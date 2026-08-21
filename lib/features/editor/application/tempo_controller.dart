import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infrastructure/web_audio_engine.dart';

class TempoState {
  const TempoState({
    this.bpm = defaultBpm,
    this.metronomeEnabled = false,
  });

  static const double defaultBpm = 120;
  static const double minimumBpm = 20;
  static const double maximumBpm = 300;

  final double bpm;
  final bool metronomeEnabled;

  TempoState copyWith({double? bpm, bool? metronomeEnabled}) {
    return TempoState(
      bpm: bpm ?? this.bpm,
      metronomeEnabled: metronomeEnabled ?? this.metronomeEnabled,
    );
  }
}

class TempoController extends Notifier<TempoState> {
  WebAudioEngine get _audioEngine => ref.read(webAudioEngineProvider);

  @override
  TempoState build() => const TempoState();

  void setBpm(double bpm) {
    if (!bpm.isFinite) {
      return;
    }

    final clamped = bpm
        .clamp(TempoState.minimumBpm, TempoState.maximumBpm)
        .toDouble();

    if (clamped == state.bpm) {
      return;
    }

    state = state.copyWith(bpm: clamped);
    _audioEngine.setTempoBpm(clamped);
  }

  void setMetronomeEnabled(bool enabled) {
    if (enabled == state.metronomeEnabled) {
      return;
    }

    state = state.copyWith(metronomeEnabled: enabled);
    _audioEngine.setMetronomeEnabled(enabled);
  }

  void toggleMetronome() {
    setMetronomeEnabled(!state.metronomeEnabled);
  }
}

final tempoControllerProvider =
    NotifierProvider<TempoController, TempoState>(TempoController.new);
