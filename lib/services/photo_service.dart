import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/patient_photo.dart';
import 'photo_prep.dart';
import 'supabase_service.dart';

/// Clinical photos: pick → shrink on the phone → upload to the private
/// bucket → record (with consent) → view through short-lived signed links.
/// Nothing is written to the phone's gallery.
class PhotoService {
  PhotoService({SupabaseClient? client}) : _injected = client;
  final SupabaseClient? _injected;
  SupabaseClient get _client => _injected ?? supabase;

  static const bucket = 'clinical-photos';
  static const _linkLife = Duration(minutes: 10);

  /// Signed links, reused until shortly before they expire.
  static final Map<String, (String, DateTime)> _links = {};

  Stream<List<PatientPhoto>> watch(String patientId) => _client
      .from('patient_photos')
      .stream(primaryKey: ['id'])
      .eq('patient_id', patientId)
      .order('created_at', ascending: false)
      .map((rows) => rows.map(PatientPhoto.fromRow).toList());

  /// Picks a photo. The picker already scales it down a little to keep
  /// memory low; [preparePhoto] does the real shrinking.
  Future<Uint8List?> pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 4000, maxHeight: 4000, imageQuality: 95);
    return file?.readAsBytes();
  }

  Future<PreparedPhoto> prepare(Uint8List bytes, {required bool highDetail}) =>
      compute(preparePhoto, (bytes: bytes, highDetail: highDetail));

  Future<void> upload({
    required String patientId,
    required PreparedPhoto photo,
    required String caption,
    required bool highDetail,
    required bool consent,
  }) async {
    final id = const Uuid().v4();
    final path = '$patientId/$id.jpg';
    final thumb = '$patientId/${id}_t.jpg';
    final storage = _client.storage.from(bucket);
    const opts = FileOptions(contentType: 'image/jpeg', upsert: false);
    await storage.uploadBinary(path, photo.jpeg, fileOptions: opts);
    try {
      await storage.uploadBinary(thumb, photo.thumb, fileOptions: opts);
      await _client.rpc('add_patient_photo', params: {
        'p_id': id,
        'p_patient': patientId,
        'p_path': path,
        'p_thumb_path': thumb,
        'p_caption': caption,
        'p_width': photo.width,
        'p_height': photo.height,
        'p_bytes': photo.jpeg.length,
        'p_high_detail': highDetail,
        'p_consent': consent,
      });
    } catch (_) {
      // Don't leave files without a record.
      await storage.remove([path, thumb]).catchError((Object _) => <FileObject>[]);
      rethrow;
    }
  }

  /// A link valid for about 10 minutes.
  Future<String> link(String path) async {
    final cached = _links[path];
    if (cached != null && cached.$2.isAfter(DateTime.now().add(const Duration(minutes: 1)))) return cached.$1;
    final url = await _client.storage.from(bucket).createSignedUrl(path, _linkLife.inSeconds);
    _links[path] = (url, DateTime.now().add(_linkLife));
    return url;
  }

  /// Files first, then the record.
  Future<void> delete(PatientPhoto p) async {
    await _client.storage.from(bucket).remove([p.path, if (p.thumbPath != null) p.thumbPath!]);
    await _client.from('patient_photos').delete().eq('id', p.id);
    _links.remove(p.path);
    if (p.thumbPath != null) _links.remove(p.thumbPath);
  }
}
