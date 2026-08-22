import 'package:flutter/material.dart';

import '../domain/track_color.dart';

class TrackColorPreset {
  const TrackColorPreset(this.label, this.colorValue);

  final String label;
  final int colorValue;

  Color get color => Color(colorValue);
}

const List<TrackColorPreset> trackColorPresets = [
  TrackColorPreset('Purple', TrackColors.purple),
  TrackColorPreset('Blue', TrackColors.blue),
  TrackColorPreset('Cyan', TrackColors.cyan),
  TrackColorPreset('Green', TrackColors.green),
  TrackColorPreset('Lime', TrackColors.lime),
  TrackColorPreset('Yellow', TrackColors.yellow),
  TrackColorPreset('Orange', TrackColors.orange),
  TrackColorPreset('Red', TrackColors.red),
  TrackColorPreset('Pink', TrackColors.pink),
  TrackColorPreset('Teal', TrackColors.teal),
];

String trackColorHex(int colorValue) {
  return '#${(colorValue & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

int? parseTrackColorHex(String input) {
  final normalized = input.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(normalized)) {
    return null;
  }
  return 0xFF000000 | int.parse(normalized, radix: 16);
}
