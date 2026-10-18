import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../utils/app_theme.dart';

class RemoteVideoViewer extends StatefulWidget {
  final String patientName;
  final String hlsUrl;

  const RemoteVideoViewer({
    super.key,
    required this.patientName,
    required this.hlsUrl,
  });

  @override
  State<RemoteVideoViewer> createState() => _RemoteVideoViewerState();
}

class _RemoteVideoViewerState extends State<RemoteVideoViewer> {
  late final Player _player;
  late final VideoController _controller;
  bool _playing = false;
  bool _timedOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.stream.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    });
    _player.stream.error.listen((e) {
      if (mounted && e.isNotEmpty) setState(() => _error = e);
    });
    _player.open(Media(widget.hlsUrl));
    _scheduleTimeout();
  }

  void _scheduleTimeout() {
    Future.delayed(const Duration(seconds: 20), () {
      if (!mounted || _playing) return;
      setState(() => _timedOut = true);
    });
  }

  void _retry() {
    setState(() { _error = null; _playing = false; _timedOut = false; });
    _player.open(Media(widget.hlsUrl));
    _scheduleTimeout();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Video(controller: _controller, controls: NoVideoControls),

            if (_error != null)
              _overlay(
                icon: Icons.videocam_off,
                iconColor: Colors.orange.shade300,
                title: 'Stream error',
                detail: 'Check that MediaMTX is running on the hospital Mac\nand the Cloudflare tunnel is active.',
                showRetry: true,
              )
            else if (_timedOut && !_playing)
              _overlay(
                icon: Icons.wifi_off,
                iconColor: Colors.orange.shade300,
                title: 'Cannot reach stream',
                detail: 'Hospital Mac may be offline or tunnel not running.',
                showRetry: true,
              )
            else if (!_playing)
              _overlay(
                icon: Icons.videocam,
                iconColor: Colors.white30,
                title: 'Connecting…',
                detail: 'Loading live feed from hospital',
                showRetry: false,
                loading: true,
              ),

            if (_playing) ...[
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('LIVE', style: GoogleFonts.dmSans(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
              Positioned(
                bottom: 12, left: 12,
                child: Text(widget.patientName,
                    style: GoogleFonts.dmSans(
                        color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _overlay({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String detail,
    required bool showRetry,
    bool loading = false,
  }) {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (loading)
            const SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(color: Colors.white30, strokeWidth: 2),
            )
          else
            Icon(icon, color: iconColor, size: 36),
          const SizedBox(height: 10),
          Text(title, style: GoogleFonts.dmSans(
              color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(detail, textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 11, height: 1.5)),
          if (showRetry) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white54),
              label: Text('Retry', style: GoogleFonts.dmSans(color: Colors.white54, fontSize: 12)),
            ),
          ],
        ]),
      ),
    );
  }
}
