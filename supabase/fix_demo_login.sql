-- ============================================================================
--  Fix demo-account login (run once in the SQL Editor)
--
--  The seeded demo accounts were inserted into auth.users directly, which left
--  some token columns NULL. GoTrue can't read NULL there, so login returned
--  500 "Database error querying schema". This sets them to empty strings.
--  (New sign-ups from the app are unaffected — Supabase fills these itself.)
-- ============================================================================
update auth.users set
  confirmation_token        = coalesce(confirmation_token, ''),
  recovery_token            = coalesce(recovery_token, ''),
  email_change              = coalesce(email_change, ''),
  email_change_token_new    = coalesce(email_change_token_new, ''),
  email_change_token_current = coalesce(email_change_token_current, ''),
  phone_change              = coalesce(phone_change, ''),
  phone_change_token        = coalesce(phone_change_token, ''),
  reauthentication_token    = coalesce(reauthentication_token, '')
where email like '%@hayaat.id';
