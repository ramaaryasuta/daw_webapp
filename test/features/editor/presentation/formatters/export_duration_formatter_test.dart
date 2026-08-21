import 'package:daw_webapp/features/editor/presentation/formatters/export_duration_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats sub-second precision', () {
    expect(formatExportDuration(0.5), '00:00.500');
  });

  test('omits milliseconds for whole seconds', () {
    expect(formatExportDuration(5), '00:05');
  });

  test('formats minutes with fractional seconds', () {
    expect(formatExportDuration(65.25), '01:05.250');
  });

  test('does not reinterpret seconds as milliseconds', () {
    expect(formatExportDuration(42.3), '00:42.300');
  });

  test('does not silently format invalid duration as zero', () {
    expect(() => formatExportDuration(double.nan), throwsArgumentError);
    expect(() => formatExportDuration(double.infinity), throwsArgumentError);
    expect(() => formatExportDuration(-1), throwsArgumentError);
  });
}
