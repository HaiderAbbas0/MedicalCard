// Manual end-to-end check of the card → admin-notification workflow.
//   patient applies for a card  -> trigger notifies every admin
//   patient requests delivery   -> trigger notifies every admin
//   admin marks the card delivered (admin update policy)
// Run: cd supabase/tests && node verify_card_workflow.mjs
import { createClient } from '@supabase/supabase-js';

const URL = process.env.SUPABASE_URL || 'https://iikwdtiqvxxatrzahuzo.supabase.co';
const KEY = process.env.SUPABASE_PUBLISHABLE_KEY || 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn';
const PW = process.env.DEMO_PASSWORD || 'password123';
const opts = { auth: { persistSession: false, autoRefreshToken: false } };
const email = (c) => `${c}@hayaat.id`;

let pass = 0, fail = 0;
const ok = (n) => { pass++; console.log(`  ✓ ${n}`); };
const bad = (n, d) => { fail++; console.log(`  ✗ ${n}${d ? ` — ${d}` : ''}`); };

async function signIn(login) {
  const c = createClient(URL, KEY, opts);
  const { data, error } = await c.auth.signInWithPassword({ email: email(login), password: PW });
  if (error) throw new Error(`${login}: ${error.message}`);
  return { client: c, uid: data.user.id };
}

const main = async () => {
  const bilal = await signIn('3520155555552'); // patient with no card
  const admin = await signIn('3520100000001');

  // 1. Apply for a card (INSERT → trigger)
  const { error: rcErr } = await bilal.client.rpc('request_card', {
    p_name_ur: 'بلال', p_dob: '1990-01-01', p_blood_group: 'O+', p_city: 'Karachi', p_photo_url: null,
  });
  if (rcErr) bad('patient can apply for a card', rcErr.message); else ok('patient can apply for a card');

  // 2. Admin received a "card_request" notification for this patient
  const { data: n1 } = await admin.client
    .from('notifications').select('title, body, type')
    .eq('type', 'card_request').eq('resource_id', bilal.uid).limit(1);
  if ((n1 ?? []).length) ok(`admin notified of application: "${n1[0].title}"`);
  else bad('admin notified of card application', 'no card_request notification found');

  // 3. Request physical delivery (UPDATE → trigger)
  const { error: rpErr } = await bilal.client.rpc('request_physical_card', {
    p_address: '12 Test Street, Karachi', p_phone: '03001234567',
  });
  if (rpErr) bad('patient can request physical delivery', rpErr.message); else ok('patient can request physical delivery');

  const { data: n2 } = await admin.client
    .from('notifications').select('title').eq('type', 'card_delivery').eq('resource_id', bilal.uid).limit(1);
  if ((n2 ?? []).length) ok(`admin notified of delivery request: "${n2[0].title}"`);
  else bad('admin notified of delivery request', 'no card_delivery notification found');

  // 4. Admin can see the delivery in the queue and mark it delivered (admin update policy)
  const { data: q } = await admin.client
    .from('cards').select('id, card_number, status').eq('profile_id', bilal.uid).eq('status', 'physical_requested');
  if ((q ?? []).length) ok(`delivery appears in admin queue (${q[0].card_number})`);
  else bad('delivery appears in admin queue', 'card not in physical_requested state');

  if (q?.[0]) {
    const { error: upErr } = await admin.client.from('cards').update({ status: 'delivered' }).eq('id', q[0].id);
    if (upErr) bad('admin can mark card delivered', upErr.message); else ok('admin can mark card delivered');
  }

  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
};

main().catch((e) => { console.error('FATAL', e.message); process.exit(1); });
