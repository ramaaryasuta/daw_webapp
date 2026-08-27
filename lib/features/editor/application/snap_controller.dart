import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/snap_settings.dart';

class SnapController extends Notifier<SnapSettings> {
  @override
  SnapSettings build() => const SnapSettings();

  void setEnabled(bool enabled) {
    if (enabled == state.enabled) {
      return;
    }
    state = state.copyWith(enabled: enabled);
  }

  void toggleEnabled() {
    setEnabled(!state.enabled);
  }

  void setSubdivision(SnapSubdivision subdivision) {
    if (subdivision == state.subdivision) {
      return;
    }
    state = state.copyWith(subdivision: subdivision);
  }

  void replaceSettings(SnapSettings settings) {
    state = settings;
  }
}

final snapControllerProvider = NotifierProvider<SnapController, SnapSettings>(
  SnapController.new,
);
