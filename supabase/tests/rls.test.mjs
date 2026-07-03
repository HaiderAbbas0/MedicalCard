// ============================================================================
// rls.test.mjs — Automated Row Level Security verification against a live
// Supabase project. Signs in as each demo role and asserts what every role
// can and cannot read/write. No service-role key is used — this exercises the
// exact policies a real client is subject to.
//
// Run (from repo root, reusing the web app's installed supabase-js):
//   NODE_PATH=web-admin/node_modules node supabase/tests/rls.test.mjs
// Or set your own project:
//   SUPABASE_URL=... SUPABASE_PUBLISHABLE_KEY=... node supabase/tests/rls.test.mjs
//
// Exit code 0 = all checks passed, 1 = one or more failed.
// ============================================================================
import { createClient } from '@supabase/supabase-js';

const URL = process.env.SUPABASE_URL || 'https://iikwdtiqvxxatrzahuzo.supabase.co';
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';
const PW = process.env.DEMO_PASSWORD || 'password123';

const CNIC = {
  ayesha: '3520112345671', // patient (has seeded clinical data)
  bilal: '3520155555552',  // patient (other — for cross-tenant checks)
  imran: '3520199999991',  // doctor, ACTIVE
  sana: '3520188888882',   // doctor, PENDING (must be blocked by is_staff active-gate)
  zafar: '3520177777771',  // lab_worker
  hina: '3520166666661',   // receptionist
  admin: '3520100000001',  // admin
};
const emailFor = (cnic) => `${cnic}@hayaat.id`;
const opts = { auth: { persistSession: false, autoRefreshToken: false } };

let pass = 0, fail = 0;
const lines = [];
function ok(name) { pass++; lines.push(`  ✓ ${name}`); }
function bad(name, detail) { fail++; lines.push(`  ✗ ${name}${detail ? `  — ${detail}` : ''}`); }
function check(name, cond, detail) { cond ? ok(name) : bad(name, detail); }

function anon() { return createClient(URL, KEY, opts); }
async function signIn(cnic) {
  const c = createClient(URL, KEY, opts);
  const { data, error } = await c.auth.signInWithPassword({ email: emailFor(cnic), password: PW });
  if (error) return { error };
  return { client: c, uid: data.user.id };
}

// RLS "read-blocked" surfaces as an empty result (no error); "write-blocked"
// surfaces as a Postgres 42501 (RLS violation). These helpers encode that.
const isRlsDenied = (error) => !!error && (error.code === '42501' || /row-level security/i.test(error.message || ''));

async function main() {
  console.log(`RLS suite against ${URL}\n`);

  const anonC = anon();

  // ---- ANONYMOUS ---------------------------------------------------------
  {
    const { data: p } = await anonC.from('profiles').select('id').limit(5);
    check('anon cannot read profiles', (p ?? []).length === 0, `got ${(p ?? []).length} rows`);
    const { data: e } = await anonC.from('encounters').select('id').limit(5);
    check('anon cannot read encounters', (e ?? []).length === 0);
    const { data: m } = await anonC.from('messages').select('id').limit(5);
    check('anon cannot read messages', (m ?? []).length === 0);
    // login_email RPC is intentionally anon-callable (documented enumeration tradeoff)
    const { data: le } = await anonC.rpc('login_email', { p_id: CNIC.ayesha });
    check('anon may resolve login_email (by design)', typeof le === 'string' && le.includes('@'));
  }

  // ---- sign in everyone ---------------------------------------------------
  const A = await signIn(CNIC.ayesha);
  const B = await signIn(CNIC.bilal);
  const D = await signIn(CNIC.imran);
  const S = await signIn(CNIC.sana);
  const ADM = await signIn(CNIC.admin);
  if (A.error) return finish(`patient sign-in failed: ${A.error.message} — did you apply the SQL + turn off email confirmation?`);

  // ---- PATIENT (owner) ----------------------------------------------------
  {
    const { data: own } = await A.client.from('profiles').select('id').eq('id', A.uid);
    check('patient reads own profile', (own ?? []).length === 1);

    if (!B.error) {
      const { data: other } = await A.client.from('profiles').select('id').eq('id', B.uid);
      check('patient cannot read another patient profile', (other ?? []).length === 0, `got ${(other ?? []).length}`);
    }

    const { data: enc } = await A.client.from('encounters').select('patient_id');
    const leak = (enc ?? []).filter((r) => r.patient_id !== A.uid);
    check('patient sees only own encounters', leak.length === 0, `${leak.length} foreign rows leaked`);

    const { data: audit } = await A.client.from('audit_logs').select('id').limit(1);
    check('patient cannot read audit_logs', (audit ?? []).length === 0);

    // write attempts (must be RLS-denied)
    const encRow = { patient_id: A.uid, doctor_id: D.uid ?? A.uid, encounter_date: '2026-07-04', status: 'draft', chief_complaint: 'rls-test' };
    const { error: encErr } = await A.client.from('encounters').insert(encRow);
    check('patient cannot insert encounters', isRlsDenied(encErr), encErr ? `code ${encErr.code}` : 'insert succeeded!');

    const { error: audErr } = await A.client.from('audit_logs').insert({ actor_id: B.uid ?? A.uid, action: 'read', resource_type: 'x', status: 'success' });
    check('patient cannot forge audit_logs as another actor', isRlsDenied(audErr), audErr ? `code ${audErr.code}` : 'insert succeeded!');
  }

  // ---- DOCTOR (active staff) ---------------------------------------------
  if (!D.error) {
    const { data: enc } = await D.client.from('encounters').select('id').eq('patient_id', A.uid).limit(1);
    check('active doctor can read a patient’s encounters', (enc ?? []).length >= 1);

    const { data: ins, error: insErr } = await D.client
      .from('encounters')
      .insert({ patient_id: A.uid, doctor_id: D.uid, encounter_date: '2026-07-04', status: 'draft', chief_complaint: 'rls-test-cleanup' })
      .select('id');
    check('active doctor can insert an encounter', !isRlsDenied(insErr), insErr ? `code ${insErr.code}` : '');
    const newId = ins?.[0]?.id;
    if (newId) await D.client.from('encounters').delete().eq('id', newId); // cleanup

    const { data: aud } = await D.client.from('audit_logs').select('id').limit(1);
    check('doctor cannot read audit_logs (admin only)', (aud ?? []).length === 0);
  } else {
    bad('active doctor sign-in', D.error.message);
  }

  // ---- PENDING DOCTOR (must be blocked by is_staff active-gate) -----------
  if (!S.error) {
    const { data: enc } = await S.client.from('encounters').select('id').eq('patient_id', A.uid).limit(1);
    check('PENDING doctor is blocked from patient encounters', (enc ?? []).length === 0,
      `got ${(enc ?? []).length} rows — apply security_hardening.sql (is_staff active-gate)`);
  } else {
    lines.push(`  – pending-doctor check skipped (sign-in: ${S.error.message})`);
  }

  // ---- ADMIN --------------------------------------------------------------
  if (!ADM.error) {
    const { data: aud, error: audErr } = await ADM.client.from('audit_logs').select('id').limit(1);
    check('admin can read audit_logs', !audErr, audErr?.message);
    const { data: profs } = await ADM.client.from('profiles').select('id').limit(10);
    check('admin (staff) can read all profiles', (profs ?? []).length > 1);
  } else {
    bad('admin sign-in', ADM.error.message);
  }

  // ---- CHAT ISOLATION (chat.sql RLS) -------------------------------------
  if (!B.error && !D.error) {
    // Ayesha starts a conversation with Dr Imran (legitimate participant action)
    const { data: convId, error: startErr } = await A.client.rpc('start_conversation', { p_patient: A.uid, p_doctor: D.uid });
    check('patient can start a conversation with a doctor', !startErr && typeof convId === 'string', startErr?.message);

    if (convId) {
      // Bilal (not a participant) must not read or write that conversation
      const { data: bMsgs } = await B.client.from('messages').select('id').eq('conversation_id', convId);
      check('non-participant cannot read a conversation’s messages', (bMsgs ?? []).length === 0);
      const { error: bInsErr } = await B.client.from('messages').insert({ conversation_id: convId, sender_id: B.uid, body: 'intrusion' });
      check('non-participant cannot post into a conversation', isRlsDenied(bInsErr), bInsErr ? `code ${bInsErr.code}` : 'insert succeeded!');
    }
    // start_conversation RPC rejects a non-participant caller
    const { error: guardErr } = await B.client.rpc('start_conversation', { p_patient: A.uid, p_doctor: D.uid });
    check('start_conversation rejects non-participant caller', !!guardErr, 'no error raised');
  }

  // ---- COMPLIANCE (consents / deletion_requests / export) ----------------
  if (!B.error) {
    // consents: own-only, append-only
    const { error: cOther } = await A.client.from('consents').insert({ user_id: B.uid, document: 'privacy_policy', version: '2026-07-04' });
    check('patient cannot record consent for another user', isRlsDenied(cOther), cOther ? `code ${cOther.code}` : 'insert succeeded!');
    const { error: cAnon } = await anonC.from('consents').insert({ user_id: A.uid, document: 'terms', version: '2026-07-04' });
    check('anon cannot record consent', !!cAnon);

    // deletion_requests: a user may only file their OWN request
    const { error: drOther } = await A.client.from('deletion_requests').insert({ user_id: B.uid, reason: 'rls-test' });
    check('patient cannot file a deletion request for another user', isRlsDenied(drOther), drOther ? `code ${drOther.code}` : 'insert succeeded!');
    if (!ADM.error) {
      const { error: drAdmSel } = await ADM.client.from('deletion_requests').select('id').limit(1);
      check('admin can read deletion requests', !drAdmSel, drAdmSel?.message);
    }

    // export_my_data: returns only the caller's own data; anon cannot call it
    const { data: exp, error: expErr } = await A.client.rpc('export_my_data');
    check('export_my_data returns the caller’s own profile', !expErr && exp?.profile?.id === A.uid, expErr?.message);
    const encs = Array.isArray(exp?.encounters) ? exp.encounters : [];
    check('export contains only the caller’s encounters', encs.every((e) => e.patient_id === A.uid));
    const { error: anonExp } = await anonC.rpc('export_my_data');
    check('anon cannot export data', !!anonExp);
  }

  finish();
}

function finish(fatal) {
  if (fatal) { console.error('FATAL:', fatal); }
  console.log(lines.join('\n'));
  console.log(`\n${pass} passed, ${fail} failed${fatal ? ' (aborted early)' : ''}`);
  process.exit(fail === 0 && !fatal ? 0 : 1);
}

main().catch((e) => finish(e.message));
