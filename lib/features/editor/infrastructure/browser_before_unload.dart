import 'browser_before_unload_stub.dart'
    if (dart.library.js_interop) 'browser_before_unload_web.dart';

abstract class BrowserBeforeUnloadGuard {
  void setDirty(bool isDirty);

  void dispose();
}

BrowserBeforeUnloadGuard createBrowserBeforeUnloadGuard() =>
    createPlatformBeforeUnloadGuard();
