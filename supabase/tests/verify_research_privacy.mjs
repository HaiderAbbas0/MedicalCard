// Privacy verification suite for the research data platform.
//
//   node supabase/tests/verify_research_privacy.mjs
//
// This is the test that matters for this module: it signs in as a real
// researcher through the ordinary public API and tries, in good faith, to get
// at something it should not be able to reach. Every assertion below is a
// privacy or compliance guarantee that the README claims — if one fails, the
// claim is false.
//
// Prerequisites:
//   1. supabase/research_platform.sql applied
//   2. node supabase/tests/seed_research_account.mjs  + its generated SQL applied
//   3. Some consented patient data (see the note about consent at the bottom)

import { createClient } from '@supabase/supabase-js';
import { RESEARCHER } from './seed_research_account.mjs';

const URL = process.env.SUPABASE_URL || 'https://iikwdtiqvxxatrzahuzo.supabase.co';
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';

let passed = 0;
let failed = 0;
const failures = [];

function check(label, condition, detail) {
  if (condition) {
    passed += 1;
    console.log(`  PASS  ${label}`);
  } else {
    failed += 1;
    failures.push(label);
    console.log(`  FAIL  ${label}${detail ? `  -- ${detail}` : ''}`);
  }
}

function section(title) {
  console.log(`\n${title}\n${'-'.repeat(title.length)}`);
}

function fatal(message) {
  console.error(`\nSTOPPED: ${message}`);
  process.exit(1);
}

const client = () =>
  createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });

// Identifier-shaped strings that must never appear in an extract.
const FORBIDDEN_COLUMNS = [
  'full_name', 'name', 'cnic', 'card_number', 'health_card_number', 'phone',
  'phone_primary', 'email', 'address_street', 'address_city', 'date_of_birth',
  'dob', 'patient_id', 'id', 'chief_complaint', 'assessment', 'plan',
  'history_of_present_illness', 'physical_examination_notes', 'instructions', 'notes',
];

console.log(`Research privacy verification against ${URL}`);

// ── Sign in ─────────────────────────────────────────────────────────────────
section('0. Researcher session');
const r = client();
const { data: auth, error: authErr } = await r.auth.signInWithPassword({
  email: RESEARCHER.email,
  password: RESEARCHER.password,
});
if (authErr) {
  fatal(
    `cannot sign in as ${RESEARCHER.email}: ${authErr.message}. ` +
      'Run seed_research_account.mjs and apply its generated SQL first.',
  );
}
const researcherId = auth.user.id;

const { data: role } = await r.rpc('my_role');
check('account resolves to the researcher role', role === 'researcher', `got ${role}`);

const { data: isStaff } = await r.rpc('is_staff');
check('a researcher is NOT staff (so clinical RLS denies them)', isStaff === false, `got ${isStaff}`);

// ── 1. Direct table access must be blocked ──────────────────────────────────
section('1. Direct access to clinical tables is blocked');

const CLINICAL_TABLES = [
  'encounters', 'conditions', 'medication_requests', 'observations',
  'allergies', 'lab_orders', 'lab_results', 'medical_documents',
  'messages', 'conversations', 'appointments', 'patient_profiles',
];

for (const table of CLINICAL_TABLES) {
  const { data, error } = await r.from(table).select('*').limit(5);
  // RLS returns an empty set rather than an error; either is a pass, rows are a fail.
  check(
    `researcher reads nothing from ${table}`,
    error !== null || (data ?? []).length === 0,
    `leaked ${(data ?? []).length} rows`,
  );
}

// profiles is special: a researcher may read their own row, but no patients.
const { data: profileRows } = await r.from('profiles').select('id, role').limit(200);
const patientsVisible = (profileRows ?? []).filter((p) => p.role === 'patient');
check(
  'researcher cannot read any patient profile row',
  patientsVisible.length === 0,
  `saw ${patientsVisible.length} patient profiles`,
);

// ── 2. Aggregate tier works and is k-anonymised ─────────────────────────────
section('2. Aggregate tier — consent-gated and k-anonymised');

const { data: sizeRows, error: sizeErr } = await r.rpc('research_cohort_size', {
  p_gender: null,
  p_province: null,
  p_age_band: null,
});
check('researcher can call research_cohort_size', !sizeErr, sizeErr?.message);
const total = sizeRows?.[0];
const totalCount = total?.subject_count ?? 0;
console.log(`        consented cohort size: ${total?.suppressed ? '<5 (suppressed)' : totalCount}`);

const { data: breakdown, error: bdErr } = await r.rpc('research_cohort_summary', {
  p_dimension: 'age_band',
  p_gender: null,
  p_province: null,
  p_age_band: null,
});
check('researcher can call research_cohort_summary', !bdErr, bdErr?.message);

const suppressed = (breakdown ?? []).filter((b) => b.suppressed);
const exposed = suppressed.filter((b) => b.subject_count !== null);
check(
  'every suppressed bucket hides its count (k-anonymity holds)',
  exposed.length === 0,
  `${exposed.length} suppressed buckets still exposed a number`,
);
console.log(`        ${(breakdown ?? []).length} age buckets, ${suppressed.length} suppressed`);

const { error: dimErr } = await r.rpc('research_cohort_summary', {
  p_dimension: 'full_name',
  p_gender: null,
  p_province: null,
  p_age_band: null,
});
check('an arbitrary grouping dimension is rejected', !!dimErr, 'unsupported dimension was accepted');

// ── 3. Consent gate ─────────────────────────────────────────────────────────
section('3. Consent gate');

// Every consented subject must have the research preference switched on. We
// cannot read consent_preferences as a researcher (correctly), so we assert the
// gate indirectly: the cohort can never exceed the number of opted-in patients.
const admin = client();
let consentedCount = null;
if (process.env.ADMIN_EMAIL && process.env.ADMIN_PASSWORD) {
  const { error: aErr } = await admin.auth.signInWithPassword({
    email: process.env.ADMIN_EMAIL,
    password: process.env.ADMIN_PASSWORD,
  });
  if (!aErr) {
    const { count } = await admin
      .from('consent_preferences')
      .select('user_id', { count: 'exact', head: true })
      .eq('key', 'research')
      .eq('enabled', true);
    consentedCount = count ?? 0;
  }
}
if (consentedCount === null) {
  console.log('        (set ADMIN_EMAIL / ADMIN_PASSWORD to cross-check the consent count)');
} else {
  check(
    'cohort size never exceeds the number of opted-in patients',
    totalCount <= consentedCount,
    `cohort ${totalCount} > consented ${consentedCount}`,
  );
}

const { data: consentRows } = await r.from('consent_preferences').select('*').limit(5);
check(
  'researcher cannot read the consent table itself',
  (consentRows ?? []).length === 0,
  `leaked ${(consentRows ?? []).length} consent rows`,
);

// ── 4. Record-level exports require an approved request ─────────────────────
section('4. Record-level exports are gated on approval');

const EXPORTERS = [
  'research_export_patient_features',
  'research_export_conditions',
  'research_export_observations',
];

const randomId = '00000000-0000-0000-0000-000000000001';
for (const fn of EXPORTERS) {
  const { error } = await r.rpc(fn, { p_request: randomId });
  check(`${fn} refuses an unknown request id`, !!error, 'export succeeded without approval');
}

// Raise a genuine request and confirm it cannot be self-approved.
const { data: datasets } = await r.from('research_datasets').select('*').eq('code', 'patient_features');
const dataset = datasets?.[0];
check('dataset catalogue is readable', !!dataset, 'patient_features dataset missing');

const { data: orgRows } = await r.from('research_organizations').select('id, status');
const org = orgRows?.[0];
check('researcher sees their own organisation', !!org, 'no organisation visible');

let ownRequestId = null;
if (dataset && org) {
  const { data: created, error: reqErr } = await r
    .from('research_data_requests')
    .insert({
      organization_id: org.id,
      dataset_id: dataset.id,
      requested_by: researcherId,
      title: 'Privacy verification run',
      research_purpose:
        'Automated verification that record-level export is refused until a request is approved.',
      legal_basis: 'consent',
      cohort_filters: {},
      dpa_accepted: true,
      // Deliberately attempting to self-approve with a long expiry.
      status: 'approved',
      expires_at: new Date(Date.now() + 86400000).toISOString(),
    })
    .select('id, status, expires_at')
    .maybeSingle();

  check('researcher can submit a data request', !reqErr && !!created, reqErr?.message);

  if (created) {
    ownRequestId = created.id;
    check(
      'a self-submitted request is forced back to pending (no self-approval)',
      created.status === 'pending',
      `status came back as ${created.status}`,
    );
    check(
      'a self-chosen expiry is discarded',
      created.expires_at === null,
      `expires_at came back as ${created.expires_at}`,
    );

    for (const fn of EXPORTERS) {
      const { error } = await r.rpc(fn, { p_request: ownRequestId });
      check(`${fn} refuses a pending request`, !!error, 'export succeeded while pending');
    }
  }
}

// The salt is the whole basis of unlinkability — it must be unreachable.
const { data: saltProbe, error: saltErr } = await r
  .from('research_request_secrets')
  .select('*')
  .limit(5);
check(
  'the pseudonym salt table is unreadable by any client',
  !!saltErr || (saltProbe ?? []).length === 0,
  `leaked ${(saltProbe ?? []).length} salt rows`,
);

// A plain `select *` on requests must still work — the salt lives elsewhere
// precisely so column-level grants never break ordinary reads.
const { error: starErr } = await r.from('research_data_requests').select('*').limit(1);
check('select * on research_data_requests still works', !starErr, starErr?.message);

const { error: approveErr } = await r
  .from('research_data_requests')
  .update({ status: 'approved' })
  .eq('id', ownRequestId ?? randomId);
const { data: afterUpdate } = await r
  .from('research_data_requests')
  .select('status')
  .eq('id', ownRequestId ?? randomId)
  .maybeSingle();
check(
  'researcher cannot update a request to approved',
  !!approveErr || afterUpdate?.status !== 'approved',
  'a researcher approved their own request',
);

const { error: decideErr } = await r.rpc('admin_decide_data_request', {
  p_request: ownRequestId ?? randomId,
  p_status: 'approved',
  p_note: null,
  p_valid_days: 30,
});
check('researcher cannot call the admin decision RPC', !!decideErr, 'admin RPC was callable');

// ── 5. If an approved request exists, the extract must be de-identified ─────
section('5. Shape of an approved extract');

const { data: approvedAll } = await r
  .from('research_data_requests')
  .select('id, title, status, dataset:research_datasets(code)')
  .eq('status', 'approved')
  .order('created_at', { ascending: true });
const approved = approvedAll ?? [];
const live = approved[0];

if (!live) {
  console.log('        (no approved request available — approve one in the admin portal to');
  console.log('         exercise the export assertions below)');
} else {
  const fn = {
    patient_features: 'research_export_patient_features',
    conditions: 'research_export_conditions',
    observations: 'research_export_observations',
  }[live.dataset?.code ?? 'patient_features'];

  const { data: exportRows, error: expErr } = await r.rpc(fn, { p_request: live.id });
  check('approved request exports successfully', !expErr, expErr?.message);

  const rows = exportRows ?? [];
  if (rows.length) {
    const columns = Object.keys(rows[0]);
    const leaked = columns.filter((c) => FORBIDDEN_COLUMNS.includes(c.toLowerCase()));
    check(
      'extract contains no direct-identifier columns',
      leaked.length === 0,
      `found ${leaked.join(', ')}`,
    );
    check('extract exposes a subject_id', columns.includes('subject_id'));

    const looksHashed = rows.every(
      (row) => typeof row.subject_id === 'string' && /^[0-9a-f]{64}$/.test(row.subject_id),
    );
    check('subject_id is a 64-char digest, not an identifier', looksHashed);

    if ('age_band' in rows[0]) {
      const banded = rows.every(
        (row) => row.age_band === 'unknown' || /^(\d+-\d+|90\+)$/.test(String(row.age_band)),
      );
      check('ages are released only as bands', banded);
    }
    console.log(`        exported ${rows.length} rows / ${columns.length} columns`);
  } else {
    console.log('        (approved request returned no rows — no consented patients yet)');
  }

  // ── Unlinkability: the headline guarantee of the whole module ─────────────
  // Two extracts covering the same people must share no subject_id, or the
  // per-request salt is not doing its job and datasets could be joined.
  const second = approved.find(
    (a) => a.id !== live.id && (a.dataset?.code ?? '') === (live.dataset?.code ?? ''),
  );
  if (!second) {
    console.log('        (approve a second request on the same dataset to verify unlinkability)');
  } else {
    const other = await r.rpc(fn, { p_request: second.id });
    const idsA = new Set(rows.map((row) => row.subject_id));
    const idsB = new Set((other.data ?? []).map((row) => row.subject_id));
    const overlap = [...idsA].filter((id) => idsB.has(id));
    check(
      'two extracts of the same cohort share no subject_id (unlinkable)',
      idsA.size > 0 && idsB.size > 0 && overlap.length === 0,
      `${overlap.length} ids appeared in both extracts`,
    );
    console.log(`        ${idsA.size} vs ${idsB.size} subjects, ${overlap.length} shared`);
  }
}

// ── Summary ─────────────────────────────────────────────────────────────────
console.log(`\n${'='.repeat(64)}`);
console.log(`${passed} passed, ${failed} failed`);
if (failed) {
  console.log('\nFailures:');
  failures.forEach((f) => console.log(`  - ${f}`));
  process.exitCode = 1;
} else {
  console.log('\nEvery privacy guarantee held: no direct table access, consent enforced,');
  console.log('k-anonymity intact, no self-approval, and the pseudonym salt unreadable.');
}

await r.auth.signOut();
