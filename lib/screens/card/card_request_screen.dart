import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/card_controller.dart';
import '../../services/card_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/brand_app_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// In-app crop dialog  (pure Flutter — works on Web, Android, iOS)
// ─────────────────────────────────────────────────────────────────────────────

/// Shows a full-screen drag-to-crop dialog. Returns the cropped PNG bytes
/// (square) or null if the user cancels.
Future<Uint8List?> showCropDialog(BuildContext context, Uint8List imageBytes) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CropDialog(imageBytes: imageBytes),
  );
}

class _CropDialog extends StatefulWidget {
  final Uint8List imageBytes;
  const _CropDialog({required this.imageBytes});

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  Offset _cropOffset = Offset.zero;
  double _cropSize = 0;
  bool _imageReady = false;
  Size _imageSize = Size.zero;
  Size _displaySize = Size.zero;
  bool _cropInitialized = false;

  @override
  void initState() {
    super.initState();
    _decodeImageSize();
  }

  Future<void> _decodeImageSize() async {
    final provider = MemoryImage(widget.imageBytes);
    final stream = provider.resolve(const ImageConfiguration());
    final completer = Completer<ui.Image>();
    stream.addListener(ImageStreamListener((info, _) {
      if (!completer.isCompleted) completer.complete(info.image);
    }));
    final img = await completer.future;
    if (mounted) {
      setState(() {
        _imageSize = Size(img.width.toDouble(), img.height.toDouble());
        _imageReady = true;
      });
    }
  }

  void _initCrop(Size layoutSize) {
    if (_cropInitialized || _imageSize == Size.zero) return;

    final imgAspect = _imageSize.width / _imageSize.height;
    final layoutAspect = layoutSize.width / layoutSize.height;

    if (imgAspect > layoutAspect) {
      _displaySize = Size(layoutSize.width, layoutSize.width / imgAspect);
    } else {
      _displaySize = Size(layoutSize.height * imgAspect, layoutSize.height);
    }

    _cropSize = math.min(_displaySize.width, _displaySize.height) * 0.85;
    _cropOffset = Offset(
      (_displaySize.width - _cropSize) / 2,
      (_displaySize.height - _cropSize) / 2,
    );
    _cropInitialized = true;
  }

  Future<void> _confirm() async {
    if (_imageSize == Size.zero || _displaySize == Size.zero) return;

    final scaleX = _imageSize.width / _displaySize.width;
    final scaleY = _imageSize.height / _displaySize.height;

    final srcX = (_cropOffset.dx * scaleX).round().clamp(0, _imageSize.width.toInt() - 1);
    final srcY = (_cropOffset.dy * scaleY).round().clamp(0, _imageSize.height.toInt() - 1);
    final srcSize = (_cropSize * scaleX)
        .round()
        .clamp(1, math.min(_imageSize.width - srcX, _imageSize.height - srcY).toInt());

    // Decode and crop using dart:ui
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    final srcImg = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
        recorder, Rect.fromLTWH(0, 0, srcSize.toDouble(), srcSize.toDouble()));
    canvas.drawImageRect(
      srcImg,
      Rect.fromLTWH(srcX.toDouble(), srcY.toDouble(), srcSize.toDouble(), srcSize.toDouble()),
      Rect.fromLTWH(0, 0, srcSize.toDouble(), srcSize.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(srcSize, srcSize);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData?.buffer.asUint8List();

    if (mounted) Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Column(
        children: [
          // Toolbar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context, null),
                  tooltip: 'Cancel',
                ),
                const Spacer(),
                Text('Crop Photo',
                    style: AppText.bodyStrong.copyWith(color: Colors.white)),
                const Spacer(),
                TextButton(
                  onPressed: _imageReady ? _confirm : null,
                  child: Text('Done',
                      style: AppText.bodyStrong.copyWith(color: c.primary)),
                ),
              ]),
            ),
          ),

          // Image + crop overlay
          Expanded(
            child: _imageReady
                ? LayoutBuilder(builder: (ctx, constraints) {
                    _initCrop(constraints.biggest);
                    return GestureDetector(
                      onPanUpdate: (d) {
                        setState(() {
                          _cropOffset = Offset(
                            (_cropOffset.dx + d.delta.dx)
                                .clamp(0, _displaySize.width - _cropSize),
                            (_cropOffset.dy + d.delta.dy)
                                .clamp(0, _displaySize.height - _cropSize),
                          );
                        });
                      },
                      child: Stack(children: [
                        Center(
                          child: SizedBox(
                            width: _displaySize.width,
                            height: _displaySize.height,
                            child: Image.memory(widget.imageBytes,
                                fit: BoxFit.contain),
                          ),
                        ),
                        Positioned.fill(
                          child: _CropOverlay(
                            displaySize: _displaySize,
                            cropOffset: _cropOffset,
                            cropSize: _cropSize,
                            layoutSize: constraints.biggest,
                          ),
                        ),
                        // Crop-box border + drag hint
                        Positioned(
                          left: (constraints.maxWidth - _displaySize.width) / 2 +
                              _cropOffset.dx,
                          top: (constraints.maxHeight - _displaySize.height) / 2 +
                              _cropOffset.dy,
                          width: _cropSize,
                          height: _cropSize,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: c.primary, width: 2.5),
                            ),
                            child: const Center(
                              child: Icon(Icons.open_with,
                                  color: Colors.white54, size: 28),
                            ),
                          ),
                        ),
                      ]),
                    );
                  })
                : const Center(child: CircularProgressIndicator()),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Drag the box to adjust • Square crop',
                  style: AppText.caption.copyWith(color: Colors.white54)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Semi-transparent overlay with a clear crop square and rule-of-thirds grid.
class _CropOverlay extends StatelessWidget {
  final Size displaySize;
  final Offset cropOffset;
  final double cropSize;
  final Size layoutSize;

  const _CropOverlay({
    required this.displaySize,
    required this.cropOffset,
    required this.cropSize,
    required this.layoutSize,
  });

  @override
  Widget build(BuildContext context) {
    final imageLeft = (layoutSize.width - displaySize.width) / 2;
    final imageTop = (layoutSize.height - displaySize.height) / 2;
    return CustomPaint(
      painter: _OverlayPainter(
        imageRect: Rect.fromLTWH(
            imageLeft, imageTop, displaySize.width, displaySize.height),
        cropRect: Rect.fromLTWH(imageLeft + cropOffset.dx,
            imageTop + cropOffset.dy, cropSize, cropSize),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final Rect imageRect;
  final Rect cropRect;
  _OverlayPainter({required this.imageRect, required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.62);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, cropRect.top), dark);
    canvas.drawRect(Rect.fromLTRB(0, cropRect.top, cropRect.left, cropRect.bottom), dark);
    canvas.drawRect(Rect.fromLTRB(cropRect.right, cropRect.top, size.width, cropRect.bottom), dark);
    canvas.drawRect(Rect.fromLTRB(0, cropRect.bottom, size.width, size.height), dark);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.7;
    final step = cropRect.width / 3;
    for (int i = 1; i <= 2; i++) {
      final x = cropRect.left + step * i;
      final y = cropRect.top + step * i;
      canvas.drawLine(Offset(x, cropRect.top), Offset(x, cropRect.bottom), grid);
      canvas.drawLine(Offset(cropRect.left, y), Offset(cropRect.right, y), grid);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.cropRect != cropRect || old.imageRect != imageRect;
}

// ─────────────────────────────────────────────────────────────────────────────
// Card Request Screen
// ─────────────────────────────────────────────────────────────────────────────

class CardRequestScreen extends StatefulWidget {
  const CardRequestScreen({super.key});

  @override
  State<CardRequestScreen> createState() => _CardRequestScreenState();
}

class _CardRequestScreenState extends State<CardRequestScreen> {
  final _service = CardService();
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  DateTime? _dob;
  String _blood = 'unknown';
  Uint8List? _photoBytes;
  String? _existingPhotoUrl;
  bool _busy = false;
  String? _error;

  static const _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'unknown'
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final authUser = context.read<AuthController>().currentUser;
    final cardCtrl = context.read<CardController>();

    if (cardCtrl.hasCard) {
      final card = cardCtrl.card!;
      setState(() {
        _nameCtrl.text = card.nameEn ?? authUser?.name ?? '';
        _cityCtrl.text = card.city ?? '';
        if (card.dateOfBirth != null) _dob = DateTime.tryParse(card.dateOfBirth!);
        if (card.bloodGroup != null && _bloodGroups.contains(card.bloodGroup)) {
          _blood = card.bloodGroup!;
        }
        _existingPhotoUrl = card.photoUrl;
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = prefs.getString('card_name') ?? authUser?.name ?? '';
      _cityCtrl.text = prefs.getString('card_city') ?? '';
      final cachedDob = prefs.getString('card_dob');
      if (cachedDob != null) _dob = DateTime.tryParse(cachedDob);
      final cachedBlood = prefs.getString('card_blood');
      if (cachedBlood != null && _bloodGroups.contains(cachedBlood)) {
        _blood = cachedBlood;
      }
      final cachedPhoto = prefs.getString('card_photo_url');
      _existingPhotoUrl = cachedPhoto != null && cachedPhoto.startsWith('http') ? cachedPhoto : null;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    // withData: true ensures bytes are ALWAYS returned (required on web where path is null)
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (!mounted || res == null || res.files.isEmpty) return;

    final bytes = res.files.single.bytes;
    if (bytes == null || bytes.isEmpty) return;

    // Open in-app crop dialog (pure Flutter, works everywhere)
    final cropped = await showCropDialog(context, bytes);
    if (!mounted || cropped == null) return;

    setState(() {
      _photoBytes = cropped;
      _existingPhotoUrl = null;
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (_dob == null) {
      setState(() => _error = 'Please select your date of birth.');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      String? photoUrl = _existingPhotoUrl;
      if (_photoBytes != null) photoUrl = await _service.uploadPhoto(_photoBytes!);

      final dobStr = _dob!.toIso8601String().substring(0, 10);
      final card = await _service.requestCard(
        nameEn: _nameCtrl.text.trim(),
        dob: dobStr,
        bloodGroup: _blood,
        city: _cityCtrl.text.trim(),
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('card_name', _nameCtrl.text.trim());
      await prefs.setString('card_dob', dobStr);
      await prefs.setString('card_blood', _blood);
      await prefs.setString('card_city', _cityCtrl.text.trim());
      await prefs.remove('card_photo_url');

      if (!mounted) return;
      context.read<CardController>().setCard(card);
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Your card ${card.cardNumber} is ready!')),
      );
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: const BrandAppBar(title: 'Request your card'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        children: [
          Text('A few details to print on your HayaatID card.',
              style: AppText.body.copyWith(color: c.text2)),
          const SizedBox(height: 20),

          // Photo picker
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: c.surfaceAlt,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.primary, width: 2.5),
                      image: _photoBytes != null
                          ? DecorationImage(
                              image: MemoryImage(_photoBytes!), fit: BoxFit.cover)
                          : (_existingPhotoUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(_existingPhotoUrl!),
                                  fit: BoxFit.cover)
                              : null),
                    ),
                    alignment: Alignment.center,
                    child: (_photoBytes == null && _existingPhotoUrl == null)
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_a_photo_outlined, color: c.primary, size: 30),
                            const SizedBox(height: 5),
                            Text('Add photo',
                                style: AppText.caption.copyWith(color: c.primary)),
                          ])
                        : null,
                  ),
                  if (_photoBytes != null || _existingPhotoUrl != null)
                    Container(
                      width: 32, height: 32,
                      margin: const EdgeInsets.only(right: 4, bottom: 4),
                      decoration: BoxDecoration(
                        color: c.primary, shape: BoxShape.circle,
                        border: Border.all(color: c.bg, width: 2),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 15),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              (_photoBytes != null || _existingPhotoUrl != null)
                  ? 'Tap to replace photo'
                  : 'Clear background • good lighting • straight face',
              style: AppText.small.copyWith(color: c.text3),
            ),
          ),
          const SizedBox(height: 22),

          _label(context, 'Name on Card'),
          TextField(controller: _nameCtrl, decoration: _dec(context, 'Full name in English')),
          const SizedBox(height: 4),
          Text('We print the Urdu version automatically.',
              style: AppText.small.copyWith(color: c.text3)),
          const SizedBox(height: 16),

          _label(context, 'Date of birth'),
          InkWell(
            onTap: _pickDob,
            child: Container(
              height: 52, padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    _dob == null ? 'Select date' : _dob!.toIso8601String().substring(0, 10),
                    style: AppText.body.copyWith(color: _dob == null ? c.text3 : c.text),
                  ),
                ),
                Icon(Icons.calendar_today_outlined, size: 18, color: c.text3),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          _label(context, 'Blood group'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
                color: c.surface, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _blood, isExpanded: true,
                items: _bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (v) => setState(() => _blood = v ?? 'unknown'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _label(context, 'City'),
          TextField(controller: _cityCtrl, decoration: _dec(context, 'e.g. Islamabad')),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: AppText.caption.copyWith(color: c.danger)),
          ],
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                  backgroundColor: c.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _busy
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Generate my card',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: AppText.caption
                .copyWith(color: context.c.text2, fontWeight: FontWeight.w700)),
      );

  InputDecoration _dec(BuildContext context, String hint) => InputDecoration(
        hintText: hint, filled: true, fillColor: context.c.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.c.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.c.border)),
      );
}
