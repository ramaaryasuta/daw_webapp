import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:daw_webapp/features/editor/domain/track_mixer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('track pan defaults to center and clamps to the stereo range', () {
    const centered = DawTrack(id: 'center', name: 'Center', clips: []);
    const tooFarLeft = DawTrack(id: 'left', name: 'Left', clips: [], pan: -2);
    const tooFarRight = DawTrack(id: 'right', name: 'Right', clips: [], pan: 2);
    const invalid = DawTrack(
      id: 'invalid',
      name: 'Invalid',
      clips: [],
      pan: double.nan,
    );

    expect(centered.pan, centerTrackPan);
    expect(tooFarLeft.pan, minimumTrackPan);
    expect(tooFarRight.pan, maximumTrackPan);
    expect(invalid.pan, centerTrackPan);
    expect(centered.copyWith(pan: 4).pan, maximumTrackPan);
  });

  test('formats compact and accessible pan values', () {
    expect(formatTrackPan(0), 'C');
    expect(formatTrackPan(-0.42), 'L 42');
    expect(formatTrackPan(0.75), 'R 75');
    expect(formatTrackPanSemantics(-0.5), '50 percent left');
    expect(formatTrackPanSemantics(0), 'center');
  });
}
