import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/camera_config.dart';
import '../../models/monitor_vitals.dart';
import '../../providers/camera_provider.dart';
import '../../providers/monitor_provider.dart';
import '../../utils/app_theme.dart';
import 'roi_editor_screen.dart';

// ─────────────────────────────────────────────
//  FolioMed Edge — Camera Setup Wizard
//  8 steps: Welcome → Hardware → Network →
//           Find IP → Build RTSP → Test →
//           Map Patient → Done
// ─────────────────────────────────────────────

class EdgeSetupScreen extends StatefulWidget {
  const EdgeSetupScreen({super.key});

  @override
  State<EdgeSetupScreen> createState() => _EdgeSetupScreenState();
}

class _EdgeSetupScreenState extends State<EdgeSetupScreen> {
  int _step = 0;
  static const int _totalSteps = 9;

  // Wizard state — built up across steps
  String _brand = 'CP Plus';
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '554');
  final _userCtrl = TextEditingController(text: 'admin');
  final _passCtrl = TextEditingController();
  final _customRtspCtrl = TextEditingController();
  final _labelCtrl = TextEditingController(text: 'Bed Camera');
  bool _useCustomRtsp = false;
  bool _passVisible = false;

  String _selectedPatientId = '';
  String _selectedPatientName = '';
  final _bedCtrl = TextEditingController();
  final Map<VitalType, RoiRect> _draftRoi = {};

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _customRtspCtrl.dispose();
    _labelCtrl.dispose();
    _bedCtrl.dispose();
    super.dispose();
  }

  // Stable ID generated once so ROI edits persist across wizard steps
  final String _draftId = const Uuid().v4();

  CameraConfig get _draft => CameraConfig(
        id: _draftId,
        label: _labelCtrl.text.trim(),
        brand: _brand,
        ip: _ipCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text.trim()) ?? 554,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
        customRtsp: _useCustomRtsp ? _customRtspCtrl.text.trim() : '',
        patientId: _selectedPatientId,
        patientName: _selectedPatientName,
        bedLabel: _bedCtrl.text.trim(),
        roi: Map.from(_draftRoi),
      );

  void _next() {
    if (_step < _totalSteps - 1) setState(() => _step++);
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.appBarBg,
        leading: _step == 0
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Text('FolioMed Edge Setup',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w800, color: AppColors.primary)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('Step ${_step + 1} of $_totalSteps',
                  style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Sidebar(currentStep: _step),
                Expanded(child: _body()),
              ],
            )
          : _body(),
    );
  }

  Widget _body() {
    return Column(
      children: [
        _ProgressBar(step: _step, total: _totalSteps),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _stepContent(),
          ),
        ),
        _NavRow(
          step: _step,
          total: _totalSteps,
          onBack: _step > 0 ? _back : null,
          onNext: _step < _totalSteps - 1 ? _next : null,
          onFinish: _step == _totalSteps - 1 ? _saveAndFinish : null,
        ),
      ],
    );
  }

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return _StepWelcome(onStart: _next);
      case 1:
        return _StepHardware(selected: _brand, onSelect: (b) => setState(() => _brand = b));
      case 2:
        return const _StepNetworkSetup();
      case 3:
        return _StepFindIP(ipCtrl: _ipCtrl, portCtrl: _portCtrl);
      case 4:
        return _StepBuildRtsp(
          brand: _brand,
          ipCtrl: _ipCtrl,
          portCtrl: _portCtrl,
          userCtrl: _userCtrl,
          passCtrl: _passCtrl,
          customRtspCtrl: _customRtspCtrl,
          useCustom: _useCustomRtsp,
          passVisible: _passVisible,
          onToggleCustom: (v) => setState(() => _useCustomRtsp = v),
          onTogglePass: () => setState(() => _passVisible = !_passVisible),
          draft: _draft,
        );
      case 5:
        return _StepTestConnection(draft: _draft);
      case 6:
        return _StepMapPatient(
          labelCtrl: _labelCtrl,
          bedCtrl: _bedCtrl,
          selectedPatientId: _selectedPatientId,
          selectedPatientName: _selectedPatientName,
          onPatientSelected: (id, name) => setState(() {
            _selectedPatientId = id;
            _selectedPatientName = name;
          }),
        );
      case 7:
        // ROI zone definition — opens the editor as a sub-screen
        return _StepRoiPrompt(
          draft: _draft,
          onLaunchEditor: () => _launchRoiEditor(context),
        );
      case 8:
        return _StepDone(draft: _draft, onAddAnother: () => setState(() => _step = 1));
      default:
        return const SizedBox.shrink();
    }
  }

  void _saveAndFinish() {
    context.read<CameraProvider>().add(_draft);
    Navigator.pop(context);
  }

  void _launchRoiEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoiEditorScreen(
          camera: _draft,
          onSave: (updates) {
            // ROI saved into _draftRoi — applied on final save at step 8
            setState(() {
              for (final e in updates.entries) {
                if (e.value == null) _draftRoi.remove(e.key);
                else _draftRoi[e.key] = e.value!;
              }
            });
          },
        ),
      ),
    );
  }
}

// ─── Sidebar ─────────────────────────────────

class _Sidebar extends StatelessWidget {
  final int currentStep;
  const _Sidebar({required this.currentStep});

  static const _steps = [
    (icon: Icons.rocket_launch_outlined,  label: 'Welcome'),
    (icon: Icons.videocam_outlined,       label: 'Camera Hardware'),
    (icon: Icons.wifi,                    label: 'Network Setup'),
    (icon: Icons.search,                  label: 'Find Camera IP'),
    (icon: Icons.link,                    label: 'RTSP URL'),
    (icon: Icons.check_circle_outline,    label: 'Test Connection'),
    (icon: Icons.person_pin_outlined,     label: 'Map to Patient'),
    (icon: Icons.crop_free,               label: 'Define Zones'),
    (icon: Icons.celebration_outlined,    label: 'Done'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: AppColors.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Text('SETUP STEPS',
                style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
          ),
          for (int i = 0; i < _steps.length; i++)
            _sidebarItem(i, _steps[i].icon, _steps[i].label),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label) {
    final done = index < currentStep;
    final active = index == currentStep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: active ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : icon,
            size: 18,
            color: done
                ? AppColors.stable
                : active
                    ? AppColors.primary
                    : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? AppColors.primary : done ? AppColors.textSecondary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Progress Bar ─────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: (step + 1) / total,
      minHeight: 3,
      backgroundColor: AppColors.divider,
      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
    );
  }
}

// ─── Nav Row ──────────────────────────────────

class _NavRow extends StatelessWidget {
  final int step;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onFinish;
  const _NavRow({required this.step, required this.total, this.onBack, this.onNext, this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: BorderSide(color: AppColors.divider),
              ),
            ),
          const Spacer(),
          if (onFinish != null)
            ElevatedButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Finish Setup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.stable,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
            )
          else if (onNext != null && step != 0)
            ElevatedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Continue'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                textStyle: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  STEP 0 — Welcome
// ═══════════════════════════════════════════════

class _StepWelcome extends StatelessWidget {
  final VoidCallback onStart;
  const _StepWelcome({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0A5C8A), Color(0xFF0E7C5F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.monitor_heart, color: Colors.white, size: 48),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('Welcome to FolioMed Edge',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Connect your CCTV camera to automatically read\n'
            'vitals from bedside monitors — no manual entry needed.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
                color: AppColors.textSecondary, fontSize: 14, height: 1.6),
          ),
        ),
        const SizedBox(height: 32),
        _InfoCard(
          icon: Icons.timer_outlined,
          title: 'Takes about 10 minutes',
          body: 'This wizard walks you through the complete setup — hardware, network, and patient mapping.',
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.checklist_outlined,
          title: 'What you\'ll need',
          body: '• An IP CCTV camera (CP Plus, Hikvision, or any ONVIF)\n'
                '• Your camera\'s IP address and password\n'
                '• This PC connected to the same WiFi/LAN as the camera\n'
                '• The camera mounted facing the bedside monitor',
        ),
        const SizedBox(height: 12),
        _InfoCard(
          icon: Icons.security_outlined,
          title: 'Everything stays on your network',
          body: 'FolioMed Edge runs entirely on this PC. Video never leaves your ward. '
                'Only vital readings (numbers, not video) are sent to the cloud.',
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text('Start Setup',
                style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  STEP 1 — Hardware Selection
// ═══════════════════════════════════════════════

class _StepHardware extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;
  const _StepHardware({required this.selected, required this.onSelect});

  static const _cameras = [
    (
      brand: 'CP Plus',
      models: 'CP-E35Q, CP-E31Q',
      badge: 'Recommended',
      icon: Icons.videocam,
      color: Color(0xFF0A5C8A),
      notes: 'WiFi PTZ camera. RTSP on port 554, stream path: /stream1. '
             'App pairing via iCSee or CP-Plus. Confirmed RTSP support.',
    ),
    (
      brand: 'Hikvision',
      models: 'DS-2CD series',
      badge: 'Best Quality',
      icon: Icons.camera_alt,
      color: Color(0xFF0E7C5F),
      notes: 'Industry standard. RTSP path: /Streaming/Channels/101. '
             'Use SADP tool to find IP. High resolution (2–8MP).',
    ),
    (
      brand: 'TrueView',
      models: 'T18296S and similar',
      badge: 'Budget',
      icon: Icons.videocam_outlined,
      color: Color(0xFF7B4F00),
      notes: 'Budget-friendly option. RTSP on port 554. '
             'Same stream path as CP Plus (/stream1). Good for basic use.',
    ),
    (
      brand: 'Dahua',
      models: 'IPC-HDW series',
      badge: 'Advanced',
      icon: Icons.camera,
      color: Color(0xFF4A148C),
      notes: 'Used in larger hospitals. RTSP path varies: '
             '/cam/realmonitor?channel=1&subtype=0. Supports 4K.',
    ),
    (
      brand: 'Other (ONVIF)',
      models: 'Any ONVIF-compatible',
      badge: 'Generic',
      icon: Icons.settings_input_antenna,
      color: Color(0xFF37474F),
      notes: 'Most IP cameras support ONVIF. You\'ll enter the RTSP URL manually. '
             'Check the camera\'s manual for the RTSP stream address.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.videocam_outlined,
          title: 'Select Your Camera Brand',
          subtitle: 'Choose the brand that matches your camera. '
                    'This helps FolioMed auto-fill the correct RTSP URL format.',
        ),
        const SizedBox(height: 24),
        for (final cam in _cameras) ...[
          GestureDetector(
            onTap: () => onSelect(cam.brand),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: selected == cam.brand
                    ? cam.color.withOpacity(0.08)
                    : AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected == cam.brand ? cam.color : AppColors.divider,
                  width: selected == cam.brand ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: cam.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(cam.icon, color: cam.color, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(cam.brand,
                                style: GoogleFonts.dmSans(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: cam.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(cam.badge,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 10, fontWeight: FontWeight.w700, color: cam.color)),
                            ),
                          ],
                        ),
                        Text(cam.models,
                            style: GoogleFonts.dmSans(
                                color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(cam.notes,
                            style: GoogleFonts.dmSans(
                                color: AppColors.textSecondary, fontSize: 11, height: 1.45)),
                      ],
                    ),
                  ),
                  if (selected == cam.brand)
                    Icon(Icons.check_circle, color: cam.color, size: 22),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _TipBox(
          text: 'Tip: For a NICU, mount the camera 60–80 cm away, angled directly at the '
                'monitor screen. Avoid backlighting — the monitor should be the brightest thing '
                'in the camera\'s view.',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  STEP 2 — Network Setup
// ═══════════════════════════════════════════════

class _StepNetworkSetup extends StatelessWidget {
  const _StepNetworkSetup();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.wifi,
          title: 'Connect Camera to Your Network',
          subtitle: 'The camera and this PC must be on the same WiFi or LAN for RTSP to work.',
        ),
        const SizedBox(height: 24),
        _SectionTitle('Option A — WiFi Setup (for CP Plus / TrueView)'),
        const SizedBox(height: 12),
        _NumberedStep(
          number: 1,
          title: 'Download the camera app',
          body: 'CP Plus → install iCSee (Android/iOS)\n'
                'Hikvision → install Hik-Connect\n'
                'TrueView / Generic → install CamHi or TuyaSmart',
        ),
        _NumberedStep(
          number: 2,
          title: 'Power on the camera',
          body: 'Connect via the included power adapter. '
                'A blue or red LED will blink slowly — ready to pair.',
        ),
        _NumberedStep(
          number: 3,
          title: 'Add camera in the app',
          body: 'Tap "+" → "Add Device" → follow the WiFi pairing wizard. '
                'Select your ward\'s WiFi network and enter the password. '
                'The camera will connect within 30–60 seconds.',
        ),
        _NumberedStep(
          number: 4,
          title: 'Confirm it\'s working in the app',
          body: 'You should see a live video feed in the mobile app. '
                'This confirms the camera is on your network.',
        ),
        const SizedBox(height: 20),
        _SectionTitle('Option B — LAN Cable (Hikvision / Dahua)'),
        const SizedBox(height: 12),
        _NumberedStep(
          number: 1,
          title: 'Connect with Ethernet',
          body: 'Plug a network cable from the camera\'s LAN port '
                'directly into your router or network switch.',
        ),
        _NumberedStep(
          number: 2,
          title: 'Power via PoE or adapter',
          body: 'PoE (Power over Ethernet) — single cable for both power and data. '
                'Or use the included 12V power adapter separately.',
        ),
        _NumberedStep(
          number: 3,
          title: 'Camera joins your network automatically',
          body: 'The router assigns an IP via DHCP. '
                'The camera is ready — no app needed for basic RTSP access.',
        ),
        const SizedBox(height: 20),
        _TipBox(
          text: '⚠️  IMPORTANT: This PC (FolioMed Edge) and the camera MUST be on the same '
                'network. If the camera is on a separate IoT VLAN, RTSP will fail. '
                'Ask your IT staff to put them on the same subnet.',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  STEP 3 — Find Camera IP
// ═══════════════════════════════════════════════

class _StepFindIP extends StatelessWidget {
  final TextEditingController ipCtrl;
  final TextEditingController portCtrl;
  const _StepFindIP({required this.ipCtrl, required this.portCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.search,
          title: 'Find Your Camera\'s IP Address',
          subtitle: 'Every camera on your network has a unique IP address. '
                    'You need this to connect FolioMed Edge to your camera.',
        ),
        const SizedBox(height: 24),
        _SectionTitle('3 Ways to Find the IP'),
        const SizedBox(height: 12),
        _FindIPMethod(
          letter: 'A',
          title: 'Check Your Router',
          color: AppColors.primary,
          steps: [
            'Open a browser on this PC',
            'Go to 192.168.1.1 or 192.168.0.1 (your router admin page)',
            'Log in (usually admin / admin or admin / password)',
            'Go to "Connected Devices" or "DHCP Clients"',
            'Look for a device named after your camera brand',
          ],
        ),
        const SizedBox(height: 12),
        _FindIPMethod(
          letter: 'B',
          title: 'Use the Camera App',
          color: AppColors.stable,
          steps: [
            'Open iCSee / Hik-Connect / CamHi app on your phone',
            'Tap the camera → Settings (⚙️)',
            'Go to "Device Info" or "Network Info"',
            'The IP address is shown there',
          ],
        ),
        const SizedBox(height: 12),
        _FindIPMethod(
          letter: 'C',
          title: 'Use SADP Tool (Hikvision/Dahua)',
          color: Color(0xFF7B4F00),
          steps: [
            'Download "SADP Tool" from Hikvision\'s website',
            'Run it on this PC — it scans your network',
            'Your camera will appear with its IP address',
            'You can also reset the password from here if needed',
          ],
        ),
        const SizedBox(height: 28),
        _SectionTitle('Enter Camera Details'),
        const SizedBox(height: 12),
        _FieldCard(
          label: 'Camera IP Address',
          hint: 'e.g. 192.168.1.108',
          controller: ipCtrl,
          keyboardType: TextInputType.number,
          icon: Icons.router_outlined,
        ),
        const SizedBox(height: 12),
        _FieldCard(
          label: 'RTSP Port',
          hint: '554',
          controller: portCtrl,
          keyboardType: TextInputType.number,
          icon: Icons.settings_ethernet,
          helperText: 'Default is 554. Only change if your camera uses a different port.',
        ),
        const SizedBox(height: 16),
        _TipBox(
          text: 'Common default IPs: 192.168.1.64 (CP Plus), 192.168.1.108 (Hikvision), '
                '192.168.1.108 (Dahua). If you set a static IP during WiFi setup, use that.',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  STEP 4 — Build RTSP URL
// ═══════════════════════════════════════════════

class _StepBuildRtsp extends StatelessWidget {
  final String brand;
  final TextEditingController ipCtrl;
  final TextEditingController portCtrl;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final TextEditingController customRtspCtrl;
  final bool useCustom;
  final bool passVisible;
  final void Function(bool) onToggleCustom;
  final VoidCallback onTogglePass;
  final CameraConfig draft;

  const _StepBuildRtsp({
    required this.brand,
    required this.ipCtrl,
    required this.portCtrl,
    required this.userCtrl,
    required this.passCtrl,
    required this.customRtspCtrl,
    required this.useCustom,
    required this.passVisible,
    required this.onToggleCustom,
    required this.onTogglePass,
    required this.draft,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.link,
          title: 'Camera Login & RTSP URL',
          subtitle: 'Enter your camera\'s username and password. '
                    'FolioMed will auto-build the RTSP stream URL.',
        ),
        const SizedBox(height: 24),

        // Toggle: auto vs custom
        Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Auto (recommended)',
                icon: Icons.auto_fix_high,
                active: !useCustom,
                onTap: () => onToggleCustom(false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeButton(
                label: 'Enter manually',
                icon: Icons.edit_outlined,
                active: useCustom,
                onTap: () => onToggleCustom(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (!useCustom) ...[
          _FieldCard(
            label: 'Username',
            hint: 'admin',
            controller: userCtrl,
            icon: Icons.person_outline,
            helperText: 'Default is "admin" for most cameras.',
          ),
          const SizedBox(height: 12),
          _PasswordField(
            controller: passCtrl,
            visible: passVisible,
            onToggle: onTogglePass,
          ),
          const SizedBox(height: 24),
          _SectionTitle('Auto-Generated RTSP URL'),
          const SizedBox(height: 10),
          _RTSPPreview(url: draft.rtspUrl),
          const SizedBox(height: 8),
          _BrandRTSPNote(brand: brand),
        ] else ...[
          _FieldCard(
            label: 'Full RTSP URL',
            hint: 'rtsp://admin:password@192.168.1.64:554/stream1',
            controller: customRtspCtrl,
            icon: Icons.link,
            helperText: 'Check your camera\'s manual for the exact RTSP URL format.',
          ),
          const SizedBox(height: 16),
          _TipBox(text: 'Format: rtsp://username:password@IP:port/path\n'
              'CP Plus: /stream1 or /live/ch00_0\n'
              'Hikvision: /Streaming/Channels/101\n'
              'Dahua: /cam/realmonitor?channel=1&subtype=0'),
        ],
        const SizedBox(height: 16),
        _TipBox(
          text: '⚠️  Change your camera\'s default password before deploying in a hospital. '
                'Default "admin/admin" is a security risk on a clinical network.',
          color: AppColors.warningColor.withOpacity(0.08),
          borderColor: AppColors.warningColor,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  STEP 5 — Test Connection
// ═══════════════════════════════════════════════

class _StepTestConnection extends StatefulWidget {
  final CameraConfig draft;
  const _StepTestConnection({required this.draft});

  @override
  State<_StepTestConnection> createState() => _StepTestConnectionState();
}

class _StepTestConnectionState extends State<_StepTestConnection> {
  bool _copied = false;

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.draft.rtspUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.play_circle_outline,
          title: 'Test Your Camera Connection',
          subtitle: 'Before connecting to FolioMed, verify the RTSP stream works using VLC — '
                    'a free media player.',
        ),
        const SizedBox(height: 24),
        _SectionTitle('Your RTSP URL'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  url,
                  style: GoogleFonts.robotoMono(
                      color: const Color(0xFF7CFC00), fontSize: 12),
                ),
              ),
              IconButton(
                onPressed: () => _copy(url),
                icon: Icon(
                  _copied ? Icons.check : Icons.copy,
                  size: 18,
                  color: _copied ? AppColors.stable : Colors.white54,
                ),
                tooltip: 'Copy URL',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionTitle('How to Test in VLC'),
        const SizedBox(height: 12),
        _NumberedStep(
          number: 1,
          title: 'Download VLC',
          body: 'Get VLC Media Player free from videolan.org — available for Windows and Mac.',
        ),
        _NumberedStep(
          number: 2,
          title: 'Open Network Stream',
          body: 'In VLC: Media menu → Open Network Stream (Ctrl+N on Windows, Cmd+N on Mac)',
        ),
        _NumberedStep(
          number: 3,
          title: 'Paste your RTSP URL',
          body: 'Paste the URL shown above → click Play. '
                'You should see a live video from your camera within 5–10 seconds.',
        ),
        _NumberedStep(
          number: 4,
          title: 'If it doesn\'t connect',
          body: '• Check the camera is powered on and LED is solid\n'
                '• Confirm this PC and camera are on the same network\n'
                '• Verify the IP address — ping it: open CMD/Terminal and run: ping 192.168.x.x\n'
                '• Try the camera\'s mobile app to confirm it\'s online',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.stable.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.stable.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.stable, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Once you can see the live video in VLC, your camera is working correctly. '
                  'Tap Continue to assign it to a patient.',
                  style: GoogleFonts.dmSans(
                      color: AppColors.stable, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  STEP 6 — Map to Patient
// ═══════════════════════════════════════════════

class _StepMapPatient extends StatelessWidget {
  final TextEditingController labelCtrl;
  final TextEditingController bedCtrl;
  final String selectedPatientId;
  final String selectedPatientName;
  final void Function(String id, String name) onPatientSelected;

  const _StepMapPatient({
    required this.labelCtrl,
    required this.bedCtrl,
    required this.selectedPatientId,
    required this.selectedPatientName,
    required this.onPatientSelected,
  });

  @override
  Widget build(BuildContext context) {
    final monitor = context.watch<MonitorProvider>();
    final patients = monitor.patients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.person_pin_outlined,
          title: 'Assign Camera to Patient',
          subtitle: 'Link this camera to a patient so FolioMed knows '
                    'which vital readings come from which bed.',
        ),
        const SizedBox(height: 24),
        _FieldCard(
          label: 'Camera Label',
          hint: 'e.g. Bed 3 Camera, ICU Cam 1',
          controller: labelCtrl,
          icon: Icons.label_outline,
          helperText: 'A friendly name to identify this camera in the dashboard.',
        ),
        const SizedBox(height: 16),
        _SectionTitle('Select Patient'),
        const SizedBox(height: 10),
        if (patients.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                Icon(Icons.people_outline, color: AppColors.textSecondary, size: 32),
                const SizedBox(height: 8),
                Text('No patients in Monitor yet.',
                    style: GoogleFonts.dmSans(
                        color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Add patients in the Patients tab first, or skip this step '
                  'and assign later from the Monitor dashboard.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          )
        else ...[
          for (final p in patients)
            GestureDetector(
              onTap: () => onPatientSelected(p.id, p.name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: selectedPatientId == p.id
                      ? AppColors.primary.withOpacity(0.08)
                      : AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedPatientId == p.id ? AppColors.primary : AppColors.divider,
                    width: selectedPatientId == p.id ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('${p.ward} · ${p.bed}',
                              style: GoogleFonts.dmSans(
                                  color: AppColors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (selectedPatientId == p.id)
                      const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        _FieldCard(
          label: 'Bed / Location Label (optional)',
          hint: 'e.g. Bed 3, Incubator 2',
          controller: bedCtrl,
          icon: Icons.bed_outlined,
          helperText: 'Shown alongside the camera feed in the dashboard.',
        ),
        const SizedBox(height: 16),
        _TipBox(
          text: 'You can skip patient assignment and set it up later from '
                'the Monitor dashboard → camera settings.',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  STEP 7 — Done
// ═══════════════════════════════════════════════
//  STEP 7 — ROI Prompt
// ═══════════════════════════════════════════════

class _StepRoiPrompt extends StatelessWidget {
  final CameraConfig draft;
  final VoidCallback onLaunchEditor;
  const _StepRoiPrompt({required this.draft, required this.onLaunchEditor});

  static const _vitalLabels = {
    VitalType.hr:   'Heart Rate',
    VitalType.spo2: 'SpO₂',
    VitalType.rr:   'Resp. Rate',
    VitalType.sbp:  'Blood Pressure',
  };
  static const _vitalColors = {
    VitalType.hr:   Color(0xFFE53935),
    VitalType.spo2: Color(0xFF1976D2),
    VitalType.rr:   Color(0xFF388E3C),
    VitalType.sbp:  Color(0xFF7B1FA2),
  };

  @override
  Widget build(BuildContext context) {
    final roiCount = draft.roiZoneCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepHeader(
          icon: Icons.crop_free,
          title: 'Define Vital Zones',
          subtitle: 'Tell FolioMed Edge exactly where each vital number appears on '
                    'the monitor screen. This is what makes auto-reading work accurately.',
        ),
        const SizedBox(height: 24),

        // Why it matters
        _InfoCard(
          icon: Icons.precision_manufacturing_outlined,
          title: 'Why this matters',
          body: 'Without zones, FolioMed reads the entire camera frame — which is noisy. '
                'With zones, it crops only the HR box, SpO₂ box, etc. — giving much '
                'more accurate OCR results and reducing cloud processing cost.',
        ),
        const SizedBox(height: 16),

        // Current zones status
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    roiCount > 0 ? Icons.check_circle_outline : Icons.radio_button_unchecked,
                    color: roiCount > 0 ? AppColors.stable : AppColors.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    roiCount > 0
                        ? '$roiCount vital zone${roiCount > 1 ? 's' : ''} defined'
                        : 'No zones defined yet',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      color: roiCount > 0 ? AppColors.stable : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (roiCount > 0) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  children: [
                    VitalType.hr, VitalType.spo2, VitalType.rr, VitalType.sbp,
                  ].map((vt) {
                    final defined = draft.roi.containsKey(vt);
                    final color = _vitalColors[vt]!;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: defined ? color.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: defined ? color : AppColors.divider),
                      ),
                      child: Text(
                        _vitalLabels[vt]!,
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: defined ? color : AppColors.textSecondary,
                          fontWeight: defined ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onLaunchEditor,
            icon: const Icon(Icons.crop_free, size: 20),
            label: Text(
              roiCount > 0 ? 'Edit Vital Zones' : 'Draw Vital Zones',
              style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        _TipBox(
          text: 'You can skip this now and define zones later from FolioMed Edge → camera → Edit Zones. '
                'Without zones the camera still works — just with lower OCR accuracy.',
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════

class _StepDone extends StatelessWidget {
  final CameraConfig draft;
  final VoidCallback onAddAnother;
  const _StepDone({required this.draft, required this.onAddAnother});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: AppColors.stable.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: AppColors.stable, size: 44),
          ),
        ),
        const SizedBox(height: 20),
        Text('Camera Ready!',
            style: GoogleFonts.dmSans(
                fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'FolioMed Edge is configured.\nVital readings will begin appearing in the Monitor tab.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
              color: AppColors.textSecondary, fontSize: 14, height: 1.6),
        ),
        const SizedBox(height: 28),

        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Configuration Summary',
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              _SummaryRow(label: 'Camera Label', value: draft.label.isEmpty ? '—' : draft.label),
              _SummaryRow(label: 'Brand', value: draft.brand),
              _SummaryRow(label: 'IP Address', value: draft.ip.isEmpty ? '—' : '${draft.ip}:${draft.port}'),
              _SummaryRow(label: 'Patient', value: draft.patientName.isEmpty ? 'Not assigned' : draft.patientName),
              _SummaryRow(label: 'Bed', value: draft.bedLabel.isEmpty ? '—' : draft.bedLabel),
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.link, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: SelectableText(
                      draft.rtspUrl,
                      style: GoogleFonts.robotoMono(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _NextStepCard(
          icon: Icons.monitor_heart_outlined,
          title: 'Open Monitor Dashboard',
          body: 'View live vitals and confirm data is flowing from your camera.',
          color: AppColors.primary,
        ),
        const SizedBox(height: 10),
        _NextStepCard(
          icon: Icons.videocam_outlined,
          title: 'Mount the Camera',
          body: 'Secure the camera to point directly at the bedside monitor screen. '
                'Distance: 60–100 cm. Avoid glare from ward lights.',
          color: AppColors.stable,
        ),
        const SizedBox(height: 10),
        _NextStepCard(
          icon: Icons.security_outlined,
          title: 'Change Default Password',
          body: 'Log into your camera\'s web interface and change the default password '
                'for clinical network security.',
          color: AppColors.warningColor,
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: onAddAnother,
          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
          label: const Text('Add Another Camera'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  Shared Small Widgets
// ═══════════════════════════════════════════════

class _StepHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _StepHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(height: 14),
        Text(title,
            style: GoogleFonts.dmSans(
                fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: GoogleFonts.dmSans(
                color: AppColors.textSecondary, fontSize: 13, height: 1.5)),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoCard({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(body,
                    style: GoogleFonts.dmSans(
                        color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipBox extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? borderColor;
  const _TipBox({required this.text, this.color, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor ?? AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: borderColor ?? AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.dmSans(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3));
  }
}

class _NumberedStep extends StatelessWidget {
  final int number;
  final String title;
  final String body;
  const _NumberedStep({required this.number, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$number',
                  style: GoogleFonts.dmSans(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(body,
                    style: GoogleFonts.dmSans(
                        color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FindIPMethod extends StatelessWidget {
  final String letter;
  final String title;
  final Color color;
  final List<String> steps;
  const _FindIPMethod({required this.letter, required this.title, required this.color, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
                child: Center(
                  child: Text(letter,
                      style: GoogleFonts.dmSans(
                          color: color, fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 38),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ',
                      style: GoogleFonts.dmSans(
                          color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Text(steps[i],
                        style: GoogleFonts.dmSans(
                            color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final IconData icon;
  final String? helperText;
  const _FieldCard({
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType,
    required this.icon,
    this.helperText,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        helperMaxLines: 2,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: GoogleFonts.dmSans(color: AppColors.textSecondary),
        hintStyle: GoogleFonts.dmSans(color: AppColors.textSecondary.withOpacity(0.5)),
        helperStyle: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 11),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool visible;
  final VoidCallback onToggle;
  const _PasswordField({required this.controller, required this.visible, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !visible,
      style: GoogleFonts.dmSans(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: 'Camera Password',
        hintText: 'Your camera login password',
        helperText: 'Default is "admin" or "12345" for most cameras. Check the sticker on the camera.',
        helperMaxLines: 2,
        prefixIcon: Icon(Icons.lock_outline, size: 20, color: AppColors.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_off : Icons.visibility,
              size: 20, color: AppColors.textSecondary),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle: GoogleFonts.dmSans(color: AppColors.textSecondary),
        helperStyle: GoogleFonts.dmSans(color: AppColors.textSecondary, fontSize: 11),
      ),
    );
  }
}

class _RTSPPreview extends StatefulWidget {
  final String url;
  const _RTSPPreview({required this.url});

  @override
  State<_RTSPPreview> createState() => _RTSPPreviewState();
}

class _RTSPPreviewState extends State<_RTSPPreview> {
  bool _copied = false;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.url));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              widget.url,
              style: GoogleFonts.robotoMono(
                  color: const Color(0xFF7CFC00), fontSize: 12),
            ),
          ),
          IconButton(
            onPressed: _copy,
            icon: Icon(
              _copied ? Icons.check : Icons.copy,
              size: 18,
              color: _copied ? AppColors.stable : Colors.white54,
            ),
            tooltip: 'Copy',
          ),
        ],
      ),
    );
  }
}

class _BrandRTSPNote extends StatelessWidget {
  final String brand;
  const _BrandRTSPNote({required this.brand});

  @override
  Widget build(BuildContext context) {
    final notes = {
      'CP Plus':   'CP Plus uses /stream1 for main stream, /stream2 for sub-stream (lower resolution).',
      'Hikvision': 'Hikvision: /Streaming/Channels/101 = main, /201 = second camera, /102 = sub-stream.',
      'Dahua':     'Dahua: subtype=0 = main stream, subtype=1 = sub-stream.',
      'TrueView':  'TrueView uses /stream1. If it fails try /live/ch00_0.',
      'Other (ONVIF)': 'ONVIF cameras vary. Check your camera manual or ask the vendor for the RTSP path.',
    };
    final note = notes[brand];
    if (note == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(note,
          style: GoogleFonts.dmSans(
              color: AppColors.textSecondary, fontSize: 11, height: 1.5)),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ModeButton({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.divider,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? AppColors.primary : AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.dmSans(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.dmSans(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  const _NextStepCard({required this.icon, required this.title, required this.body, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.dmSans(
                        color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 3),
                Text(body,
                    style: GoogleFonts.dmSans(
                        color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
