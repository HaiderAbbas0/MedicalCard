// Supabase Edge Function: delete-account
// Permanently erases a user's account and all their data. Deleting an auth user
// requires the service role (never in the browser), so it runs here.
//
// Two callers:
//   * a signed-in user deleting THEIR OWN account (no body, or { user_id: <self> })
//   * an ADMIN fulfilling a deletion request ({ user_id: <target> })
//
// Deleting the profiles row cascades (ON DELETE CASCADE) to all dependent
// clinical data; the auth user is then removed. An audit record is written so
// the erasure itself is accountable.
//
// Deploy:
//   supabase functions deploy delete-account
// (SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY are provided by
//  the platform.)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (status: number, obj: unknown) =>
  new Response(JSON.stringify(obj), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

async function removeFolder(admin: ReturnType<typeof createClient>, bucket: string, userId: string) {
  const { data, error } = await admin.storage.from(bucket).list(userId, { limit: 1000 });
  if (error || !data?.length) return;
  const paths = data.map((item) => `${userId}/${item.name}`);
  await admin.storage.from(bucket).remove(paths);
}

async function markDeletionRequest(
  admin: ReturnType<typeof createClient>,
  requestId: string | null,
  callerId: string,
  status: 'processing' | 'completed' | 'failed',
  note?: string,
) {
  if (!requestId) return;
  await admin.from('deletion_requests').update({
    status,
    note: note ? note.slice(0, 1000) : null,
    processed_at: status === 'completed' || status === 'failed' ? new Date().toISOString() : null,
    processed_by: callerId,
  }).eq('id', requestId);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Identify the caller from their JWT.
    const caller = createClient(url, anon, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: ures } = await caller.auth.getUser();
    if (!ures?.user) return json(401, { message: 'Not authenticated.' });
    const callerId = ures.user.id;

    const { data: callerProf } = await caller.from('profiles').select('role').eq('id', callerId).maybeSingle();
    const callerRole = callerProf?.role ?? null;

    const body = await req.json().catch(() => ({}));
    const targetId: string = (body?.user_id as string) || callerId;
    const requestId: string | null = (body?.request_id as string) || null;

    // Authorization: you may delete yourself; only an admin may delete someone else.
    if (targetId !== callerId && callerRole !== 'admin') {
      return json(403, { message: 'You can only delete your own account.' });
    }

    const admin = createClient(url, service);

    if (requestId && callerRole === 'admin') {
      await markDeletionRequest(admin, requestId, callerId, 'processing');
    }

    await Promise.all([
      removeFolder(admin, 'card-photos', targetId),
      removeFolder(admin, 'lab-results', targetId),
      removeFolder(admin, 'medical-documents', targetId),
    ]);

    // Erase application data (cascades from profiles), then the auth identity.
    const { error: delProfErr } = await admin.from('profiles').delete().eq('id', targetId);
    if (delProfErr) {
      await markDeletionRequest(admin, requestId, callerId, 'failed', delProfErr.message);
      return json(400, { message: delProfErr.message });
    }

    const { error: delAuthErr } = await admin.auth.admin.deleteUser(targetId);
    if (delAuthErr) {
      await markDeletionRequest(admin, requestId, callerId, 'failed', delAuthErr.message);
      return json(400, { message: delAuthErr.message });
    }

    // Accountability record (survives the cascade — audit_logs has no FK to profiles).
    await admin.from('audit_logs').insert({
      actor_id: callerId,
      actor_role: callerRole ?? 'self',
      action: 'delete',
      resource_type: 'account',
      resource_id: targetId,
      patient_id: targetId,
      status: 'success',
    });
    if (requestId && callerRole === 'admin') {
      await markDeletionRequest(admin, requestId, callerId, 'completed');
    }
    return json(200, { deleted: targetId });
  } catch (e) {
    return json(500, { message: String(e) });
  }
});
