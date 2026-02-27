// Stub library for non-web platforms so that
// `dart:js` conditional import doesn't fail at compile time.
// This file is never actually called on Android/iOS/Windows.
library js_stub;

// ignore_for_file: avoid_classes_with_only_static_members

class _JsContext {
  dynamic operator [](String key) => null;
  void operator []=(String key, dynamic value) {}
  dynamic callMethod(String method, [List? args]) => null;
}

final context = _JsContext();

dynamic allowInterop(Function f) => f;
