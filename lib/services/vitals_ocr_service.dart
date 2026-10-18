import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

// ML Kit only available on iOS/Android — guarded below
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    if (dart.library.html) 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/monitor_vitals.dart';

class ParsedVitals {
  final double? hr;
  final double? spo2;
  final double? rr;
  final double? sbp;
  final double? dbp;
  final DateTime timestamp;
  final int confidence;

  const ParsedVitals({
    this.hr,
    this.spo2,
    this.rr,
    this.sbp,
    this.dbp,
    required this.timestamp,
    this.confidence = 0,
  });

  double? get map => (sbp != null && dbp != null)
      ? ((sbp! + 2 * dbp!) / 3).roundToDouble()
      : null;

  Map<VitalType, double> toVitalMap() {
    final m = <VitalType, double>{};
    if (hr != null) m[VitalType.hr] = hr!;
    if (spo2 != null) m[VitalType.spo2] = spo2!;
    if (rr != null) m[VitalType.rr] = rr!;
    if (sbp != null) m[VitalType.sbp] = sbp!;
    if (dbp != null) m[VitalType.dbp] = dbp!;
    final mapVal = map;
    if (mapVal != null) m[VitalType.map] = mapVal;
    return m;
  }

  bool get hasAnyVital => hr != null || spo2 != null || rr != null || sbp != null;

  @override
  String toString() => 'HR:$hr SpO2:$spo2 RR:$rr BP:$sbp/$dbp (conf:$confidence)';
}

class VitalsOcrService {
  // ML Kit recognizer — only created on iOS/Android
  TextRecognizer? _recognizer;
  bool _isProcessing = false;

  // macOS uses Apple Vision via a method channel
  static const _channel = MethodChannel('com.foliomed.app/vision_ocr');

  VitalsOcrService() {
    if (Platform.isIOS || Platform.isAndroid) {
      _recognizer = TextRecognizer();
    }
  }

  bool get isProcessing => _isProcessing;

  Future<ParsedVitals?> processFrame(CameraImage image, CameraDescription camera) async {
    if (!Platform.isIOS && !Platform.isAndroid) return null;
    if (_isProcessing) return null;
    _isProcessing = true;
    try {
      final inputImage = _buildInputImage(image, camera);
      if (inputImage == null) return null;
      final result = await _recognizer!.processImage(inputImage);
      return _parseVitalsFromText(result.text);
    } catch (_) {
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  Future<ParsedVitals?> processFile(File imageFile) async {
    if (_isProcessing) return null;
    _isProcessing = true;
    try {
      if (Platform.isMacOS) {
        return await _processFileMacOS(imageFile);
      }
      final inputImage = InputImage.fromFile(imageFile);
      final result = await _recognizer!.processImage(inputImage);
      return _parseVitalsFromText(result.text);
    } catch (_) {
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// macOS: call Apple Vision text recognition via Swift method channel.
  Future<ParsedVitals?> _processFileMacOS(File imageFile) async {
    try {
      final text = await _channel.invokeMethod<String>(
        'recognizeText',
        {'path': imageFile.path},
      );
      if (text == null || text.isEmpty) return null;
      return _parseVitalsFromText(text);
    } on PlatformException {
      // Channel not yet wired — fall back to tesseract if installed
      return _processFileTesseract(imageFile);
    }
  }

  Future<ParsedVitals?> _processFileTesseract(File imageFile) async {
    try {
      const paths = ['/usr/local/bin/tesseract', '/opt/homebrew/bin/tesseract'];
      String? tesseract;
      for (final p in paths) {
        if (File(p).existsSync()) { tesseract = p; break; }
      }
      if (tesseract == null) return null;
      final result = await Process.run(tesseract, [imageFile.path, 'stdout', '--psm', '6']);
      if (result.exitCode != 0) return null;
      return _parseVitalsFromText(result.stdout as String);
    } catch (_) {
      return null;
    }
  }

  InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null) return null;
    final rotation = _rotationFromCamera(camera);
    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: ui.Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageRotation _rotationFromCamera(CameraDescription camera) {
    switch (camera.sensorOrientation) {
      case 90:  return InputImageRotation.rotation90deg;
      case 180: return InputImageRotation.rotation180deg;
      case 270: return InputImageRotation.rotation270deg;
      default:  return InputImageRotation.rotation0deg;
    }
  }

  ParsedVitals _parseVitalsFromText(String rawText) {
    double? hr, spo2, rr, sbp, dbp;
    int confidence = 0;
    final text = rawText.toUpperCase();
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    for (final line in lines) {
      // BP: "120/80"
      if (sbp == null) {
        final bp = RegExp(r'(\d{2,3})\s*/\s*(\d{2,3})').firstMatch(line);
        if (bp != null) {
          final s = double.tryParse(bp.group(1)!);
          final d = double.tryParse(bp.group(2)!);
          if (s != null && d != null && s > 30 && s < 260 && d > 15 && d < 160 && s > d) {
            sbp = s; dbp = d; confidence += 25;
          }
        }
      }

      if (hr == null && _hasLabel(line, ['HR', 'HEART', 'PULSE'])) {
        final v = _extractNum(line, 30, 220);
        if (v != null) { hr = v; confidence += 25; }
      }
      if (spo2 == null && _hasLabel(line, ['SPO2', 'SP02', 'SPO', 'O2', 'SAT'])) {
        final v = _extractNum(line, 50, 100);
        if (v != null) { spo2 = v; confidence += 25; }
      }
      if (rr == null && _hasLabel(line, ['RR', 'RESP', 'BREATH'])) {
        final v = _extractNum(line, 4, 80);
        if (v != null) { rr = v; confidence += 25; }
      }
      if (sbp == null && _hasLabel(line, ['SYS', 'NIBP', 'ART'])) {
        final v = _extractNum(line, 40, 260);
        if (v != null) { sbp = v; confidence += 15; }
      }
      if (dbp == null && _hasLabel(line, ['DIA'])) {
        final v = _extractNum(line, 15, 160);
        if (v != null) { dbp = v; confidence += 10; }
      }
    }

    // Positional fallback
    if (hr == null || spo2 == null) {
      final nums = RegExp(r'\b(\d{2,3})\b').allMatches(text)
          .map((m) => double.tryParse(m.group(1)!))
          .whereType<double>()
          .toList();
      for (final n in nums) {
        if (hr == null && n >= 40 && n <= 220) { hr = n; confidence += 8; }
        else if (spo2 == null && n >= 70 && n <= 100) { spo2 = n; confidence += 8; }
        else if (rr == null && n >= 6 && n <= 80) { rr = n; confidence += 5; }
      }
    }

    return ParsedVitals(hr: hr, spo2: spo2, rr: rr, sbp: sbp, dbp: dbp,
        timestamp: DateTime.now(), confidence: confidence.clamp(0, 100));
  }

  bool _hasLabel(String text, List<String> labels) =>
      labels.any((l) => text.contains(l));

  double? _extractNum(String text, double min, double max) {
    for (final m in RegExp(r'\d+\.?\d*').allMatches(text)) {
      final v = double.tryParse(m.group(0)!);
      if (v != null && v >= min && v <= max) return v;
    }
    return null;
  }

  void dispose() {
    _recognizer?.close();
  }
}
