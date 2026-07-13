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
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Use the service-role client to validate the caller's JWT.
    // This works regardless of whether the browser uses publishable key or anon key.
    const adminClient = createClient(url, service);
    const authHeader = req.headers.get('Authorization') ?? '';
    const token = authHeader.replace(/^Bearer\s+/i, '');

    if (!token) return json(401, { message: 'Not authenticated.' });

    const { data: userRes, error: userErr } = await adminClient.auth.getUser(token);
    if (userErr || !userRes?.user) return json(401, { message: 'Invalid or expired token.' });

    const callerId = userRes.user.id;
    const { data: prof } = await adminClient
      .from('profiles')
      .select('role')
      .eq('id', callerId)
      .maybeSingle();
    if (prof?.role !== 'admin') return json(403, { message: 'Only admins can create accounts.' });

    const b = await req.json();

    // Use a real email when supplied, otherwise a staff Employee ID alias.
    let authEmail: string = String(b.email ?? '').trim();
    if (!authEmail) {
      if (b.employee_id) {
        authEmail = `${String(b.employee_id).toLowerCase().trim()}@hayaat.id`;
      } else {
        return json(400, {
          message: 'Must provide an email or Employee ID.',
        });
      }
    }

    const { data: created, error } = await adminClient.auth.admin.createUser({
      email: authEmail,
      password: b.password,
      email_confirm: true,
      // app_metadata is service-role-only → the handle_new_user trigger trusts
      // the role from here. (A self-signup client can only set user_metadata,
      // which the trigger clamps to patient/doctor.)
      app_metadata: { role: b.role },
      user_metadata: {
        role: b.role,
        full_name: b.full_name,
        phone: b.phone_primary,
        email: b.email,
        clinic_id: b.clinic_id,
        lab_id: b.lab_id,
        admin_level: b.admin_level,
        employee_id: b.employee_id,
      },
    });
    if (error) return json(400, { message: error.message });
    return json(200, { id: created.user?.id });
  } catch (e) {
    return json(500, { message: String(e) });
  }
});
