import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:foliomed/utils/stream_cache.dart';

void main() {
  test('returns the same stream for the same key', () {
    final cache = StreamCache<int>();
    var created = 0;
    Stream<int> create() {
      created++;
      return Stream.value(1);
    }

    final a = cache.get('k', create);
    final b = cache.get('k', create);
    expect(identical(a, b), isTrue);
    expect(created, 0, reason: 'source is created lazily on listen');
  });

  test('a new key yields a new stream', () {
    final cache = StreamCache<int>();
    final a = cache.get('a', () => Stream.value(1));
    final b = cache.get('b', () => Stream.value(2));
    expect(identical(a, b), isFalse);
  });

  test('cached stream can be listened to more than once', () async {
    final cache = StreamCache<int>();
    var created = 0;
    final stream = cache.get('k', () {
      created++;
      return Stream.fromIterable([1, 2, 3]);
    });

    expect(await stream.toList(), [1, 2, 3]);
    expect(await stream.toList(), [1, 2, 3]);
    expect(created, 2, reason: 'each listener gets its own source');
  });

  test('cancelling a listener cancels its source subscription', () async {
    final cache = StreamCache<int>();
    var cancelled = false;
    final controller = StreamController<int>(onCancel: () => cancelled = true);
    final stream = cache.get('k', () => controller.stream);

    final sub = stream.listen((_) {});
    await sub.cancel();
    expect(cancelled, isTrue);
  });

  test('errors propagate to the listener', () async {
    final cache = StreamCache<int>();
    final stream = cache.get('k', () => Stream<int>.error(StateError('boom')));
    await expectLater(stream, emitsError(isA<StateError>()));
  });
}
