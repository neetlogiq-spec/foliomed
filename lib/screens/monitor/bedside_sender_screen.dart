import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../../services/video_call_service.dart';
import '../../services/vitals_ocr_service.dart';
import '../../utils/app_theme.dart';

class BedsideSenderScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String wardId;

  const BedsideSenderScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.wardId,
  });

  @override
  State<BedsideSenderScreen> createState() => _BedsideSenderScreenState();
}

class _BedsideSenderScreenState extends State<BedsideSenderScreen> with WidgetsBindingObserver {
  CameraController? _cameraCtrl;
  final VitalsOcrService _ocr = VitalsOcrService();
  final VideoCallService _video = VideoCallService();
  Timer? _ocrTimer;
  Timer? _snapshotTimer;
  bool _isStreaming = false;
  bool _ocrActive = false;
  bool _videoBroadcasting = false;
  ParsedVitals? _lastParsed;
  String _status = 'Initializing camera...';
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ocrTimer?.cancel();
    _snapshotTimer?.cancel();
    _cameraCtrl?.dispose();
    _ocr.dispose();
    _video.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopStreaming();
      _cameraCtrl?.dispose();
      _cameraCtrl = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _status = 'No camera found');
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraCtrl = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.nv21,
      );

      await _cameraCtrl!.initialize();
      if (mounted) setState(() => _status = 'Camera ready. Tap Start to begin.');
    } catch (e) {
      if (mounted) setState(() => _status = 'Camera error: $e');
    }
  }

  void _startStreaming() async {
    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) return;
    setState(() {
      _isStreaming = true;
      _ocrActive = true;
      _status = 'Streaming...';
    });

    _ocrTimer = Timer.periodic(const Duration(seconds: 3), (_) => _runOcrCycle());
    _snapshotTimer = Timer.periodic(const Duration(seconds: 5), (_) => _uploadSnapshot());

    // Also broadcast live video via Agora
    final ok = await _video.initialize();
    if (ok) {
      final channel = VideoCallService.channelForPatient(widget.patientId);
      await _video.joinAsBroadcaster(channel);
      if (mounted) setState(() => _videoBroadcasting = true);
    }
  }

  void _stopStreaming() async {
    _ocrTimer?.cancel();
    _snapshotTimer?.cancel();
    if (_videoBroadcasting) {
      await _video.leaveChannel();
    }
    setState(() {
      _isStreaming = false;
      _ocrActive = false;
      _videoBroadcasting = false;
      _status = 'Stopped.';
    });
  }

  Future<void> _runOcrCycle() async {
    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized || !_ocrActive) return;

    try {
      final xFile = await _cameraCtrl!.takePicture();
      final file = File(xFile.path);

      final parsed = await _ocr.processFile(file);
      if (parsed != null && parsed.hasAnyVital) {
        _frameCount++;
        setState(() => _lastParsed = parsed);
        await _pushVitalsToFirestore(parsed);
      }

      try { await file.delete(); } catch (_) {}
    } catch (e) {
      debugPrint('OCR cycle error: $e');
    }
  }

  Future<void> _pushVitalsToFirestore(ParsedVitals parsed) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final vitalsMap = parsed.toVitalMap();
      if (vitalsMap.isEmpty) return;

      final data = <String, dynamic>{
        'timestamp': FieldValue.serverTimestamp(),
        'confidence': parsed.confidence,
        'source': 'ocr',
        'senderUid': uid,
      };

      for (final entry in vitalsMap.entries) {
        data[entry.key.name] = entry.value;
      }

      await FirebaseFirestore.instance
          .collection('monitor_vitals')
          .doc(widget.patientId)
          .set(data);

      await FirebaseFirestore.instance
          .collection('monitor_vitals')
          .doc(widget.patientId)
          .collection('history')
          .add(data);
    } catch (e) {
      debugPrint('Firestore push error: $e');
    }
  }

  Future<void> _uploadSnapshot() async {
    if (_cameraCtrl == null || !_cameraCtrl!.value.isInitialized) return;

    try {
      final xFile = await _cameraCtrl!.takePicture();
      final bytes = await xFile.readAsBytes();

      final ref = FirebaseStorage.instance
          .ref('monitor_snapshots/${widget.patientId}/latest.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      try { await File(xFile.path).delete(); } catch (_) {}
    } catch (e) {
      debugPrint('Snapshot upload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text('Bedside Monitor', style: GoogleFonts.dmSans(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          if (_isStreaming)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('LIVE', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview
          Expanded(
            flex: 3,
            child: _cameraCtrl != null && _cameraCtrl!.value.isInitialized
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CameraPreview(_cameraCtrl!),
                  )
                : Center(
                    child: Text(_status, style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 14)),
                  ),
          ),

          // Parsed vitals overlay
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  '${widget.patientName} · Sending vitals',
                  style: GoogleFonts.dmSans(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),

                if (_lastParsed != null) _vitalsReadout(_lastParsed!) else _noData(),

                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isStreaming ? 'Frames processed: $_frameCount' : _status,
                      style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 11),
                    ),
                    if (_lastParsed != null)
                      Text(
                        'Confidence: ${_lastParsed!.confidence}%',
                        style: GoogleFonts.dmSans(
                          color: _lastParsed!.confidence > 50 ? AppColors.accent : AppColors.warning,
                          fontSize: 11, fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _cameraCtrl != null && _cameraCtrl!.value.isInitialized
                        ? (_isStreaming ? _stopStreaming : _startStreaming)
                        : null,
                    icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                    label: Text(_isStreaming ? 'Stop Streaming' : 'Start Streaming'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isStreaming ? AppColors.danger : AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalsReadout(ParsedVitals v) {
    return Row(
      children: [
        _vitalChip('HR', v.hr != null ? '${v.hr!.round()}' : '--', 'bpm', v.hr != null),
        const SizedBox(width: 8),
        _vitalChip('SpO₂', v.spo2 != null ? '${v.spo2!.round()}' : '--', '%', v.spo2 != null),
        const SizedBox(width: 8),
        _vitalChip('RR', v.rr != null ? '${v.rr!.round()}' : '--', 'br/m', v.rr != null),
        const SizedBox(width: 8),
        _vitalChip('BP', v.sbp != null ? '${v.sbp!.round()}/${v.dbp?.round() ?? "--"}' : '--', 'mmHg', v.sbp != null),
      ],
    );
  }

  Widget _vitalChip(String label, String value, String unit, bool detected) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: detected ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: detected ? AppColors.accent.withOpacity(0.4) : Colors.white12),
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.dmSans(color: detected ? Colors.white : Colors.white30, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(unit, style: GoogleFonts.dmSans(color: Colors.white30, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _noData() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.monitor_heart_outlined, color: Colors.white30, size: 20),
          const SizedBox(width: 10),
          Text(
            _isStreaming ? 'Scanning for vitals...' : 'Point camera at the bedside monitor',
            style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
