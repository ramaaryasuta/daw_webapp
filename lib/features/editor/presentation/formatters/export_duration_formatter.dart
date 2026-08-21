String formatExportDuration(double seconds) {
  if (!seconds.isFinite || seconds < 0) {
    throw ArgumentError.value(
      seconds,
      'seconds',
      'Must be finite and non-negative.',
    );
  }

  // Keep this arithmetic portable to JavaScript. Large bit-shift sentinels
  // use 32-bit bitwise semantics in the web build and can collapse to zero.
  final totalMilliseconds =
      (seconds * Duration.millisecondsPerSecond).round();
  final hours = totalMilliseconds ~/ Duration.millisecondsPerHour;
  final minutes = (totalMilliseconds ~/ Duration.millisecondsPerMinute) % 60;
  final wholeSeconds =
      (totalMilliseconds ~/ Duration.millisecondsPerSecond) % 60;
  final milliseconds = totalMilliseconds % 1000;
  final prefix = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
  final millisecondsSuffix = milliseconds == 0
      ? ''
      : '.${milliseconds.toString().padLeft(3, '0')}';

  return '$prefix${minutes.toString().padLeft(2, '0')}:'
      '${wholeSeconds.toString().padLeft(2, '0')}'
      '$millisecondsSuffix';
}
