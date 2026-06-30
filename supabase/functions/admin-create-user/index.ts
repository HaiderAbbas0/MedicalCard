// Supabase Edge Function: admin-create-user
// Lets an authenticated ADMIN create a staff/admin account (creating an auth
// user requires the service role, which must never be in the browser).
//
// Deploy:
//   supabase functions deploy admin-create-user
// (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY are provided
//  automatically by the platform.)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (status: number, obj: unknown) =>
  new Response(JSON.stringify(obj), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Verify the caller is an admin.
    const caller = createClient(url, anon, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: ures } = await caller.auth.getUser();
    if (!ures?.user) return json(401, { message: 'Not authenticated.' });
    const { data: prof } = await caller.from('profiles').select('role').eq('id', ures.user.id).maybeSingle();
    if (prof?.role !== 'admin') return json(403, { message: 'Only admins can create accounts.' });

    const b = await req.json();
    const cnicDigits = String(b.cnic ?? '').replace(/\D/g, '');
    if (cnicDigits.length !== 13) return json(400, { message: 'CNIC must be 13 digits.' });

    const admin = createClient(url, service);
    const { data: created, error } = await admin.auth.admin.createUser({
      email: `${cnicDigits}@hayaat.id`,
      password: b.password,
      email_confirm: true,
      // app_metadata is service-role-only → the handle_new_user trigger trusts
      // the role from here. (A self-signup client can only set user_metadata,
      // which the trigger clamps to patient/doctor.)
      app_metadata: { role: b.role },
      user_metadata: {
        role: b.role,
        cnic: cnicDigits,
        full_name: b.full_name,
        phone: b.phone_primary,
        email: b.email,
        clinic_id: b.clinic_id,
        lab_id: b.lab_id,
        admin_level: b.admin_level,
      },
    });
    if (error) return json(400, { message: error.message });
    return json(200, { id: created.user?.id });
  } catch (e) {
    return json(500, { message: String(e) });
  }
});
