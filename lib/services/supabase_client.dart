import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase configuration + helpers for the HayaatID app.
class SupabaseConfig {
  /// Supabase project URL. Overridable at build time with
  /// `--dart-define=SUPABASE_URL=...`; defaults to the shared development project.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://iikwdtiqvxxatrzahuzo.supabase.co',
  );

  /// Publishable key (safe to ship — RLS protects data). Overridable with
  /// `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`. Production builds MUST set it.
  static const String publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_4axuKG5-YTuZeHuuzZjuVw_cB5_h-xn',
  );

  /// Legacy anon JWT (kept as a fallback for older tooling).
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlpa3dkdGlxdnh4YXRyemFodXpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI3MjU2ODcsImV4cCI6MjA5ODMwMTY4N30.fdv7ntuU30nevZf9QPKZ2QELc8PY1GvJK5hfneQ3dbA';

  /// Maps a phone-only login to its deterministic internal auth email.
  static String emailFor(String identifier) {
    final id = identifier.trim();
    return id.contains('@') ? id : '$id@hayaat.id';
  }

  static Future<void> initialize() async {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
  }
}

/// Shortcut to the authenticated Supabase client.
SupabaseClient get db => Supabase.instance.client;

/// Current signed-in auth user id (profiles.id == auth.users.id).
String? get currentUid => db.auth.currentUser?.id;

/// Resolve a login identifier (Hayaat ID / email / phone / employee ID).
Future<String?> resolveLoginEmail(String identifier) async {
  final res = await db.rpc('login_email', params: {'p_id': identifier.trim()});
  return res as String?;
}

/// Fetch a full profile (base row + role-extended row) shaped like the old API
/// `/me` response, i.e. `{ ...base, extended: {...} }`.
Future<Map<String, dynamic>?> fetchFullProfile(String userId) async {
  final base = await db
      .from('profiles')
      .select()
      .eq('id', userId)
      .maybeSingle();
  if (base == null) return null;

  const extTable = {
    'patient': 'patient_profiles',
    'doctor': 'doctor_profiles',
    'lab_worker': 'lab_worker_profiles',
    'receptionist': 'receptionist_profiles',
    'admin': 'admin_profiles',
  };
  final table = extTable[base['role']];
  Map<String, dynamic> ext = {};
  if (table != null) {
    final row = await db.from(table).select().eq('id', userId).maybeSingle();
    if (row != null) ext = Map<String, dynamic>.from(row);
  }
  return {...Map<String, dynamic>.from(base), 'extended': ext};
}
