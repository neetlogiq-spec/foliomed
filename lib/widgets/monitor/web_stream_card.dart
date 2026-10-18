import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/app_theme.dart';

class WebStreamCard extends StatelessWidget {
  final String patientName;
  final String hlsUrl;

  const WebStreamCard({
    super.key,
    required this.patientName,
    required this.hlsUrl,
  });

  String get _playerUrl => hlsUrl.replaceFirst('/index.m3u8', '');

  Future<void> _open() async {
    final uri = Uri.parse(_playerUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text('LIVE STREAM AVAILABLE',
                  style: GoogleFonts.dmSans(
                      color: AppColors.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          const Icon(Icons.videocam, color: Colors.white54, size: 40),
          const SizedBox(height: 10),
          Text(patientName,
              style: GoogleFonts.dmSans(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Live camera feed from hospital',
              style: GoogleFonts.dmSans(color: Colors.white38, fontSize: 12)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _open,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text('Watch Live Stream',
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Opens in a new tab · Full screen supported',
              style: GoogleFonts.dmSans(color: Colors.white24, fontSize: 10)),
        ],
      ),
    );
  }
}
