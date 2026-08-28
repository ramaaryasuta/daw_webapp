import 'package:daw_webapp/features/editor/domain/track_filter_fx.dart';
import 'package:daw_webapp/features/editor/infrastructure/project_io/project_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> baseTrackJson() => {
    'id': 'track-1',
    'order': 0,
    'name': 'Vocals',
    'colorArgb': 0xff6750a4,
    'volumeDb': -3,
    'mute': false,
    'solo': false,
    'pan': 0.25,
  };

  test('older track metadata defaults Filter FX to bypassed', () {
    final track = ProjectTrackDto.fromJson(baseTrackJson());

    expect(track.filterFx, const TrackFilterFx());
    expect(track.filterFx.isProcessing, isFalse);
  });

  test('Filter FX metadata round-trips all authoritative values', () {
    final original = ProjectTrackDto(
      id: 'track-1',
      order: 0,
      name: 'Vocals',
      colorArgb: 0xff6750a4,
      volumeDb: -3,
      muted: false,
      solo: false,
      pan: 0.25,
      filterFx: const TrackFilterFx(
        enabled: true,
        highPass: TrackFilterModule(enabled: true, frequencyHz: 120, q: 1.2),
        lowPass: TrackFilterModule(enabled: true, frequencyHz: 14200, q: 2.4),
      ),
    );

    final restored = ProjectTrackDto.fromJson(original.toJson());

    expect(restored.filterFx, original.filterFx);
  });
}
