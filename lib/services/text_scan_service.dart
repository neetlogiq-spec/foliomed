import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Photo → text, entirely on the device (ML Kit). The photo is never
/// uploaded or stored by FolioMed; only the text the user keeps is saved,
/// as part of their note.
class TextScanService {
  TextScanService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// ML Kit text recognition runs on Android and iOS only.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Lets the user take or choose a photo and returns the recognised text,
  /// or null if they cancelled. Throws [TextScanException] when nothing
  /// readable was found.
  Future<String?> scan(ImageSource source) async {
    final photo = await _picker.pickImage(
      source: source,
      maxWidth: 2400, // plenty for OCR, keeps memory low
      imageQuality: 90,
    );
    if (photo == null) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(photo.path));
      final text = cleanRecognizedText(result.text);
      if (text.isEmpty) {
        throw const TextScanException(
            "Couldn't find any text in that photo. Try again with the text "
            'flat, in focus and well lit.');
      }
      return text;
    } finally {
      await recognizer.close();
    }
  }
}

class TextScanException implements Exception {
  const TextScanException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Normalises OCR output: trims each line, drops empty runs, joins
/// hyphenated line breaks.
@visibleForTesting
String cleanRecognizedText(String raw) {
  final lines = raw
      .replaceAll('\r', '')
      .split('\n')
      .map((l) => l.trim())
      .toList();
  final out = StringBuffer();
  var blankRun = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty) {
      blankRun++;
      continue;
    }
    if (out.isNotEmpty) out.write(blankRun > 0 ? '\n\n' : '\n');
    blankRun = 0;
    if (line.endsWith('-') && i + 1 < lines.length && lines[i + 1].isNotEmpty) {
      out.write(line.substring(0, line.length - 1));
      // Next line continues the same word.
      out.write(lines[i + 1]);
      i++;
      continue;
    }
    out.write(line);
  }
  return out.toString();
}
