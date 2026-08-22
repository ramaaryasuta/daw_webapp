import 'dart:math' as math;

import 'daw_track.dart';

/// Track-fader range used by project state, playback, export, and the UI.
const double minimumTrackVolumeDb = -60;
const double maximumTrackVolumeDb = 6;
const double unityTrackVolumeDb = 0;

double clampTrackVolumeDb(double volumeDb) {
  return volumeDb.clamp(minimumTrackVolumeDb, maximumTrackVolumeDb).toDouble();
}

/// Converts a decibel fader value to the linear amplitude used by Web Audio.
double dbToLinearGain(double volumeDb) {
  return math.pow(10, clampTrackVolumeDb(volumeDb) / 20).toDouble();
}

/// Mute wins over Solo. When any track is soloed, every non-solo track is
/// silent; multiple soloed tracks remain audible together.
double effectiveTrackGain(DawTrack track, {required bool hasSolo}) {
  final isAudible = !track.isMuted && (!hasSolo || track.isSolo);
  return isAudible ? dbToLinearGain(track.volumeDb) : 0;
}

String formatTrackVolumeDb(double volumeDb) {
  final value = clampTrackVolumeDb(volumeDb);
  final prefix = value > 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)} dB';
}
