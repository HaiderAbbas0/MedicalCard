import { supabase, myId, fetchFullProfile } from './supabase';
import type { Appointment, AvailabilitySlot, Encounter, LabOrderForReview, PatientSummary } from './types';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Q = any;
const nowIso = () => new Date().toISOString();
const today = () => nowIso().slice(0, 10);

async function rows<T>(builder: Q): Promise<T[]> {
  const { data, error } = await builder;
  if (error) throw new Error(error.message);
  return (data ?? []) as T[];
}
async function one<T>(builder: Q): Promise<T> {
  const { data, error } = await builder;
  if (error) throw new Error(error.message);
  return data as T;
}
async function encPatient(encId: string): Promise<string | null> {
  const { data } = await supabase.from('encounters').select('patient_id').eq('id', encId).maybeSingle();
  return (data?.patient_id as string) ?? null;
}

export const doctorApi = {
  async appointments(date?: string): Promise<Appointment[]> {
    const me = await myId();
    let q: Q = supabase.from('appointments').select('*, patient:profiles!patient_id(id, full_name, cnic)').eq('doctor_id', me);
    if (date) q = q.eq('appointment_date', date);
    return rows<Appointment>(q);
  },
  async confirmAppointment(id: string) {
    const a = await one<Q>(supabase.from('appointments').update({ status: 'confirmed' }).eq('id', id).select().maybeSingle());
    if (a) await supabase.from('notifications').insert({ recipient_id: a.patient_id, type: 'appointment_confirmed', title: 'Appointment confirmed', body: 'Your appointment has been confirmed.' });
  },
  async checkInAppointment(id: string) {
    const { error } = await supabase.from('appointments').update({ status: 'checked_in' }).eq('id', id);
    if (error) throw new Error(error.message);
  },
  async noShowAppointment(id: string) {
    const { error } = await supabase.from('appointments').update({ status: 'no_show' }).eq('id', id);
    if (error) throw new Error(error.message);
  },

  async searchPatient(cardNumber: string): Promise<PatientSummary> {
    const prof = await one<Q>(supabase.from('profiles').select('*').eq('card_number', cardNumber).eq('role', 'patient').maybeSingle());
    if (!prof) throw new Error('No patient found with that Card Number.');
    const id = prof.id as string;
    const pp = await one<Q>(supabase.from('patient_profiles').select('*').eq('id', id).maybeSingle());
    const allergies = await rows<Record<string, unknown>>(supabase.from('allergies').select('*').eq('patient_id', id));
    const conds = await rows<Record<string, unknown>>(supabase.from('conditions').select('*').eq('patient_id', id).eq('clinical_status', 'active'));
    await supabase.from('audit_logs').insert({ actor_id: await myId(), actor_role: 'doctor', action: 'read', resource_type: 'patient_profiles', resource_id: id, patient_id: id });
    return { ...prof, blood_group: pp?.blood_group, allergies, active_conditions: conds } as PatientSummary;
  },
  async patient(id: string): Promise<PatientSummary> {
    const prof = await one<Q>(supabase.from('profiles').select('*').eq('id', id).maybeSingle());
    const pp = await one<Q>(supabase.from('patient_profiles').select('*').eq('id', id).maybeSingle());
    const allergies = await rows<Record<string, unknown>>(supabase.from('allergies').select('*').eq('patient_id', id));
    const conds = await rows<Record<string, unknown>>(supabase.from('conditions').select('*').eq('patient_id', id).eq('clinical_status', 'active'));
    return { ...prof, blood_group: pp?.blood_group, allergies, active_conditions: conds } as PatientSummary;
  },
  async timeline(id: string): Promise<{ items: Encounter[]; total: number }> {
    const data = await rows<Q>(
      supabase.from('encounters').select('*, conditions(*), medication_requests(*), observations(*), lab_orders(*)')
        .eq('patient_id', id).eq('status', 'finalized').order('encounter_date', { ascending: false }),
    );
    const docIds = [...new Set(data.map((e) => e.doctor_id).filter(Boolean))];
    const names: Record<string, string> = {};
    if (docIds.length) {
      const dn = await rows<Q>(supabase.from('profiles').select('id, full_name').in('id', docIds));
      dn.forEach((d) => (names[d.id] = d.full_name));
    }
    const items = data.map((e) => ({ ...e, medications: e.medication_requests, doctor_name: names[e.doctor_id] })) as Encounter[];
    return { items, total: items.length };
  },
  medications(id: string): Promise<Record<string, unknown>[]> {
    return rows(supabase.from('medication_requests').select('*').eq('patient_id', id).eq('status', 'active'));
  },
  async recordAllergy(id: string, body: Record<string, unknown>) {
    const { error } = await supabase.from('allergies').insert({ patient_id: id, recorded_by_id: await myId(), clinical_status: 'active', ...body });
    if (error) throw new Error(error.message);
  },

  async createEncounter(patientId: string, chiefComplaint?: string): Promise<Encounter> {
    return one<Encounter>(supabase.from('encounters').insert({ patient_id: patientId, doctor_id: await myId(), encounter_date: today(), chief_complaint: chiefComplaint, status: 'draft' }).select().single());
  },
  async updateEncounter(id: string, patch: Record<string, unknown>) {
    const { error } = await supabase.from('encounters').update(patch).eq('id', id);
    if (error) throw new Error(error.message);
  },
  async addCondition(id: string, body: Record<string, unknown>) {
    const { error } = await supabase.from('conditions').insert({ encounter_id: id, patient_id: await encPatient(id), doctor_id: await myId(), ...body });
    if (error) throw new Error(error.message);
  },
  async addMedication(id: string, body: Record<string, unknown>): Promise<{ allergy_warning: string | null }> {
    const pid = await encPatient(id);
    const allergies = await rows<Q>(supabase.from('allergies').select('*').eq('patient_id', pid ?? '').eq('clinical_status', 'active'));
    const name = String(body.medication_name ?? '').toLowerCase();
    const conflict = allergies.find((a) => {
      const s = String(a.substance_name ?? '').toLowerCase();
      return s && (name.includes(s) || s.includes(name));
    });
    const { error } = await supabase.from('medication_requests').insert({ encounter_id: id, patient_id: pid, doctor_id: await myId(), route: 'oral', status: 'active', start_date: today(), ...body });
    if (error) throw new Error(error.message);
    return { allergy_warning: conflict ? `Patient has a recorded ${conflict.criticality} allergy to ${conflict.substance_name}.` : null };
  },
  async addVital(id: string, body: Record<string, unknown>) {
    const { error } = await supabase.from('observations').insert({ encounter_id: id, patient_id: await encPatient(id), authored_by_id: await myId(), observation_date: today(), ...body });
    if (error) throw new Error(error.message);
  },
  async addLabOrder(id: string, body: Record<string, unknown>) {
    const { error } = await supabase.from('lab_orders').insert({ encounter_id: id, patient_id: await encPatient(id), ordering_doctor_id: await myId(), status: 'ordered', ...body });
    if (error) throw new Error(error.message);
  },
  async finalizeEncounter(id: string): Promise<Encounter> {
    const row = await one<Q>(supabase.from('encounters').update({ status: 'finalized', finalized_at: nowIso() }).eq('id', id).select().single());
    await supabase.from('notifications').insert({ recipient_id: row.patient_id, type: 'record_added', title: 'New record added', body: 'A new entry has been added to your health timeline.', resource_id: id });
    return row as Encounter;
  },

  labs(): Promise<{ id: string; name: string }[]> {
    return rows(supabase.from('diagnostic_labs').select('id, name').eq('status', 'active'));
  },
  async labOrdersForReview(): Promise<LabOrderForReview[]> {
    const me = await myId();
    const data = await rows<Q>(
      supabase.from('lab_orders').select('*, patient:profiles!patient_id(full_name), lab_results(*)')
        .eq('ordering_doctor_id', me).in('status', ['resulted', 'reviewed']),
    );
    return data.map((r) => ({ ...r, result: r.lab_results?.[0] ?? null })) as LabOrderForReview[];
  },
  async reviewLabOrder(id: string) {
    const { error } = await supabase.from('lab_orders').update({ status: 'reviewed', reviewed_at: nowIso() }).eq('id', id);
    if (error) throw new Error(error.message);
  },
  async releaseLabOrder(id: string) {
    const o = await one<Q>(supabase.from('lab_orders').update({ status: 'released_to_patient', released_to_patient_at: nowIso() }).eq('id', id).select().maybeSingle());
    if (o) await supabase.from('notifications').insert({ recipient_id: o.patient_id, type: 'lab_result_ready', title: 'Lab result available', body: 'A new lab result has been released to you.', resource_id: id });
  },

  async availability(): Promise<AvailabilitySlot[]> {
    return rows<AvailabilitySlot>(supabase.from('doctor_availability').select('*').eq('doctor_id', await myId()));
  },
  async addAvailability(body: Record<string, unknown>): Promise<AvailabilitySlot> {
    return one<AvailabilitySlot>(supabase.from('doctor_availability').insert({ doctor_id: await myId(), is_active: true, ...body }).select().single());
  },
  async deleteAvailability(id: string) {
    const { error } = await supabase.from('doctor_availability').delete().eq('id', id);
    if (error) throw new Error(error.message);
  },

  async updateProfile(patch: Record<string, unknown>) {
    const me = await myId();
    const baseFields = ['full_name', 'phone_primary', 'email'];
    const base: Record<string, unknown> = {};
    const ext: Record<string, unknown> = {};
    Object.entries(patch).forEach(([k, v]) => (baseFields.includes(k) ? (base[k] = v) : (ext[k] = v)));
    if (Object.keys(base).length) await supabase.from('profiles').update(base).eq('id', me);
    if (Object.keys(ext).length) await supabase.from('doctor_profiles').update(ext).eq('id', me);
    await fetchFullProfile(me);
  },
};
