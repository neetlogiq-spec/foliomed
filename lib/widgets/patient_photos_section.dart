import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/patient.dart';
import '../models/patient_photo.dart';
import '../services/photo_prep.dart';
import '../services/photo_service.dart';
import '../utils/app_theme.dart';
import '../utils/app_typography.dart';
import '../utils/formatting.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import '../utils/secure_screen.dart';
import 'app_alert_dialog.dart';
import 'inset_group.dart';

const _privacyLine = 'For this patient’s care only. Stored in FolioMed (not your gallery) and visible only to '
    'this patient’s ward team.';

/// Patient page: clinical photos (thumbnails → full screen) and Add Photo.
class PatientPhotosSection extends StatefulWidget {
  const PatientPhotosSection({super.key, required this.patient});

  final Patient patient;

  @override
  State<PatientPhotosSection> createState() => _PatientPhotosSectionState();
}

class _PatientPhotosSectionState extends State<PatientPhotosSection> {
  final _service = PhotoService();
  late final Stream<List<PatientPhoto>> _photos = _service.watch(widget.patient.id);
  bool _secured = false;

  Patient get p => widget.patient;

  @override
  void dispose() {
    if (_secured) SecureScreen.leave();
    super.dispose();
  }

  void _secureWhileShown(bool any) {
    if (any && !_secured) {
      _secured = true;
      SecureScreen.enter();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PatientPhoto>>(
      stream: _photos,
      builder: (context, snap) {
        final photos = snap.data ?? const <PatientPhoto>[];
        _secureWhileShown(photos.isNotEmpty);
        return InsetGroup(
          header: 'Photos',
          footer: _privacyLine,
          children: [
            if (snap.hasError)
              const SettingsRow(title: "Couldn't load photos")
            else if (photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final (i, ph) in photos.indexed)
                    _Thumb(
                      key: ValueKey(ph.id),
                      photo: ph,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PhotoViewerScreen(photos: photos, initial: i, canDelete: p.isActive),
                      )),
                    ),
                ]),
              ),
            if (p.isActive) SettingsRow(icon: Icons.add_a_photo_outlined, title: 'Add Photo', onTap: _add),
          ],
        );
      },
    );
  }

  Future<void> _add() async {
    final camera = !kIsWeb;
    final source = camera
        ? await showOptionSheet<ImageSource>(
            context,
            title: 'Add a photo',
            options: const {ImageSource.camera: 'Take Photo', ImageSource.gallery: 'Choose Photo'},
          )
        : ImageSource.gallery;
    if (source == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Uint8List? bytes;
    try {
      bytes = await _service.pick(source);
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
      return;
    }
    if (bytes == null || !mounted) return;
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddPhotoScreen(patient: p, original: bytes!),
    ));
    if (done == true) messenger.showSnackBar(const SnackBar(content: Text('Photo added')));
  }
}

class _Thumb extends StatefulWidget {
  const _Thumb({super.key, required this.photo, required this.onTap});
  final PatientPhoto photo;
  final VoidCallback onTap;

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final Future<String> _url = PhotoService().link(widget.photo.thumbPath ?? widget.photo.path);

  @override
  Widget build(BuildContext context) {
    const side = 84.0;
    return Semantics(
      button: true,
      label: 'Photo${widget.photo.caption == null ? '' : ': ${widget.photo.caption}'}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox.square(
            dimension: side,
            child: FutureBuilder<String>(
              future: _url,
              builder: (context, snap) => snap.hasData
                  ? Image.network(
                      snap.data!,
                      fit: BoxFit.cover,
                      cacheWidth: (side * MediaQuery.devicePixelRatioOf(context)).round(),
                      errorBuilder: (_, _, _) => _placeholder(Icons.broken_image_outlined),
                    )
                  : _placeholder(snap.hasError ? Icons.cloud_off_outlined : null),
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(IconData? icon) => ColoredBox(
        color: AppColors.fill,
        child: Center(
          child: icon == null
              ? const CupertinoActivityIndicator()
              : Icon(icon, color: AppColors.textSecondary),
        ),
      );
}

/// Shrinks the picked photo, shows the result and its size, and uploads
/// it once consent is ticked. Pops true when uploaded.
class AddPhotoScreen extends StatefulWidget {
  const AddPhotoScreen({super.key, required this.patient, required this.original, this.service});

  final Patient patient;
  final Uint8List original;

  /// For tests.
  final PhotoService? service;

  @override
  State<AddPhotoScreen> createState() => _AddPhotoScreenState();
}

class _AddPhotoScreenState extends State<AddPhotoScreen> {
  late final PhotoService _service = widget.service ?? PhotoService();
  final _caption = TextEditingController();
  bool _highDetail = false;
  bool _consent = false;
  bool _uploading = false;
  Future<PreparedPhoto>? _prepared;

  @override
  void initState() {
    super.initState();
    SecureScreen.enter();
    _prepare();
  }

  @override
  void dispose() {
    SecureScreen.leave();
    _caption.dispose();
    super.dispose();
  }

  void _prepare() => _prepared = _service.prepare(widget.original, highDetail: _highDetail);

  static String _size(int bytes) => bytes >= 1024 * 1024
      ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).round()} KB';

  Future<void> _upload(PreparedPhoto photo) async {
    setState(() => _uploading = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.upload(
        patientId: widget.patient.id,
        photo: photo,
        caption: _caption.text,
        highDetail: _highDetail,
        consent: _consent,
      );
      Haptics.success();
      navigator.pop(true);
    } catch (e) {
      Haptics.error();
      if (!mounted) return;
      setState(() => _uploading = false);
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Add Photo'),
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel', onPressed: () => Navigator.pop(context)),
      ),
      body: FutureBuilder<PreparedPhoto>(
        future: _prepared,
        builder: (context, snap) {
          final photo = snap.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.card),
                child: AspectRatio(
                  aspectRatio: photo == null ? 4 / 3 : photo.width / photo.height,
                  child: photo != null
                      ? Image.memory(photo.jpeg, fit: BoxFit.contain, gaplessPlayback: true)
                      : ColoredBox(
                          color: AppColors.fill,
                          child: Center(
                            child: snap.hasError
                                ? Text("Couldn't read this photo.", style: AppTypography.body(color: AppColors.danger))
                                : const CupertinoActivityIndicator(),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                photo == null
                    ? 'Shrinking…'
                    : '${photo.width} × ${photo.height} · ${_size(photo.jpeg.length)} '
                        '(from ${_size(widget.original.length)}) · location data removed',
                textAlign: TextAlign.center,
                style: AppTypography.footnote(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              InsetGroup(dividerIndent: 16, children: [
                InsetTextRow(
                  label: 'Caption',
                  controller: _caption,
                  placeholder: 'e.g. Rash on trunk, day 3',
                  textCapitalization: TextCapitalization.sentences,
                ),
                SettingsRow(
                  title: 'High detail',
                  subtitle: 'For X-rays and fine detail — a larger file',
                  trailing: Switch.adaptive(
                    value: _highDetail,
                    onChanged: _uploading
                        ? null
                        : (v) => setState(() {
                              _highDetail = v;
                              _prepare();
                            }),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              InsetGroup(footer: _privacyLine, children: [
                SettingsRow(
                  title: 'Consent obtained',
                  subtitle: 'The patient (or parent / guardian) agreed to this photo for their care.',
                  trailing: Checkbox.adaptive(
                    value: _consent,
                    onChanged: _uploading ? null : (v) => setState(() => _consent = v ?? false),
                  ),
                  onTap: _uploading ? null : () => setState(() => _consent = !_consent),
                  showChevron: false,
                ),
              ]),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: photo != null && _consent && !_uploading ? () => _upload(photo) : null,
                child: _uploading
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator.adaptive(strokeWidth: 2))
                    : const Text('Upload'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Full-screen photos: swipe between them, pinch to zoom. Screenshots are
/// blocked on Android while open.
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({super.key, required this.photos, required this.initial, required this.canDelete});

  final List<PatientPhoto> photos;
  final int initial;
  final bool canDelete;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  final _service = PhotoService();
  final _links = <String, Future<String>>{};

  @override
  void initState() {
    super.initState();
    SecureScreen.enter();
  }

  @override
  void dispose() {
    SecureScreen.leave();
    _page.dispose();
    super.dispose();
  }

  Future<void> _delete(PatientPhoto ph) async {
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AppAlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text('It’s removed for the whole ward team. This can’t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.delete(ph);
      Haptics.destructive();
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Photo deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: AppColors.danger, content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = widget.photos[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} of ${widget.photos.length}'),
        actions: [
          if (widget.canDelete)
            IconButton(tooltip: 'Delete photo', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(ph)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: PageView.builder(
            controller: _page,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final p = widget.photos[i];
              return FutureBuilder<String>(
                future: _links.putIfAbsent(p.path, () => _service.link(p.path)),
                builder: (context, snap) => snap.hasData
                    ? InteractiveViewer(
                        maxScale: 6,
                        child: Center(
                          child: Image.network(
                            snap.data!,
                            fit: BoxFit.contain,
                            loadingBuilder: (_, child, progress) =>
                                progress == null ? child : const CupertinoActivityIndicator(color: Colors.white),
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                          ),
                        ),
                      )
                    : Center(
                        child: snap.hasError
                            ? const Icon(Icons.cloud_off_outlined, color: Colors.white54, size: 48)
                            : const CupertinoActivityIndicator(color: Colors.white),
                      ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((ph.caption ?? '').isNotEmpty)
                Text(ph.caption!, style: AppTypography.body(color: Colors.white)),
              Text(
                [
                  if ((ph.createdByName ?? '').isNotEmpty) ph.createdByName!,
                  formatDueTime(ph.createdAt),
                  if (ph.sizeLabel != null) ph.sizeLabel!,
                  if (ph.highDetail) 'high detail',
                ].join(' · '),
                style: AppTypography.footnote(color: Colors.white70),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
