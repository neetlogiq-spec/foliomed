import 'row_parsing.dart';

/// A clinical photo (`patient_photos` row). The file itself is in the
/// private "clinical-photos" bucket at [path] (+ [thumbPath]).
class PatientPhoto {
  const PatientPhoto({
    required this.id,
    required this.patientId,
    required this.path,
    this.thumbPath,
    this.caption,
    this.width,
    this.height,
    this.bytes,
    this.highDetail = false,
    this.createdByName,
    required this.createdAt,
  });

  final String id;
  final String patientId;
  final String path;
  final String? thumbPath;
  final String? caption;
  final int? width;
  final int? height;
  final int? bytes;
  final bool highDetail;
  final String? createdByName;
  final DateTime createdAt;

  /// "240 KB".
  String? get sizeLabel => bytes == null
      ? null
      : bytes! >= 1024 * 1024
          ? '${(bytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
          : '${(bytes! / 1024).round()} KB';

  factory PatientPhoto.fromRow(DbRow r) => PatientPhoto(
        id: r['id'] as String? ?? '',
        patientId: r['patient_id'] as String? ?? '',
        path: r['path'] as String? ?? '',
        thumbPath: r['thumb_path'] as String?,
        caption: r['caption'] as String?,
        width: (r['width'] as num?)?.toInt(),
        height: (r['height'] as num?)?.toInt(),
        bytes: (r['bytes'] as num?)?.toInt(),
        highDetail: r['high_detail'] as bool? ?? false,
        createdByName: r['created_by_name'] as String?,
        createdAt: parseTimestamp(r['created_at']),
      );
}
