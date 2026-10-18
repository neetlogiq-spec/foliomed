import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/monitor_vitals.dart';
import 'vlm_server_manager.dart';

/// One VLM read of a bedside monitor photo.
///
/// Unlike the regex OCR path, the model reads HR and PR independently and
/// can return an explicit MAP (e.g. NON-PULSATILE arterial lines show only
/// a mean), so this is kept separate from [ParsedVitals].
class VlmVitals {
  final double? hr;
  final double? pr;
  final double? spo2;
  final double? rr;
  final double? bpSys;
  final double? bpDia;
  final double? bpMap;
  final DateTime timestamp;

  const VlmVitals({
    this.hr,
    this.pr,
    this.spo2,
    this.rr,
    this.bpSys,
    this.bpDia,
    this.bpMap,
    required this.timestamp,
  });

  Map<VitalType, double> toVitalMap() {
    final m = <VitalType, double>{};
    // The monitor dashboard has no PR slot yet — fall back to PR for HR
    // only when HR itself is unreadable, so the ward still sees a rate.
    final rate = hr ?? pr;
    if (rate != null) m[VitalType.hr] = rate;
    if (spo2 != null) m[VitalType.spo2] = spo2!;
    if (rr != null) m[VitalType.rr] = rr!;
    if (bpSys != null) m[VitalType.sbp] = bpSys!;
    if (bpDia != null) m[VitalType.dbp] = bpDia!;
    final mapVal = bpMap ??
        ((bpSys != null && bpDia != null)
            ? ((bpSys! + 2 * bpDia!) / 3).roundToDouble()
            : null);
    if (mapVal != null) m[VitalType.map] = mapVal;
    return m;
  }

  bool get hasAnyVital =>
      hr != null ||
      pr != null ||
      spo2 != null ||
      rr != null ||
      bpSys != null ||
      bpMap != null;

  @override
  String toString() {
    String f(double? v) => v == null ? '–' : '${v.round()}';
    final bp = (bpSys == null && bpDia == null && bpMap != null)
        ? '(${f(bpMap)})'
        : '${f(bpSys)}/${f(bpDia)}';
    return 'HR:${f(hr)} PR:${f(pr)} SpO2:${f(spo2)} RR:${f(rr)} BP:$bp';
  }
}

/// Talks to the local FolioMed VLM served by llama.cpp's `llama-server`
/// (OpenAI-compatible API). Started with:
///
///   llama-server -m ~/foliomed-model-v3/foliomed-v3-q4_k_m.gguf \
///     --mmproj ~/foliomed-model-v3/mmproj-foliomed-model-v3-BF16.gguf --port 8080
///
/// See tools/start_vlm_server.sh. One read can take minutes on CPU-only
/// hardware, so callers must respect [isBusy] and skip frames meanwhile.
class VlmVitalsService {
  static const String prefUrlKey = 'edge_vlm_url_v1';
  static const String defaultUrl = 'http://127.0.0.1:8080';

  /// The tested inference instruction from the foliomed-vitals-ai playbook
  /// (scripts/4_run_and_test.md). Keep byte-identical with that file —
  /// the model was validated against this exact wording.
  static const String prompt =
      "Extract the vital signs from this patient monitor photo. Returning null for a value you cannot confidently read is the CORRECT answer, not a failure or an incomplete response - it is exactly what is wanted. Guessing a plausible-looking number for a field you are not genuinely confident about is WRONG, even if the guess happens to be close, and is treated as an error - a wrong number in this context could mislead a doctor treating a real patient. Do not try to fill in every field just to give a complete-looking answer. However, if you CAN clearly and confidently read a value, you must report it - do not default to null out of excessive caution when the evidence is genuinely clear. The monitor may show: hr (heart rate from ECG), pr (pulse rate from the pulse-oximetry/SpO2 probe - may differ from hr, report both if both shown), spo2 (oxygen saturation, always 70-100), rr (respiratory rate), and blood pressure shown as SYS/DIA(MAP) - for example '120/80 (93)' means bp_sys=120, bp_dia=80, bp_map=93. Sometimes (e.g. when a monitor shows 'NON-PULSATILE' for an arterial line) ONLY a single parenthetical mean value is shown with no sys/dia pair at all - for example just '(87)' alone. In that case, set bp_map=87 and leave bp_sys and bp_dia null - do not invent sys/dia numbers to complete the usual pattern, and do not place the lone value in the wrong field (e.g. hr). Different monitors use different colors for the same parameter - do not assume a color always means the same thing. Always match each value to its actual text label on screen, not its color or position. If any parameter shows as disconnected, invalid, or a '?' symbol on the monitor, return null for that specific field - do not substitute a number from elsewhere on the screen. This applies even if a DIFFERENT related field has a valid value - for example, if HR shows '?' but Pulse/PR shows a real number, hr must still be null, NOT copied from pr. hr and pr are independent and must never be duplicated into each other. This applies even when both are valid and close together (e.g. hr=151, pr=149) - read and report each one's actual exact digits independently, do not round one to match the other or assume they must be equal just because they are close. Small numbers shown above or next to the main value (e.g. two stacked numbers like 200 and 100 near an HR display, or 100 and 90 near a SpO2 display, or 100 and 20 near a RESP display) are ALARM LIMITS (configured upper/lower thresholds) for that specific parameter - this applies to EVERY field, not just HR. Never use an alarm limit as the value, and never include alarm limits anywhere in your output. The real current reading is always the large/prominent number, or the '?' symbol if invalid. If the photo itself is blurry, low-resolution, or a value's digits are too compressed/small to read with real confidence, return null for that specific field rather than guessing your best interpretation of unclear digits - a confident-looking wrong number is worse than an honest null. This monitor may display additional parameters beyond these 7 fields - for example CO2/EtCO2, CVP (Central Venous Pressure), or Temperature (T1/T2). These are NOT part of the requested output - completely ignore them. Do not let their values influence, replace, or get confused with hr, pr, spo2, rr, bp_sys, bp_dia, or bp_map. In particular, CVP is a different pressure measurement from arterial blood pressure and must never be read as bp_map. Return JSON with keys: hr, pr, spo2, rr, bp_sys, bp_dia, bp_map. Use null for anything not clearly visible or marked invalid/disconnected.";

  /// One read can take minutes on a CPU-only Mac — generous by design.
  static const Duration _readTimeout = Duration(minutes: 15);

  bool _busy = false;
  bool get isBusy => _busy;

  http.Client? _activeClient;

  /// Abort the in-flight read. Closing the connection also makes
  /// llama-server cancel the inference slot, freeing the CPU immediately.
  void cancelActive() {
    _activeClient?.close();
    _activeClient = null;
  }

  Future<String> _baseUrl() async {
    // The embedded engine (spawned and supervised by VlmServerManager)
    // takes precedence; the pref is an override for a remote/shared box.
    final mgr = VlmServerManager.instance;
    if (mgr.status.value == VlmEngineStatus.running ||
        mgr.status.value == VlmEngineStatus.external) {
      return mgr.baseUrl;
    }
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(prefUrlKey);
    return (url == null || url.isEmpty) ? defaultUrl : url;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefUrlKey, url.trim());
  }

  /// Quick reachability probe — llama-server exposes GET /health.
  Future<bool> isAvailable() async {
    try {
      final base = await _baseUrl();
      final res = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Send one monitor frame to the VLM. Returns null on any failure
  /// (callers fall back to the regex OCR path). Skips if a read is already
  /// in flight — never queue frames behind a minutes-long inference.
  ///
  /// [cropRegion] is a normalized (0–1) rect. Pass the monitor-screen area
  /// (NOT a single-digit zone — the model needs the whole screen's labels
  /// and layout, it was trained on full monitor photos). Cropping away the
  /// room background means fewer image tokens → several times faster reads
  /// and sharper digits at the same token budget.
  Future<VlmVitals?> processFile(File imageFile,
      {ui.Rect? cropRegion}) async {
    if (_busy) return null;
    _busy = true;
    try {
      final base = await _baseUrl();
      var bytes = await imageFile.readAsBytes();
      var mime = 'image/jpeg';
      if (cropRegion != null) {
        try {
          bytes = await _cropToRegion(bytes, cropRegion);
          mime = 'image/png';
        } catch (_) {
          // Crop failure is never fatal — send the full frame instead.
        }
      }
      final b64 = base64Encode(bytes);
      final body = jsonEncode({
        'temperature': 0.1,
        'max_tokens': 128,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'image_url',
                'image_url': {'url': 'data:$mime;base64,$b64'},
              },
              {'type': 'text', 'text': prompt},
            ],
          },
        ],
      });

      final client = http.Client();
      _activeClient = client;
      final http.Response res;
      try {
        res = await client
            .post(
              Uri.parse('$base/v1/chat/completions'),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(_readTimeout);
      } finally {
        if (identical(_activeClient, client)) _activeClient = null;
        client.close();
      }
      if (res.statusCode != 200) return null;

      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      final content =
          decoded['choices']?[0]?['message']?['content'] as String?;
      if (content == null || content.isEmpty) return null;
      return _parse(content);
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }

  /// Crop [bytes] to the normalized [region] using the Flutter engine
  /// (no extra image package needed). Returns PNG bytes.
  Future<Uint8List> _cropToRegion(Uint8List bytes, ui.Rect region) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;
    try {
      final src = ui.Rect.fromLTWH(
        (region.left.clamp(0.0, 1.0)) * img.width,
        (region.top.clamp(0.0, 1.0)) * img.height,
        (region.width.clamp(0.0, 1.0)) * img.width,
        (region.height.clamp(0.0, 1.0)) * img.height,
      );
      final w = src.width.round().clamp(16, img.width);
      final h = src.height.round().clamp(16, img.height);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        img,
        src,
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint(),
      );
      final out = await recorder.endRecording().toImage(w, h);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      out.dispose();
      if (data == null) throw StateError('PNG encode failed');
      return data.buffer.asUint8List();
    } finally {
      img.dispose();
    }
  }

  /// Extract the JSON object from the model reply (tolerates ```json fences
  /// or prose around it) and map its 7 keys.
  VlmVitals? _parse(String content) {
    final match = RegExp(r'\{[\s\S]*?\}').firstMatch(content);
    if (match == null) return null;
    try {
      final j = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      double? num_(String key) {
        final v = j[key];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v);
        return null;
      }

      return VlmVitals(
        hr: num_('hr'),
        pr: num_('pr'),
        spo2: num_('spo2'),
        rr: num_('rr'),
        bpSys: num_('bp_sys'),
        bpDia: num_('bp_dia'),
        bpMap: num_('bp_map'),
        timestamp: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }
}
