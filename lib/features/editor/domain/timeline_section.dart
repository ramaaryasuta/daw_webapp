class TimelineSection {
  const TimelineSection({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.name,
    required this.colorArgb,
  }) : assert(id != ''),
       assert(startTime >= 0),
       assert(endTime > startTime),
       assert(name != '');

  final String id;
  final double startTime;
  final double endTime;
  final String name;

  /// Serializable 32-bit ARGB color value.
  final int colorArgb;

  double get duration => endTime - startTime;

  TimelineSection copyWith({
    double? startTime,
    double? endTime,
    String? name,
    int? colorArgb,
  }) {
    return TimelineSection(
      id: id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      name: name ?? this.name,
      colorArgb: colorArgb ?? this.colorArgb,
    );
  }
}
