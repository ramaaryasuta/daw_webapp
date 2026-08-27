class TimelineMarker {
  const TimelineMarker({
    required this.id,
    required this.timeSeconds,
    required this.name,
    required this.colorArgb,
  }) : assert(id != ''),
       assert(timeSeconds >= 0),
       assert(name != '');

  final String id;
  final double timeSeconds;
  final String name;

  /// Serializable 32-bit ARGB color value.
  final int colorArgb;

  TimelineMarker copyWith({double? timeSeconds, String? name, int? colorArgb}) {
    return TimelineMarker(
      id: id,
      timeSeconds: timeSeconds ?? this.timeSeconds,
      name: name ?? this.name,
      colorArgb: colorArgb ?? this.colorArgb,
    );
  }
}
