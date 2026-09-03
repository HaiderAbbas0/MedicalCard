// Creates the six demo accounts through the ordinary public sign-up API.
//
//   node supabase/tests/seed_demo_accounts.mjs
//
// Re-running is safe: accounts that already exist are reported and skipped.
// After this, run `supabase/demo_seed.sql` in the Supabase SQL editor to
// promote the staff roles and create the demo clinic + lab, then
// `node supabase/tests/verify_e2e.mjs` to drive and verify the full flow.

import { createClient } from '@supabase/supabase-js';
import { DEMO_ACCOUNTS, DEMO_PASSWORD, signupMetadata } from './demo_accounts.mjs';

const URL = process.env.SUPABASE_URL || 'https://iikwdtiqvxxatrzahuzo.supabase.co';
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';

const client = () => createClient(URL, KEY, { auth: { persistSession: false, autoRefreshToken: false } });

let created = 0;
let existing = 0;
let failed = 0;

for (const account of DEMO_ACCOUNTS) {
  const c = client();
  const { error } = await c.auth.signUp({
    email: account.email,
    password: DEMO_PASSWORD,
    options: { data: signupMetadata(account) },
  });

  if (!error) {
    created += 1;
    console.log(`created   ${account.email.padEnd(26)} cnic ${account.cnic}  (signs up as ${account.signupRole}, final ${account.finalRole})`);
  } else if (/already registered|already been registered/i.test(error.message)) {
    existing += 1;
    console.log(`exists    ${account.email.padEnd(26)} cnic ${account.cnic}`);
  } else {
    failed += 1;
    console.log(`FAILED    ${account.email.padEnd(26)} ${error.message}`);
  }
  await c.auth.signOut();
}

console.log(`\ncreated ${created}, already existed ${existing}, failed ${failed}`);
console.log(`password for every demo account: ${DEMO_PASSWORD}`);
if (failed) process.exitCode = 1;
