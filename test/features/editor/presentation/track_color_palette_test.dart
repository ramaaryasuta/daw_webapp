import 'package:daw_webapp/features/editor/presentation/track_color_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hex helpers normalize valid RGB and reject invalid input', () {
    expect(parseTrackColorHex('#7c5cff'), 0xFF7C5CFF);
    expect(parseTrackColorHex('123456'), 0xFF123456);
    expect(trackColorHex(0x7FABCDEF), '#ABCDEF');
    expect(parseTrackColorHex('#12345'), isNull);
    expect(parseTrackColorHex('#GGGGGG'), isNull);
  });
}
