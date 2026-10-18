/// Keeps one stream per key so a widget's `build` can ask for a stream on
/// every rebuild without opening a new realtime subscription each time.
///
/// Each cached stream may be listened to more than once (e.g. a tab that
/// is disposed and rebuilt); every listener gets its own source
/// subscription, which is cancelled when that listener goes away.
class StreamCache<T> {
  final Map<String, Stream<T>> _streams = {};

  Stream<T> get(String key, Stream<T> Function() create) =>
      _streams.putIfAbsent(key, () => _reListenable(create));

  static Stream<T> _reListenable<T>(Stream<T> Function() create) {
    return Stream<T>.multi((controller) {
      final sub = create().listen(
        controller.addSync,
        onError: controller.addErrorSync,
        onDone: controller.closeSync,
      );
      controller.onCancel = sub.cancel;
    });
  }
}
