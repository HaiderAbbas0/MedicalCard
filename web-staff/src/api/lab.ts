import { supabase, myId } from './supabase';
import type { LabQueueOrder } from './types';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Q = any;
const RANK: Record<string, number> = { stat: 0, urgent: 1, routine: 2 };
const MAX_RESULT_BYTES = 25 * 1024 * 1024;
const ALLOWED_RESULT_TYPES = new Set(['application/pdf', 'image/jpeg', 'image/png']);

async function myLab(): Promise<string | null> {
  const { data } = await supabase.from('lab_worker_profiles').select('lab_id').eq('id', await myId()).maybeSingle();
  return (data?.lab_id as string) ?? null;
}

function mask(fullName: string): string {
  const parts = (fullName || '').trim().split(/\s+/);
  if (!parts[0]) return 'Patient';
  const last = parts.length > 1 ? `${parts[parts.length - 1][0]}.` : '';
  return `${parts[0]} ${last}`.trim();
}

export const labApi = {
  async queue(): Promise<LabQueueOrder[]> {
    const lab = await myLab();
    if (!lab) return [];
    const { data, error } = await supabase
      .from('lab_orders')
      .select('*, patient:profiles!patient_id(full_name)')
      .eq('lab_id', lab);
    if (error) throw new Error(error.message);
    return ((data ?? []) as Q[])
      .filter((r) => !['released_to_patient', 'cancelled'].includes(r.status))
      .map((r) => ({ ...r, patient: { display_name: mask(r.patient?.full_name ?? '') } }))
      .sort((a, b) => (RANK[a.priority] ?? 9) - (RANK[b.priority] ?? 9) || String(a.ordered_at).localeCompare(String(b.ordered_at))) as LabQueueOrder[];
  },

  async markCollected(id: string) {
    const { error } = await supabase.from('lab_orders').update({ status: 'sample_collected', sample_collected_at: new Date().toISOString() }).eq('id', id);
    if (error) throw new Error(error.message);
  },
  async markProcessing(id: string) {
    const { error } = await supabase.from('lab_orders').update({ status: 'processing' }).eq('id', id);
    if (error) throw new Error(error.message);
  },

  async uploadResult(id: string, body: Record<string, unknown>) {
    const { data: order, error: e1 } = await supabase.from('lab_orders').select('*').eq('id', id).single();
    if (e1) throw new Error(e1.message);
    const { error } = await supabase.from('lab_results').insert({
      lab_order_id: id, lab_id: order.lab_id, uploaded_by: await myId(), patient_id: order.patient_id, ...body,
    });
    if (error) throw new Error(error.message);
    await supabase.from('lab_orders').update({ status: 'resulted', resulted_at: new Date().toISOString() }).eq('id', id);
    await supabase.from('notifications').insert({
      recipient_id: order.ordering_doctor_id, type: 'lab_result_uploaded', title: 'Lab result uploaded',
      body: 'A lab result is ready for your review.', resource_id: id,
    });
  },

  async uploadResultFile(id: string, file: File, comments?: string, onProgress?: (message: string) => void) {
    if (file.size <= 0) throw new Error(`${file.name} is empty.`);
    if (file.size > MAX_RESULT_BYTES) throw new Error(`${file.name} is larger than 25 MB.`);
    if (file.type && !ALLOWED_RESULT_TYPES.has(file.type) && !/\.(pdf|jpe?g|png)$/i.test(file.name)) {
      throw new Error('Upload a PDF, JPG, or PNG result file.');
    }
    // Store under "<patient_id>/<order_id>/…" — the lab-results bucket is private
    // and RLS scopes reads to the owning patient + staff.
    const { data: order, error: e0 } = await supabase.from('lab_orders').select('patient_id').eq('id', id).single();
    if (e0) throw new Error(e0.message);
    onProgress?.('Uploading file...');
    const path = `${order.patient_id}/${id}/${Date.now()}_${file.name}`;
    const { error } = await supabase.storage.from('lab-results').upload(path, file, { upsert: true });
    if (error) throw new Error(error.message);
    onProgress?.('Saving result metadata...');
    await this.uploadResult(id, { result_file_name: file.name, result_file_path: path, comments });
  },
};
