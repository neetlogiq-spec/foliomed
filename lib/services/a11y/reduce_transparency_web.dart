import 'dart:js_interop';

@JS('window.matchMedia')
external _MediaQueryList _matchMedia(String query);

extension type _MediaQueryList(JSObject _) implements JSObject {
  external bool get matches;
}

/// `prefers-reduced-transparency: reduce` (Safari / Chromium).
bool webPrefersReducedTransparency() {
  try {
    return _matchMedia('(prefers-reduced-transparency: reduce)').matches;
  } catch (_) {
    return false;
  }
}
