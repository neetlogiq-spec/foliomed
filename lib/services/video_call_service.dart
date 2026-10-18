import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallService {
  // ⚠️ PLACEHOLDER — replace with the real Agora App ID from
  // https://console.agora.io before shipping. Until this is a real ID,
  // initialize() will fail (Agora throws on empty/placeholder appId) and
  // the remote video viewer + bedside broadcaster will both no-op.
  static const String appId = 'YOUR_AGORA_APP_ID';
  static bool get isConfigured =>
      appId != 'YOUR_AGORA_APP_ID' && appId.isNotEmpty;

  RtcEngine? _engine;
  bool _isInitialized = false;
  int? _remoteUid;

  bool get isInitialized => _isInitialized;
  int? get remoteUid => _remoteUid;
  RtcEngine? get engine => _engine;

  VoidCallback? onRemoteJoined;
  VoidCallback? onRemoteLeft;
  VoidCallback? onError;

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    final cameraStatus = await Permission.camera.request();
    await Permission.microphone.request();

    if (!cameraStatus.isGranted) {
      debugPrint('Camera permission denied');
      return false;
    }

    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          debugPrint('Local joined channel: ${connection.channelId}');
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          debugPrint('Remote user joined: $remoteUid');
          _remoteUid = remoteUid;
          onRemoteJoined?.call();
        },
        onUserOffline: (connection, remoteUid, reason) {
          debugPrint('Remote user left: $remoteUid');
          _remoteUid = null;
          onRemoteLeft?.call();
        },
        onError: (err, msg) {
          debugPrint('Agora error: $err - $msg');
          onError?.call();
        },
      ));

      await _engine!.enableVideo();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Agora init error: $e');
      return false;
    }
  }

  /// Bedside phone joins as broadcaster (sends video).
  Future<void> joinAsBroadcaster(String channelName) async {
    if (!_isInitialized) return;

    await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine!.startPreview();
    await _engine!.joinChannel(
      token: '', // Use token server in production
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: false, // No audio needed for monitoring
        publishCameraTrack: true,
        publishMicrophoneTrack: false,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  /// Doctor's phone joins as audience (watches video).
  Future<void> joinAsViewer(String channelName) async {
    if (!_isInitialized) return;

    await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
    await _engine!.joinChannel(
      token: '',
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: false,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        clientRoleType: ClientRoleType.clientRoleAudience,
      ),
    );
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
    _remoteUid = null;
  }

  Future<void> dispose() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    _isInitialized = false;
  }

  /// Channel name for a patient's bedside camera.
  /// Convention: foliomed_monitor_{patientId}
  static String channelForPatient(String patientId) => 'foliomed_monitor_$patientId';
}
