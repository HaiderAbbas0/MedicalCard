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
      .select('*, patient:profiles!patient_id(id, full_name, card_number, phone_primary), doctor:profiles!doctor_id(full_name)')
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

  /** Front-desk lookup by 13-digit CNIC or 16-digit Hayaat ID. Uses the same
   *  staff-only RPC as the doctor, so demographics are available for booking
   *  without granting the receptionist a blanket read over `profiles`. */
  async searchPatient(identifier: string) {
    const digits = identifier.replace(/\D/g, '');
    if (digits.length !== 13 && digits.length !== 16) {
      throw new Error('Enter a 13-digit CNIC or a 16-digit Hayaat ID.');
    }
    const { data, error } = await supabase.rpc('find_patient_by_identifier', { p_identifier: digits });
    if (error) throw new Error(error.message);
    const patient = (data ?? [])[0];
    if (!patient) {
      throw new Error(digits.length === 13
        ? 'No patient is registered with that CNIC.'
        : 'No patient found with that Hayaat ID.');
    }
    return patient;
  },

  async book(body: Record<string, unknown>) {
    const { error } = await supabase.rpc('book_clinic_appointment', {
      p_patient: body.patient_id,
      p_doctor: body.doctor_id,
      p_date: body.appointment_date,
      p_time: body.appointment_time,
      p_type: body.appointment_type ?? 'in_person',
      p_notes: body.notes_for_doctor ?? null,
    });
    if (error) {
      if (error.message.includes('appointments_unique_doctor_time') || error.message.includes('duplicate key')) {
        throw new Error('That doctor already has an appointment at this date and time.');
      }
      throw new Error(error.message);
    }
  },

  async availableSlots(doctorId: string, date: string): Promise<{ slot_time: string; slot_label: string; clinic_id: string }[]> {
    const { data, error } = await supabase.rpc('available_appointment_slots', {
      p_doctor: doctorId,
      p_date: date,
    });
    if (error) throw new Error(error.message);
    return (data ?? []) as { slot_time: string; slot_label: string; clinic_id: string }[];
  },

  async checkIn(id: string) {
    const { error } = await supabase.from('appointments').update({ status: 'checked_in' }).eq('id', id);
    if (error) throw new Error(error.message);
  },
  async cancel(id: string, reason?: string) {
    const { error } = await supabase.from('appointments').update({ status: 'cancelled_by_clinic', cancellation_reason: reason }).eq('id', id);
    if (error) throw new Error(error.message);
  },
};
