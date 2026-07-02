import { supabase, myId } from './supabase';
import type { ClinicAppointment, ClinicDoctor } from './types';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type Q = any;

async function myClinic(): Promise<string | null> {
  const { data } = await supabase.from('receptionist_profiles').select('clinic_id').eq('id', await myId()).maybeSingle();
  return (data?.clinic_id as string) ?? null;
}

export const receptionApi = {
  async appointments(date?: string): Promise<ClinicAppointment[]> {
    const clinic = await myClinic();
    if (!clinic) return [];
    let q: Q = supabase
      .from('appointments')
      .select('*, patient:profiles!patient_id(id, full_name, cnic, phone_primary), doctor:profiles!doctor_id(full_name)')
      .eq('clinic_id', clinic);
    if (date) q = q.eq('appointment_date', date);
    const { data, error } = await q;
    if (error) throw new Error(error.message);
    return ((data ?? []) as Q[]).map((r) => ({ ...r, doctor_name: r.doctor?.full_name })) as ClinicAppointment[];
  },

  async doctors(): Promise<ClinicDoctor[]> {
    const clinic = await myClinic();
    if (!clinic) return [];
    const { data, error } = await supabase
      .from('doctor_profiles')
      .select('id, specialization_primary, profiles!id(full_name, status)')
      .eq('clinic_id', clinic);
    if (error) throw new Error(error.message);
    return ((data ?? []) as Q[])
      .filter((r) => r.profiles?.status === 'active')
      .map((r) => ({ id: r.id, full_name: r.profiles?.full_name ?? '', specialization_primary: r.specialization_primary ?? '' }));
  },

  async searchPatient(cnic: string) {
    const { data, error } = await supabase
      .from('profiles')
      .select('id, full_name, cnic, phone_primary')
      .eq('cnic', cnic)
      .eq('role', 'patient')
      .maybeSingle();
    if (error) throw new Error(error.message);
    if (!data) throw new Error('No patient found with that CNIC.');
    return data;
  },

  async book(body: Record<string, unknown>) {
    const clinic = await myClinic();
    const { error } = await supabase.from('appointments').insert({
      clinic_id: clinic, status: 'pending', booked_by_role: 'receptionist', booked_by_id: await myId(), ...body,
    });
    if (error) throw new Error(error.message);
    if (body.doctor_id) {
      await supabase.from('notifications').insert([
        { recipient_id: body.doctor_id, type: 'appointment_booked', title: 'New appointment request', body: 'A receptionist booked an appointment.' },
        { recipient_id: body.patient_id, type: 'appointment_booked', title: 'Appointment booked', body: 'An appointment has been booked for you.' },
      ]);
    }
  },

  async checkIn(id: string) {
    const { error } = await supabase.from('appointments').update({ status: 'checked_in' }).eq('id', id);
    if (error) throw new Error(error.message);
  },
  async cancel(id: string, reason?: string) {
    const { error } = await supabase.from('appointments').update({ status: 'cancelled_by_patient', cancellation_reason: reason }).eq('id', id);
    if (error) throw new Error(error.message);
  },
};
