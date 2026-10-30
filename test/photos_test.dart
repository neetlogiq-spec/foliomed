import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/models/patient.dart';
import 'package:foliomed/models/patient_photo.dart';
import 'package:foliomed/services/photo_prep.dart';
import 'package:foliomed/services/photo_service.dart';
import 'package:foliomed/widgets/patient_photos_section.dart';
import 'package:image/image.dart' as img;

/// A noisy test photo (noise compresses badly, like real detail).
Uint8List _photo(int w, int h, {int orientation = 1}) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = (x * 7 + y * 13 + (x * y) % 97) & 0xff;
      im.setPixelRgb(x, y, v, (v * 3) & 0xff, (255 - v));
    }
  }
  if (orientation != 1) im.exif.imageIfd.orientation = orientation;
  return img.encodeJpg(im, quality: 95);
}

class _FakeService extends PhotoService {
  int uploads = 0;
  bool? lastConsent;

  @override
  Future<PreparedPhoto> prepare(Uint8List bytes, {required bool highDetail}) async =>
      preparePhoto((bytes: bytes, highDetail: highDetail));

  @override
  Future<void> upload({
    required String patientId,
    required PreparedPhoto photo,
    required String caption,
    required bool highDetail,
    required bool consent,
  }) async {
    uploads++;
    lastConsent = consent;
  }
}

void main() {
  test('fitWithin keeps the shape and never enlarges', () {
    expect(fitWithin(4000, 3000, 1600), (1600, 1200));
    expect(fitWithin(3000, 4000, 1600), (1200, 1600));
    expect(fitWithin(800, 600, 1600), (800, 600));
  });

  test('shrinks to 1600 px, re-encodes smaller, makes a 360 px thumbnail', () {
    final original = _photo(3200, 2400);
    final p = preparePhoto((bytes: original, highDetail: false));
    expect([p.width, p.height], [1600, 1200]);
    expect(p.jpeg.length, lessThan(original.length ~/ 2));
    expect(p.jpeg.length, lessThanOrEqualTo(kPhotoMaxBytes));
    final thumb = img.decodeJpg(p.thumb)!;
    expect([thumb.width, thumb.height], [360, 270]);
    expect(p.thumb.length, lessThan(60 * 1024));
  });

  test('high detail keeps up to 2560 px', () {
    final p = preparePhoto((bytes: _photo(3200, 2400), highDetail: true));
    expect([p.width, p.height], [2560, 1920]);
  });

  test('turns the photo upright and drops EXIF (location etc.)', () {
    // Orientation 6 = taken rotated 90°: a landscape file shown portrait.
    final p = preparePhoto((bytes: _photo(1200, 800, orientation: 6), highDetail: false));
    expect([p.width, p.height], [800, 1200]);
    expect(img.decodeJpgExif(p.jpeg)?.imageIfd.hasOrientation ?? false, isFalse);
  });

  test('refuses what isn’t an image', () {
    expect(() => preparePhoto((bytes: Uint8List.fromList([1, 2, 3]), highDetail: false)), throwsFormatException);
  });

  test('photo rows map; size label', () {
    final ph = PatientPhoto.fromRow({'id': 'x', 'patient_id': 'p', 'path': 'p/x.jpg', 'bytes': 245760,
        'created_at': '2026-10-30T09:00:00Z'});
    expect(ph.sizeLabel, '240 KB');
    expect(PatientPhoto.fromRow({'id': 'y', 'path': 'p/y.jpg', 'bytes': 1572864}).sizeLabel, '1.5 MB');
  });

  testWidgets('Upload stays off until consent is ticked', (t) async {
    t.view.physicalSize = const Size(2400, 5400);
    addTearDown(t.view.resetPhysicalSize);
    final service = _FakeService();
    final patient = Patient(id: 'p', name: 'A', age: 4, gender: '', wardId: 'w', bedNumber: '1',
        diagnosis: '', admittedAt: DateTime(2026, 10, 30));
    await t.pumpWidget(MaterialApp(home: AddPhotoScreen(patient: patient, original: _photo(800, 600), service: service)));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    expect(find.textContaining('location data removed'), findsOneWidget);
    final upload = find.widgetWithText(FilledButton, 'Upload');
    expect(t.widget<FilledButton>(upload).onPressed, isNull);
    await t.tap(find.text('Consent obtained'));
    await t.pump();
    expect(t.widget<FilledButton>(upload).onPressed, isNotNull);
    await t.tap(upload);
    await t.pump();
    expect([service.uploads, service.lastConsent], [1, true]);
  });
}
