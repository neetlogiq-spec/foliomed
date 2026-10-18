import 'monitor_vitals.dart';

/// Normalized rectangle on the camera frame (0.0 – 1.0 for both axes).
/// Used to define which region of the camera image to crop for OCR per vital.
class RoiRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const RoiRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  RoiRect clamp() => RoiRect(
        left: left.clamp(0.0, 1.0),
        top: top.clamp(0.0, 1.0),
        width: width.clamp(0.01, 1.0 - left.clamp(0.0, 1.0)),
        height: height.clamp(0.01, 1.0 - top.clamp(0.0, 1.0)),
      );

  Map<String, dynamic> toJson() =>
      {'l': left, 't': top, 'w': width, 'h': height};

  factory RoiRect.fromJson(Map<String, dynamic> j) => RoiRect(
        left: (j['l'] as num).toDouble(),
        top: (j['t'] as num).toDouble(),
        width: (j['w'] as num).toDouble(),
        height: (j['h'] as num).toDouble(),
      );
}

/// One physical bedside monitor inside a camera's field of view.
///
/// A single wall camera often covers 2–3 beds; each [MonitorZone] marks
/// where one monitor sits in the frame so it can be cropped out and read
/// independently, with its own name ("Monitor 1", "Bed 3 left", …) and
/// its own assigned patient.
class MonitorZone {
  final String id;
  final String name;
  final RoiRect rect;
  final String patientId;
  final String patientName;

  const MonitorZone({
    required this.id,
    required this.name,
    required this.rect,
    this.patientId = '',
    this.patientName = '',
  });

  MonitorZone copyWith({
    String? name,
    RoiRect? rect,
    String? patientId,
    String? patientName,
  }) {
    return MonitorZone(
      id: id,
      name: name ?? this.name,
      rect: rect ?? this.rect,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'rect': rect.toJson(),
        'patientId': patientId,
        'patientName': patientName,
      };

  factory MonitorZone.fromJson(Map<String, dynamic> j) => MonitorZone(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        rect: RoiRect.fromJson(Map<String, dynamic>.from(j['rect'] as Map)),
        patientId: j['patientId'] as String? ?? '',
        patientName: j['patientName'] as String? ?? '',
      );
}

class CameraConfig {
  final String id;
  final String label;
  final String brand;
  final String ip;
  final int port;
  final String username;
  final String password;
  final String customRtsp;
  final String patientId;
  final String patientName;
  final String bedLabel;
  final bool isEnabled;
  final Map<VitalType, RoiRect> roi;
  final List<MonitorZone> monitors;

  const CameraConfig({
    required this.id,
    required this.label,
    required this.brand,
    required this.ip,
    this.port = 554,
    this.username = 'admin',
    required this.password,
    this.customRtsp = '',
    this.patientId = '',
    this.patientName = '',
    this.bedLabel = '',
    this.isEnabled = true,
    this.roi = const {},
    this.monitors = const [],
  });

  /// Webcam test phase: use the laptop's built-in camera instead of an IP
  /// camera — for trying the capture → AI pipeline without ward hardware.
  static const String webcamBrand = 'Webcam Test';

  bool get isWebcam => brand == webcamBrand;

  String get rtspUrl {
    // libmpv can open the default macOS camera via avfoundation.
    if (isWebcam) return 'av://avfoundation:0';
    if (customRtsp.isNotEmpty) return customRtsp;
    final cred = '${Uri.encodeComponent(username)}:${Uri.encodeComponent(password)}';
    final base = 'rtsp://$cred@$ip:$port';
    switch (brand) {
      case 'TrueView':
        return '$base/ch0_0.264';
      case 'Hikvision':
        return '$base/Streaming/Channels/101';
      case 'Dahua':
        return '$base/cam/realmonitor?channel=1&subtype=0';
      case 'CP Plus':
        return '$base/stream1';
      default:
        return '$base/stream1';
    }
  }

  bool get hasRoi => roi.isNotEmpty;

  int get roiZoneCount => roi.length;

  bool get hasMonitorZones => monitors.isNotEmpty;

  /// The monitor zone assigned to this patient, if any — matched by id
  /// first, then by name (same fallback the camera-level match uses).
  MonitorZone? zoneForPatient(String pid, String pname) {
    for (final m in monitors) {
      if (pid.isNotEmpty && m.patientId == pid) return m;
    }
    for (final m in monitors) {
      if (pname.isNotEmpty && m.patientName == pname) return m;
    }
    return null;
  }

  /// True when this camera watches the given patient — either directly
  /// (single-monitor setup) or via one of its monitor zones.
  bool watchesPatient(String pid, String pname) {
    if (pid.isNotEmpty && patientId == pid) return true;
    if (pname.isNotEmpty && patientName == pname) return true;
    return zoneForPatient(pid, pname) != null;
  }

  CameraConfig copyWith({
    String? id,
    String? label,
    String? brand,
    String? ip,
    int? port,
    String? username,
    String? password,
    String? customRtsp,
    String? patientId,
    String? patientName,
    String? bedLabel,
    bool? isEnabled,
    Map<VitalType, RoiRect>? roi,
    List<MonitorZone>? monitors,
  }) {
    return CameraConfig(
      id: id ?? this.id,
      label: label ?? this.label,
      brand: brand ?? this.brand,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      customRtsp: customRtsp ?? this.customRtsp,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      bedLabel: bedLabel ?? this.bedLabel,
      isEnabled: isEnabled ?? this.isEnabled,
      roi: roi ?? this.roi,
      monitors: monitors ?? this.monitors,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'brand': brand,
        'ip': ip,
        'port': port,
        'username': username,
        'password': password,
        'customRtsp': customRtsp,
        'patientId': patientId,
        'patientName': patientName,
        'bedLabel': bedLabel,
        'isEnabled': isEnabled,
        'roi': roi.map((vt, r) => MapEntry(vt.name, r.toJson())),
        'monitors': monitors.map((m) => m.toJson()).toList(),
      };

  factory CameraConfig.fromJson(Map<String, dynamic> j) {
    final roiRaw = (j['roi'] as Map<String, dynamic>?) ?? {};
    final roi = <VitalType, RoiRect>{};
    for (final entry in roiRaw.entries) {
      try {
        final vt = VitalType.values.firstWhere((v) => v.name == entry.key);
        roi[vt] = RoiRect.fromJson(Map<String, dynamic>.from(entry.value as Map));
      } catch (_) {}
    }
    return CameraConfig(
      id: j['id'] as String,
      label: j['label'] as String? ?? '',
      brand: j['brand'] as String? ?? 'CP Plus',
      ip: j['ip'] as String? ?? '',
      port: (j['port'] as num?)?.toInt() ?? 554,
      username: j['username'] as String? ?? 'admin',
      password: j['password'] as String? ?? '',
      customRtsp: j['customRtsp'] as String? ?? '',
      patientId: j['patientId'] as String? ?? '',
      patientName: j['patientName'] as String? ?? '',
      bedLabel: j['bedLabel'] as String? ?? '',
      isEnabled: j['isEnabled'] as bool? ?? true,
      roi: roi,
      monitors: [
        for (final m in (j['monitors'] as List?) ?? const [])
          MonitorZone.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
    );
  }
}
