import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/auth_model.dart';
import '../models/record_models.dart';

/// Patient identity printed in the header of every exported document.
class PdfPatientInfo {
  final String name;
  final String hayaatId;
  final String cnic;
  final String dob;
  final String gender;
  final String bloodGroup;
  final String phone;

  const PdfPatientInfo({
    required this.name,
    this.hayaatId = '',
    this.cnic = '',
    this.dob = '',
    this.gender = '',
    this.bloodGroup = '',
    this.phone = '',
  });

  factory PdfPatientInfo.fromUser(UserModel? u) => PdfPatientInfo(
    name: u?.name ?? '',
    hayaatId: u?.cardNumber ?? u?.healthId ?? '',
    cnic: u?.cnic ?? '',
    dob: u?.dob ?? '',
    gender: u?.gender ?? '',
    bloodGroup: u?.bloodGroup ?? '',
    phone: u?.phone ?? '',
  );
}

/// Loads a Unicode-capable font pair for the PDF theme. Returns null to fall
/// back to the built-in Helvetica (Latin-only) fonts.
typedef PdfFontLoader = Future<pw.ThemeData?> Function();

/// Builds branded, shareable PDF documents from the patient's records.
///
/// Every builder returns raw PDF bytes; [share] and [print] hand them to the
/// platform (share sheet / file download / print dialog).
class ReportPdfService {
  ReportPdfService({PdfFontLoader? fontLoader, http.Client? client})
    : _fontLoader = fontLoader ?? _googleFonts,
      _client = client ?? http.Client();

  final PdfFontLoader _fontLoader;
  final http.Client _client;

  static const brand = PdfColor.fromInt(0xFF0E7A6E);
  static const brandSoft = PdfColor.fromInt(0xFFE4F4EC);
  static const ink = PdfColor.fromInt(0xFF0F201B);
  static const ink2 = PdfColor.fromInt(0xFF5C6B66);
  static const line = PdfColor.fromInt(0xFFE6ECE9);

  static Future<pw.ThemeData?> _googleFonts() async {
    try {
      final base = await PdfGoogleFonts.notoSansRegular();
      final bold = await PdfGoogleFonts.notoSansBold();
      return pw.ThemeData.withFont(base: base, bold: bold);
    } catch (_) {
      return null;
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> share(Uint8List bytes, String filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename);

  Future<void> print(Uint8List bytes, String filename) =>
      Printing.layoutPdf(onLayout: (_) async => bytes, name: filename);

  /// A safe file name like `hayaat_prescription_2026-09-04.pdf`.
  static String fileName(String label, [DateTime? date]) {
    final slug = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final d = DateFormat('yyyy-MM-dd').format(date ?? DateTime.now());
    return 'hayaat_${slug.isEmpty ? 'document' : slug}_$d.pdf';
  }

  /// One record from the record library. Original uploaded PDFs are returned
  /// as-is; images are embedded on pages; structured records are rendered.
  Future<Uint8List> buildRecordPdf(
    MedicalRecordModel record,
    PdfPatientInfo patient,
  ) async {
    if (record.hasOriginalDocument) {
      final firstName = record.fileNames.isNotEmpty ? record.fileNames.first : '';
      final firstMime = record.mimeTypes.isNotEmpty ? record.mimeTypes.first : '';
      final isPdf =
          firstMime == 'application/pdf' ||
          firstName.toLowerCase().endsWith('.pdf');
      if (isPdf && record.fileUrls.length == 1) {
        return _fetch(record.fileUrls.first);
      }
      return _imagesPdf(record, patient);
    }
    return _structuredPdf(record, patient);
  }

  /// A finalized visit: symptoms, diagnosis, medicines, follow-up, advice.
  Future<Uint8List> buildVisitPdf(VisitModel v, PdfPatientInfo patient) async {
    final doc = await _document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(),
        footer: _footer,
        build: (ctx) => [
          _header('Visit summary', '${v.dateLabel}${v.time.isEmpty ? '' : ' at ${v.time}'}'),
          pw.SizedBox(height: 14),
          _patientBlock(patient),
          pw.SizedBox(height: 16),
          _kv([
            ['Diagnosis', _v(v.dx)],
            ['Doctor', _v(v.doctor)],
            ['Specialty', _v(v.specialty)],
            ['Hospital / clinic', _v(v.hospital)],
          ]),
          _section('Symptoms', pw.Text(_v(v.symptoms), style: _body)),
          _section(
            'Diagnosis',
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_v(v.diagnosis), style: _bodyStrong),
                if (v.diagnosisNote.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(v.diagnosisNote, style: _muted),
                ],
              ],
            ),
          ),
          _section(
            'Medicines',
            v.meds.isEmpty
                ? pw.Text('None prescribed.', style: _muted)
                : _table(
                    ['#', 'Medicine', 'Strength', 'Frequency', 'Duration'],
                    [
                      for (var i = 0; i < v.meds.length; i++)
                        [
                          '${i + 1}',
                          v.meds[i].name,
                          v.meds[i].strength,
                          v.meds[i].freq,
                          v.meds[i].dur,
                        ],
                    ],
                  ),
          ),
          _section(
            'Follow-up',
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(_v(v.followUp), style: _bodyStrong),
                if (v.advice.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(v.advice, style: _body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// The whole patient-held record in one document.
  Future<Uint8List> buildHealthRecordPdf({
    required PdfPatientInfo patient,
    required List<VisitModel> visits,
    required List<PrescriptionModel> prescriptions,
    required List<ReportModel> reports,
    required List<Map<String, dynamic>> allergies,
  }) async {
    final doc = await _document();
    final active = prescriptions.where((p) => p.active).toList();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(),
        footer: _footer,
        build: (ctx) => [
          _header(
            'Health record summary',
            'Generated ${DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now())}',
          ),
          pw.SizedBox(height: 14),
          _patientBlock(patient, full: true),
          _section(
            'Allergies',
            allergies.isEmpty
                ? pw.Text('No allergies recorded.', style: _muted)
                : _table(
                    ['Substance', 'Category', 'Criticality', 'Reaction', 'Status'],
                    [
                      for (final a in allergies)
                        [
                          _s(a['substance_name'] ?? a['name']),
                          _s(a['category']),
                          _s(a['criticality'] ?? a['severity']),
                          _s(a['reaction_description'] ?? a['reaction']),
                          _s(a['clinical_status'] ?? a['status']),
                        ],
                    ],
                    widths: {0: 2.2, 3: 3},
                  ),
          ),
          _section(
            'Active medicines',
            active.isEmpty
                ? pw.Text('No active medicines.', style: _muted)
                : _table(
                    ['Medicine', 'Strength', 'Frequency', 'Duration', 'Prescribed by', 'Since'],
                    [
                      for (final p in active)
                        [p.name, p.strength, p.freq, p.dur, p.by, p.date],
                    ],
                    widths: {0: 2.2, 4: 2},
                  ),
          ),
          _section(
            'Visits',
            visits.isEmpty
                ? pw.Text('No finalized visits yet.', style: _muted)
                : _table(
                    ['Date', 'Doctor', 'Specialty', 'Diagnosis', 'Hospital / clinic'],
                    [
                      for (final v in visits)
                        [v.dateLabel, v.doctor, v.specialty, v.dx, v.hospital],
                    ],
                    widths: {3: 2.4, 4: 2},
                  ),
          ),
          _section(
            'Laboratory reports',
            reports.isEmpty
                ? pw.Text('No lab reports.', style: _muted)
                : _table(
                    ['Date', 'Test', 'Laboratory', 'Status'],
                    [
                      for (final r in reports)
                        [r.date, r.name, r.lab, r.status.replaceAll('_', ' ')],
                    ],
                    widths: {1: 2.2, 2: 2.2},
                  ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  // ── Record renderers ───────────────────────────────────────────────────────

  Future<Uint8List> _structuredPdf(
    MedicalRecordModel r,
    PdfPatientInfo patient,
  ) async {
    final doc = await _document();
    final date = DateFormat('d MMMM yyyy').format(r.date);
    final isRx = r.type == MedicalRecordType.prescription;
    doc.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(),
        footer: _footer,
        build: (ctx) => [
          _header(isRx ? 'Prescription' : r.type.label, date),
          pw.SizedBox(height: 14),
          _patientBlock(patient),
          pw.SizedBox(height: 16),
          _kv([
            if (!isRx) ['Title', _v(r.title)],
            if (r.doctor.isNotEmpty) ['Doctor', r.doctor],
            if (r.facility.isNotEmpty) ['Hospital / clinic', r.facility],
          ]),
          if (isRx) ..._prescriptionBody(r) else ..._genericBody(r),
        ],
      ),
    );
    return doc.save();
  }

  List<pw.Widget> _prescriptionBody(MedicalRecordModel r) {
    final meds = (r.details['medications'] as List? ?? const [])
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
    final sigName = _s(r.details['signatureName']);
    final sigCred = _s(r.details['signatureCredentials']);
    final sigFoot = _s(r.details['signatureFooter']);
    return [
      pw.SizedBox(height: 6),
      pw.Text('Rx', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: brand)),
      pw.SizedBox(height: 6),
      for (var i = 0; i < meds.length; i++) ...[
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${i + 1}.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: brand)),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_s(meds[i]['name'], 'Medicine'), style: _bodyStrong.copyWith(fontSize: 12)),
                  pw.Text(
                    [
                      meds[i]['strength'],
                      meds[i]['route'],
                      meds[i]['frequency'],
                      meds[i]['duration'],
                    ].map(_s).where((e) => e.isNotEmpty).join('  |  '),
                    style: _muted,
                  ),
                  if (_s(meds[i]['instructions']).isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Text(_s(meds[i]['instructions']), style: _body),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (i < meds.length - 1) pw.Divider(color: line, height: 16),
      ],
      if (r.summary.isNotEmpty) _section('Clinical advice', pw.Text(r.summary, style: _body)),
      pw.SizedBox(height: 30),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Container(width: 160, height: 0.8, color: ink2),
            pw.SizedBox(height: 4),
            pw.Text(sigName.isNotEmpty ? sigName : r.doctor, style: _bodyStrong),
            if (sigCred.isNotEmpty) pw.Text(sigCred, style: _muted),
            if (sigFoot.isNotEmpty) pw.Text(sigFoot, style: _muted.copyWith(fontSize: 8)),
          ],
        ),
      ),
    ];
  }

  List<pw.Widget> _genericBody(MedicalRecordModel r) {
    final out = <pw.Widget>[];
    if (r.summary.isNotEmpty) {
      out.add(_section('Summary', pw.Text(r.summary, style: _body)));
    }
    for (final e in r.details.entries) {
      final v = e.value;
      if (v == null || v.toString().isEmpty || (v is List && v.isEmpty)) continue;
      if (v is List && v.isNotEmpty && v.first is Map) {
        final rows = v.map((m) => Map<String, dynamic>.from(m as Map)).toList();
        final keys = <String>{for (final m in rows) ...m.keys.map((k) => k.toString())}.toList();
        out.add(
          _section(
            _title(e.key),
            _table(
              keys.map(_title).toList(),
              [for (final m in rows) keys.map((k) => _s(m[k])).toList()],
            ),
          ),
        );
      } else if (v is List) {
        out.add(
          _section(
            _title(e.key),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [for (final item in v) pw.Bullet(text: item.toString(), style: _body)],
            ),
          ),
        );
      } else {
        out.add(_section(_title(e.key), pw.Text(v.toString(), style: _body)));
      }
    }
    if (out.isEmpty) out.add(_section('Details', pw.Text('No additional details.', style: _muted)));
    return out;
  }

  Future<Uint8List> _imagesPdf(MedicalRecordModel r, PdfPatientInfo patient) async {
    final doc = await _document();
    final date = DateFormat('d MMMM yyyy').format(r.date);
    for (var i = 0; i < r.fileUrls.length; i++) {
      final name = i < r.fileNames.length ? r.fileNames[i] : 'File ${i + 1}';
      final mime = i < r.mimeTypes.length ? r.mimeTypes[i] : '';
      final isPdf = mime == 'application/pdf' || name.toLowerCase().endsWith('.pdf');
      pw.Widget body;
      if (isPdf) {
        body = pw.Text(
          'The original PDF "$name" is attached to this record in the app and must be exported on its own.',
          style: _muted,
        );
      } else {
        try {
          final bytes = await _fetch(r.fileUrls[i]);
          body = pw.Expanded(
            child: pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
          );
        } catch (_) {
          body = pw.Text('The file "$name" could not be downloaded.', style: _muted);
        }
      }
      doc.addPage(
        pw.Page(
          pageTheme: _pageTheme(),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _header(r.type.label, '$date  |  ${_v(r.title)}'),
              pw.SizedBox(height: 10),
              _patientBlock(patient),
              pw.SizedBox(height: 10),
              pw.Text(name, style: _muted),
              pw.SizedBox(height: 6),
              body,
            ],
          ),
        ),
      );
    }
    return doc.save();
  }

  // ── Building blocks ────────────────────────────────────────────────────────

  Future<pw.Document> _document() async {
    final theme = await _fontLoader();
    return pw.Document(
      theme: theme,
      title: 'HayaatID record',
      author: 'HayaatID',
      creator: 'HayaatID Health Platform',
    );
  }

  pw.PageTheme _pageTheme() => const pw.PageTheme(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
  );

  pw.Widget _header(String title, String subtitle) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    decoration: const pw.BoxDecoration(
      color: brand,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'HAYAAT ID',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                title,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 19,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (subtitle.isNotEmpty)
                pw.Text(subtitle, style: const pw.TextStyle(color: PdfColors.white, fontSize: 9.5)),
            ],
          ),
        ),
        pw.Text(
          "Pakistan's Digital\nHealth Card",
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(color: PdfColors.white, fontSize: 8.5),
        ),
      ],
    ),
  );

  pw.Widget _patientBlock(PdfPatientInfo p, {bool full = false}) {
    final rows = <List<String>>[
      ['Patient', _v(p.name)],
      if (p.hayaatId.isNotEmpty) ['Hayaat ID', _fmtId(p.hayaatId)],
      if (p.cnic.isNotEmpty) ['CNIC', _fmtCnic(p.cnic)],
      if (full && p.dob.isNotEmpty) ['Date of birth', p.dob],
      if (full && p.gender.isNotEmpty) ['Gender', _title(p.gender)],
      if (p.bloodGroup.isNotEmpty) ['Blood group', p.bloodGroup],
      if (full && p.phone.isNotEmpty) ['Phone', p.phone],
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const pw.BoxDecoration(
        color: brandSoft,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Wrap(
        spacing: 26,
        runSpacing: 6,
        children: [
          for (final r in rows)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(r[0].toUpperCase(), style: pw.TextStyle(fontSize: 7, color: ink2, letterSpacing: 0.8)),
                pw.Text(r[1], style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: ink)),
              ],
            ),
        ],
      ),
    );
  }

  pw.Widget _kv(List<List<String>> rows) {
    if (rows.isEmpty) return pw.SizedBox();
    return pw.Table(
      columnWidths: const {0: pw.FixedColumnWidth(120), 1: pw.FlexColumnWidth()},
      children: [
        for (final r in rows)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(r[0], style: _muted),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(r[1], style: _bodyStrong),
              ),
            ],
          ),
      ],
    );
  }

  pw.Widget _section(String title, pw.Widget child) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(height: 16),
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: brand, letterSpacing: 1.1),
      ),
      pw.Container(height: 0.8, color: line, margin: const pw.EdgeInsets.symmetric(vertical: 6)),
      child,
    ],
  );

  pw.Widget _table(List<String> headers, List<List<String>> data, {Map<int, double> widths = const {}}) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: ink),
      headerDecoration: const pw.BoxDecoration(color: brandSoft),
      cellStyle: const pw.TextStyle(fontSize: 9, color: ink),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      border: pw.TableBorder.all(color: line, width: 0.6),
      columnWidths: {
        for (var i = 0; i < headers.length; i++) i: pw.FlexColumnWidth(widths[i] ?? 1),
      },
    );
  }

  pw.Widget _footer(pw.Context ctx) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(height: 0.6, color: line, margin: const pw.EdgeInsets.only(bottom: 5)),
      pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Generated by HayaatID on ${DateFormat('d MMM yyyy, HH:mm').format(DateTime.now())}. '
              'Patient-held copy of records stored on the HayaatID platform; not a substitute for a clinician\'s original signed document.',
              style: pw.TextStyle(fontSize: 7, color: ink2),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 7, color: ink2)),
        ],
      ),
    ],
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

  pw.TextStyle get _body => const pw.TextStyle(fontSize: 10, color: ink, lineSpacing: 2);
  pw.TextStyle get _bodyStrong => pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: ink);
  pw.TextStyle get _muted => const pw.TextStyle(fontSize: 9, color: ink2);

  String _v(String s) => s.trim().isEmpty ? '-' : s.trim();
  String _s(dynamic v, [String fallback = '']) {
    final t = v?.toString().trim() ?? '';
    return t.isEmpty ? fallback : t;
  }

  String _title(String s) {
    final words = s.replaceAll('_', ' ').replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
    return words.isEmpty ? words : words[0].toUpperCase() + words.substring(1);
  }

  String _fmtId(String id) {
    final d = id.replaceAll(RegExp(r'\D'), '');
    if (d.length != 16) return id;
    return '${d.substring(0, 4)} ${d.substring(4, 8)} ${d.substring(8, 12)} ${d.substring(12)}';
  }

  String _fmtCnic(String cnic) {
    final d = cnic.replaceAll(RegExp(r'\D'), '');
    if (d.length != 13) return cnic;
    return '${d.substring(0, 5)}-${d.substring(5, 12)}-${d.substring(12)}';
  }

  Future<Uint8List> _fetch(String url) async {
    final res = await _client.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('Could not download the file (HTTP ${res.statusCode}).');
    }
    return res.bodyBytes;
  }
}
