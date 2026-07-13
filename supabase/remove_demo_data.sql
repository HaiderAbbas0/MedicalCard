-- Removes the fixed legacy demo identities and every row that directly
-- references them. Run in the Supabase SQL editor with an owner/service role.
-- Safe to re-run.

do $$
declare
  demo_ids uuid[] := array[
    '00000000-0000-0000-0000-0000000000a1'::uuid,
    '00000000-0000-0000-0000-0000000000a2'::uuid,
    '00000000-0000-0000-0000-0000000000d1'::uuid,
    '00000000-0000-0000-0000-0000000000d2'::uuid,
    '00000000-0000-0000-0000-0000000000c1'::uuid,
    '00000000-0000-0000-0000-0000000000e1'::uuid,
    '00000000-0000-0000-0000-0000000000f1'::uuid
  ];
  fk record;
  demo_lab_ids uuid[] := array[
    '00000000-0000-0000-0000-00000000abc1'::uuid,
    '00000000-0000-0000-0000-00000000abc2'::uuid
  ];
  demo_clinic_ids uuid[] := array[
    '00000000-0000-0000-0000-0000000c1111'::uuid,
    '00000000-0000-0000-0000-0000000c2222'::uuid
  ];
begin
  -- Delete rows from every table with a single-column FK to profiles. This
  -- includes conditions.patient_id/doctor_id, medication requests, encounters,
  -- appointments, chat, notifications, audit records, and role extensions.
  for fk in
    select n.nspname as schema_name,
           c.relname as table_name,
           a.attname as column_name
      from pg_constraint con
      join pg_class c on c.oid = con.conrelid
      join pg_namespace n on n.oid = c.relnamespace
      join pg_attribute a on a.attrelid = con.conrelid
                         and a.attnum = con.conkey[1]
     where con.contype = 'f'
       and con.confrelid = 'public.profiles'::regclass
       and array_length(con.conkey, 1) = 1
       and not (n.nspname = 'public' and c.relname = 'profiles')
  loop
    execute format('delete from %I.%I where %I = any ($1)',
                   fk.schema_name, fk.table_name, fk.column_name)
      using demo_ids;
  end loop;

  -- profiles.id cascades from auth.users once all non-cascading clinical FKs
  -- have been cleared.
  delete from auth.users where id = any (demo_ids);

  -- Preserve any real staff accounts that were temporarily attached to seeded
  -- facilities, but remove clinical/demo rows owned by those facilities.
  update public.lab_worker_profiles set lab_id = null
   where lab_id = any (demo_lab_ids);
  update public.doctor_profiles set clinic_id = null
   where clinic_id = any (demo_clinic_ids);
  update public.receptionist_profiles set clinic_id = null
   where clinic_id = any (demo_clinic_ids);

  delete from public.lab_results where lab_id = any (demo_lab_ids);
  delete from public.lab_orders where lab_id = any (demo_lab_ids);
  delete from public.doctor_availability where clinic_id = any (demo_clinic_ids);
  delete from public.appointments where clinic_id = any (demo_clinic_ids);
  delete from public.encounters where clinic_id = any (demo_clinic_ids);

  delete from public.diagnostic_labs where id = any (demo_lab_ids);
  delete from public.clinics where id = any (demo_clinic_ids);
end $$;
