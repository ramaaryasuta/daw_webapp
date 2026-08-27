import 'package:daw_webapp/features/editor/presentation/controllers/track_reorder_drag_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('previews a stable-ID order without changing the original list', () {
    const original = ['track-a', 'track-b', 'track-c'];
    final controller = TrackReorderDragController();
    addTearDown(controller.dispose);

    controller.start(trackId: 'track-c', trackIds: original);
    controller.updateDestinationIndex(0);

    expect(controller.value!.originalTrackIds, original);
    expect(controller.value!.previewTrackIds, [
      'track-c',
      'track-a',
      'track-b',
    ]);
    expect(original, ['track-a', 'track-b', 'track-c']);
    expect(controller.finish(), ['track-c', 'track-a', 'track-b']);
    expect(controller.value, isNull);
  });

  test('clamps drops below the real track list to its final position', () {
    final controller = TrackReorderDragController();
    addTearDown(controller.dispose);

    controller.start(
      trackId: 'track-a',
      trackIds: const ['track-a', 'track-b', 'track-c'],
    );
    controller.updateDestinationIndex(99);

    expect(controller.finish(), ['track-b', 'track-c', 'track-a']);
  });
}
