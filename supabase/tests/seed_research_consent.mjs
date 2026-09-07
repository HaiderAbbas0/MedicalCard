// Turns on research consent for a slice of the fake test patients, so the
// research portal has a non-empty cohort to explore.
//
//   node supabase/tests/seed_research_consent.mjs           # first 30 patients
//   node supabase/tests/seed_research_consent.mjs --all     # all of them
//   node supabase/tests/seed_research_consent.mjs --off     # withdraw again
//
// Consent is set by signing in as each patient and calling the same
// `set_consent_preference` RPC the mobile app's Consent Management screen uses.
// There is no back door here on purpose: if this script can do it, it is
// because a patient could do exactly the same thing in the app.
//
// Withdrawing (--off) is the interesting case to try: re-run the cohort
// explorer afterwards and the numbers drop immediately, because the consent
// check happens at query time rather than from a snapshot.

import { createClient } from '@supabase/supabase-js';
import { FAKE_PASSWORD, FAKE_PATIENTS } from './fake_pk_data.mjs';

const URL = process.env.SUPABASE_URL || 'https://iikwdtiqvxxatrzahuzo.supabase.co';
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';

const ENABLE = !process.argv.includes('--off');
const COUNT = process.argv.includes('--all') ? FAKE_PATIENTS.length : 30;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

let ok = 0;
let failed = 0;

async function setConsent(email) {
  const c = createClient(URL, KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  try {
    const { error: authErr } = await c.auth.signInWithPassword({
      email,
      password: FAKE_PASSWORD,
    });
    if (authErr) throw new Error(authErr.message);

    const { error } = await c.rpc('set_consent_preference', {
      p_key: 'research',
      p_enabled: ENABLE,
    });
    if (error) throw new Error(error.message);

    ok += 1;
    console.log(`${ENABLE ? 'opted in ' : 'withdrew '} ${email}`);
  } catch (e) {
    failed += 1;
    console.log(`FAILED    ${email}: ${e.message}`);
  } finally {
    await c.auth.signOut();
  }
}

const targets = FAKE_PATIENTS.slice(0, COUNT);
console.log(
  `${ENABLE ? 'Granting' : 'Withdrawing'} research consent for ${targets.length} patients ` +
    `against ${URL}\n`,
);

for (const p of targets) {
  await setConsent(p.email);
  await sleep(150);
}

console.log(`\n${ok} updated, ${failed} failed`);
if (ENABLE) {
  console.log('These patients are now in scope for the research portal.');
  console.log('Run with --off to withdraw and watch the cohort shrink immediately.');
}
if (failed) process.exitCode = 1;
