/// Stable, serializable opaque ARGB values used by track presets.
abstract final class TrackColors {
  static const int purple = 0xFF8468C8;
  static const int blue = 0xFF527AC2;
  static const int cyan = 0xFF438DA8;
  static const int green = 0xFF4D9368;
  static const int lime = 0xFF7F994E;
  static const int yellow = 0xFFB8913F;
  static const int orange = 0xFFC27442;
  static const int red = 0xFFB65C5C;
  static const int pink = 0xFFB96086;
  static const int teal = 0xFF3F8F87;
}

const List<int> defaultTrackColorRotation = [
  TrackColors.purple,
  TrackColors.blue,
  TrackColors.cyan,
  TrackColors.green,
  TrackColors.lime,
  TrackColors.yellow,
  TrackColors.orange,
  TrackColors.red,
  TrackColors.pink,
  TrackColors.teal,
];

int opaqueTrackColor(int colorValue) {
  return 0xFF000000 | (colorValue & 0x00FFFFFF);
}

int defaultTrackColorForIndex(int index) {
  final normalizedIndex = index < 0 ? 0 : index;
  return defaultTrackColorRotation[normalizedIndex %
      defaultTrackColorRotation.length];
}
