import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Shrinking a clinical photo before upload, so it costs little data and
/// storage: the long side is capped ([kPhotoMaxSide], or
/// [kPhotoHighDetailSide] for X-rays and fine detail), it's re-encoded as
/// JPEG (which also drops EXIF metadata such as GPS location), and a small
/// thumbnail is made for lists. Typical phone photo: 3–6 MB → about
/// 150–350 KB (+ ~20 KB thumbnail).
const int kPhotoMaxSide = 1600;
const int kPhotoHighDetailSide = 2560;
const int kPhotoQuality = 72;
const int kPhotoHighDetailQuality = 80;
const int kThumbSide = 360;
const int kThumbQuality = 60;

/// The bucket's limit (the database refuses bigger files).
const int kPhotoMaxBytes = 3 * 1024 * 1024;

class PreparedPhoto {
  const PreparedPhoto(this.jpeg, this.thumb, this.width, this.height);
  final Uint8List jpeg;
  final Uint8List thumb;
  final int width;
  final int height;
}

/// Size that fits within [maxSide] on the long edge, keeping the shape;
/// never enlarges.
(int, int) fitWithin(int width, int height, int maxSide) {
  final long = width > height ? width : height;
  if (long <= maxSide) return (width, height);
  final scale = maxSide / long;
  return ((width * scale).round().clamp(1, maxSide), (height * scale).round().clamp(1, maxSide));
}

/// Decodes, straightens (EXIF orientation), shrinks and re-encodes.
/// Pure Dart; run it with `compute` so the UI stays smooth. Throws
/// [FormatException] if the bytes aren't an image.
PreparedPhoto preparePhoto(({Uint8List bytes, bool highDetail}) input) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(input.bytes);
  } catch (_) {
    decoded = null; // the decoder can throw on corrupt data
  }
  if (decoded == null) throw const FormatException('That file isn’t a photo FolioMed can read.');
  final upright = img.bakeOrientation(decoded);
  final maxSide = input.highDetail ? kPhotoHighDetailSide : kPhotoMaxSide;
  final (w, h) = fitWithin(upright.width, upright.height, maxSide);
  final main = (w == upright.width && h == upright.height)
      ? upright
      : img.copyResize(upright, width: w, height: h, interpolation: img.Interpolation.average);
  var quality = input.highDetail ? kPhotoHighDetailQuality : kPhotoQuality;
  var jpeg = img.encodeJpg(main, quality: quality);
  // Very detailed images can still be large: step the quality down.
  while (jpeg.length > kPhotoMaxBytes && quality > 40) {
    quality -= 10;
    jpeg = img.encodeJpg(main, quality: quality);
  }
  final (tw, th) = fitWithin(main.width, main.height, kThumbSide);
  final thumb = img.encodeJpg(
      img.copyResize(main, width: tw, height: th, interpolation: img.Interpolation.average),
      quality: kThumbQuality);
  return PreparedPhoto(jpeg, thumb, main.width, main.height);
}
