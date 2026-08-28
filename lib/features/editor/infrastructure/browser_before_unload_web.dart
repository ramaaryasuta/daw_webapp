import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_before_unload.dart';

BrowserBeforeUnloadGuard createPlatformBeforeUnloadGuard() =>
    _WebBeforeUnloadGuard();

class _WebBeforeUnloadGuard implements BrowserBeforeUnloadGuard {
  _WebBeforeUnloadGuard()
    : _listener = ((web.Event event) {
        event.preventDefault();
        (event as web.BeforeUnloadEvent).returnValue = '';
      }).toJS;

  final JSFunction _listener;
  bool _isRegistered = false;

  @override
  void setDirty(bool isDirty) {
    if (isDirty == _isRegistered) return;
    _isRegistered = isDirty;
    if (isDirty) {
      web.window.addEventListener('beforeunload', _listener);
    } else {
      web.window.removeEventListener('beforeunload', _listener);
    }
  }

  @override
  void dispose() {
    if (_isRegistered) {
      web.window.removeEventListener('beforeunload', _listener);
      _isRegistered = false;
    }
  }
}
