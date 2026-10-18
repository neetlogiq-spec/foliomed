import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Lifecycle states of the embedded AI engine.
enum VlmEngineStatus { off, starting, running, external, error }

/// Runs the FolioMed vitals VLM *inside* FolioMed Edge.
///
/// On desktop the app owns the AI engine: it spawns llama.cpp's
/// `llama-server` as a supervised child process on launch, waits for the
/// model to load, and kills it on quit. No terminal, no manual server —
/// the localhost port is an internal implementation detail.
///
/// If a server is already reachable (e.g. one shared engine for several
/// apps on the hospital box), it is reused and left untouched on quit.
class VlmServerManager {
  VlmServerManager._();
  static final VlmServerManager instance = VlmServerManager._();

  static const String prefModelDirKey = 'edge_vlm_model_dir_v1';
  static const int port = 8080;

  final ValueNotifier<VlmEngineStatus> status =
      ValueNotifier(VlmEngineStatus.off);

  /// Human-readable reason when [status] is [VlmEngineStatus.error].
  String? errorDetail;

  Process? _proc;
  bool _startInFlight = false;
  AppLifecycleListener? _lifecycle;

  String get baseUrl => 'http://127.0.0.1:$port';

  bool get _isDesktop =>
      !kIsWeb && (Platform.isMacOS || Platform.isLinux || Platform.isWindows);

  /// Idempotent: safe to call from every Edge screen's initState.
  Future<void> ensureRunning() async {
    if (!_isDesktop) return;
    if (_startInFlight) return;
    if ((status.value == VlmEngineStatus.running ||
            status.value == VlmEngineStatus.external) &&
        await _healthy()) {
      return;
    }

    _startInFlight = true;
    try {
      if (await _healthy()) {
        status.value =
            _proc == null ? VlmEngineStatus.external : VlmEngineStatus.running;
        return;
      }

      final binary = _findBinary();
      if (binary == null) {
        errorDetail = 'llama-server not found (brew install llama.cpp)';
        status.value = VlmEngineStatus.error;
        return;
      }
      final models = await _findModels();
      if (models == null) {
        errorDetail = 'Model files not found (expected ~/foliomed-model-v3)';
        status.value = VlmEngineStatus.error;
        return;
      }

      status.value = VlmEngineStatus.starting;
      _proc = await Process.start(binary, [
        '-m', models.$1,
        '--mmproj', models.$2,
        '--host', '127.0.0.1',
        '--port', '$port',
      ]);
      // Drain output so the child never blocks on a full pipe.
      _proc!.stdout.drain<void>();
      _proc!.stderr.drain<void>();
      final started = _proc!;
      started.exitCode.then((code) {
        if (_proc != started) return; // superseded or already stopped
        _proc = null;
        errorDetail = 'AI engine exited (code $code)';
        status.value =
            code == 0 ? VlmEngineStatus.off : VlmEngineStatus.error;
      });

      // Kill the child when the app quits; a detached engine would keep
      // ~5 GB of RAM alive with no UI attached to it.
      _lifecycle ??= AppLifecycleListener(onExitRequested: () async {
        stop();
        return AppExitResponse.exit;
      });

      // The 4.7 GB model takes a while to load from disk — poll patiently.
      final deadline = DateTime.now().add(const Duration(minutes: 5));
      while (DateTime.now().isBefore(deadline)) {
        if (_proc == null) return; // crashed; exitCode handler set status
        if (await _healthy()) {
          status.value = VlmEngineStatus.running;
          return;
        }
        await Future.delayed(const Duration(seconds: 3));
      }
      errorDetail = 'AI engine did not become ready in 5 minutes';
      status.value = VlmEngineStatus.error;
      stop();
    } finally {
      _startInFlight = false;
    }
  }

  /// Kill the engine if we spawned it. External servers are left alone.
  void stop() {
    final p = _proc;
    _proc = null;
    p?.kill();
    if (status.value != VlmEngineStatus.external) {
      status.value = VlmEngineStatus.off;
    }
  }

  Future<bool> _healthy() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String? _findBinary() {
    final home = Platform.environment['HOME'] ?? '';
    // Bundled next to the app binary wins (future packaged distribution),
    // then the usual install locations.
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir/../Resources/llama-server',
      '/usr/local/bin/llama-server',
      '/opt/homebrew/bin/llama-server',
      '$home/llama.cpp/build/bin/llama-server',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Returns (model, mmproj) paths, preferring the quantized model.
  Future<(String, String)?> _findModels() async {
    final home = Platform.environment['HOME'] ?? '';
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(prefModelDirKey);
    final dirs = [
      if (custom != null && custom.isNotEmpty) custom,
      '$home/foliomed-model-v3',
      '$home/foliomed-model',
    ];
    for (final d in dirs) {
      final dir = Directory(d);
      if (!dir.existsSync()) continue;
      final ggufs = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.gguf'))
          .map((f) => f.path)
          .toList();
      final mmproj = ggufs.where((p) => p.contains('mmproj')).toList();
      final models = ggufs.where((p) => !p.contains('mmproj')).toList()
        ..sort((a, b) {
          int rank(String p) => p.contains('q4_k_m') ? 0 : 1;
          return rank(a).compareTo(rank(b));
        });
      if (mmproj.isNotEmpty && models.isNotEmpty) {
        return (models.first, mmproj.first);
      }
    }
    return null;
  }
}
