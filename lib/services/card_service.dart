import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/card_model.dart';
import 'supabase_client.dart';

/// HayaatID card issuance backed by Supabase (numbers, photos, virtual/physical).
class CardService {
  CardService([String? _]);

  /// Optional remove.bg API key. When set, uploaded photos get their background
  /// removed before going on the card. When empty, the photo is stored as-is.
  static const String removeBgApiKey = '';

  /// The caller's card, or null if they haven't requested one yet.
  Future<CardModel?> getMyCard() async {
    final uid = currentUid;
    if (uid == null) return null;
    final row = await db.from('cards').select().eq('profile_id', uid).maybeSingle();
    return row == null ? null : CardModel.fromJson(await _withSignedPhoto(row));
  }

  /// Issue (or update) the card. The name is entered in English; the Urdu
  /// version is generated automatically. Returns the saved card.
  Future<CardModel> requestCard({
    required String nameEn,
    required String dob,
    required String bloodGroup,
    required String city,
    String? photoUrl,
  }) async {
    final nameUr = await transliterateToUrdu(nameEn);
    final row = await db.rpc('request_card', params: {
      'p_name_en': nameEn,
      'p_name_ur': nameUr,
      'p_dob': dob,
      'p_blood_group': bloodGroup,
      'p_city': city,
      'p_photo_url': photoUrl,
    });
    final map = row is List ? row.first : row;
    return CardModel.fromJson(await _withSignedPhoto(Map<String, dynamic>.from(map)));
  }

  /// Update only the card photo (keeps profile + card pictures in sync).
  Future<void> setPhotoUrl(String url) async {
    final uid = currentUid;
    if (uid == null) return;
    await db.from('cards').update({'photo_url': url}).eq('profile_id', uid);
  }

  /// Transliterate an English name to Urdu script (Google Input Tools).
  /// Falls back to the English text if the service is unavailable.
  Future<String> transliterateToUrdu(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return clean;
    try {
      final words = clean.split(RegExp(r'\s+'));
      final out = <String>[];
      for (final w in words) {
        final uri = Uri.parse(
            'https://inputtools.google.com/request?text=${Uri.encodeQueryComponent(w)}&itc=ur-t-i0-und&num=1&ime=transliteration_en_ur');
        final res = await http.get(uri).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data is List && data.isNotEmpty && data[0] == 'SUCCESS') {
            out.add(data[1][0][1][0] as String);
            continue;
          }
        }
        out.add(w);
      }
      return out.join(' ');
    } catch (_) {
      return clean;
    }
  }

  Future<CardModel> requestPhysical({required String address, required String phone}) async {
    final row = await db.rpc('request_physical_card', params: {'p_address': address, 'p_phone': phone});
    final map = row is List ? row.first : row;
    return CardModel.fromJson(Map<String, dynamic>.from(map));
  }

  /// Upload a card photo (background removed if a remove.bg key is configured),
  /// returning the private object path stored on the card row.
  Future<String> uploadPhoto(Uint8List bytes) async {
    final processed = await _maybeRemoveBackground(bytes);
    final uid = currentUid;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.png';
    await db.storage.from('card-photos').uploadBinary(
          path,
          processed,
          fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
        );
    return path;
  }

  Future<Map<String, dynamic>> _withSignedPhoto(Map<String, dynamic> row) async {
    final copy = Map<String, dynamic>.from(row);
    final value = (copy['photo_url'] ?? '').toString();
    if (value.isEmpty || value.startsWith('http')) return copy;
    try {
      copy['photo_url'] = await db.storage.from('card-photos').createSignedUrl(value, 3600);
    } catch (_) {
      copy['photo_url'] = null;
    }
    return copy;
  }

  Future<Uint8List> _maybeRemoveBackground(Uint8List bytes) async {
    if (removeBgApiKey.isEmpty) return bytes;
    try {
      final req = http.MultipartRequest('POST', Uri.parse('https://api.remove.bg/v1.0/removebg'))
        ..headers['X-Api-Key'] = removeBgApiKey
        ..fields['size'] = 'auto'
        ..files.add(http.MultipartFile.fromBytes('image_file', bytes, filename: 'photo.png'));
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode == 200) return res.bodyBytes;
    } catch (_) {/* fall back to the original image */}
    return bytes;
  }
}
