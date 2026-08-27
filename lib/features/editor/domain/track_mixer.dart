import 'dart:math' as math;

import 'daw_track.dart';

/// Track-fader range used by project state, playback, export, and the UI.
const double minimumTrackVolumeDb = -60;
const double maximumTrackVolumeDb = 6;
const double unityTrackVolumeDb = 0;
const double minimumMasterVolumeDb = -60;
const double maximumMasterVolumeDb = 6;
const double unityMasterVolumeDb = 0;
const double minimumTrackPan = -1;
const double maximumTrackPan = 1;
const double centerTrackPan = 0;

double clampTrackVolumeDb(double volumeDb) {
  return volumeDb.clamp(minimumTrackVolumeDb, maximumTrackVolumeDb).toDouble();
}

double clampMasterVolumeDb(double volumeDb) {
  if (volumeDb.isNaN) {
    return unityMasterVolumeDb;
  }
  return volumeDb
      .clamp(minimumMasterVolumeDb, maximumMasterVolumeDb)
      .toDouble();
}

double clampTrackPan(double pan) {
  if (pan.isNaN) {
    return centerTrackPan;
  }
  return pan.clamp(minimumTrackPan, maximumTrackPan).toDouble();
}

/// Converts a decibel fader value to the linear amplitude used by Web Audio.
double dbToLinearGain(double volumeDb) {
  return math.pow(10, clampTrackVolumeDb(volumeDb) / 20).toDouble();
}

double masterDbToLinearGain(double volumeDb) {
  return math.pow(10, clampMasterVolumeDb(volumeDb) / 20).toDouble();
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

String formatMasterVolumeDb(double volumeDb) {
  final value = clampMasterVolumeDb(volumeDb);
  if (value <= minimumMasterVolumeDb) {
    return '-∞ dB';
  }
  final prefix = value > 0 ? '+' : '';
  return '$prefix${value.toStringAsFixed(1)} dB';
}

String formatTrackPan(double pan) {
  final value = clampTrackPan(pan);
  final percent = (value.abs() * 100).round();
  if (percent == 0) {
    return 'C';
  }
  return '${value < 0 ? 'L' : 'R'} $percent';
}

String formatTrackPanSemantics(double pan) {
  final value = clampTrackPan(pan);
  final percent = (value.abs() * 100).round();
  if (percent == 0) {
    return 'center';
  }
  return '$percent percent ${value < 0 ? 'left' : 'right'}';
}
