import 'browser_before_unload.dart';

BrowserBeforeUnloadGuard createPlatformBeforeUnloadGuard() =>
    const _NoopBeforeUnloadGuard();

class _NoopBeforeUnloadGuard implements BrowserBeforeUnloadGuard {
  const _NoopBeforeUnloadGuard();

  @override
  void dispose() {}

  @override
  void setDirty(bool isDirty) {}
}
