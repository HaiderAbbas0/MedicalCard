import 'supabase_client.dart';

/// Compliance / data-rights operations backed by Supabase
/// (`consents`, `deletion_requests`, `export_my_data()` — see supabase/compliance.sql).
class ComplianceService {
  /// Version of the legal documents currently in force. Keep in sync with
  /// `docs/legal/*` and the web apps.
  static const String legalVersion = '2026-07-04';

  /// Record acceptance of the Privacy Policy + Terms for the signed-in user.
  /// Called right after account creation. Best-effort: failures must not block
  /// sign-up (the row is stamped server-side with IP/device/time).
  Future<void> recordSignupConsent() async {
    final uid = currentUid;
    if (uid == null) return;
    await db.from('consents').insert([
      {'user_id': uid, 'document': 'privacy_policy', 'version': legalVersion},
      {'user_id': uid, 'document': 'terms', 'version': legalVersion},
    ]);
  }

  /// Full machine-readable export of everything the caller's account holds.
  Future<Map<String, dynamic>> exportMyData() async {
    final res = await db.rpc('export_my_data');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<Map<String, bool>> consentPreferences() async {
    final uid = currentUid;
    if (uid == null) return {};
    final rows = await db.from('consent_preferences').select().eq('user_id', uid) as List;
    return {
      for (final row in rows)
        (row['key'] ?? '').toString(): row['enabled'] == true,
    };
  }

  Future<void> setConsentPreference(String key, bool enabled) async {
    await db.rpc('set_consent_preference', params: {
      'p_key': key,
      'p_enabled': enabled,
    });
  }

  /// File a request to delete the account and all associated data. An admin
  /// fulfils it (the `delete-account` Edge Function performs the erasure).
  Future<void> requestAccountDeletion(String? reason) async {
    final uid = currentUid;
    if (uid == null) throw StateError('Not signed in');
    await db.from('deletion_requests').insert({
      'user_id': uid,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }
}
