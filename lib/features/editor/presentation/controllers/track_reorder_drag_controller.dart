import 'package:flutter/foundation.dart';

class TrackReorderDragState {
  const TrackReorderDragState({
    required this.draggedTrackId,
    required this.originalTrackIds,
    required this.destinationIndex,
  });

  final String draggedTrackId;
  final List<String> originalTrackIds;

  /// Index occupied by the dragged track in the preview order.
  final int destinationIndex;

  List<String> get previewTrackIds {
    final reordered = originalTrackIds
        .where((trackId) => trackId != draggedTrackId)
        .toList();
    reordered.insert(
      destinationIndex.clamp(0, reordered.length),
      draggedTrackId,
    );
    return List<String>.unmodifiable(reordered);
  }

  TrackReorderDragState copyWith({int? destinationIndex}) {
    return TrackReorderDragState(
      draggedTrackId: draggedTrackId,
      originalTrackIds: originalTrackIds,
      destinationIndex: destinationIndex ?? this.destinationIndex,
    );
  }
}

/// Ephemeral UI-only state. Project order changes only when the drag commits.
class TrackReorderDragController extends ValueNotifier<TrackReorderDragState?> {
  TrackReorderDragController() : super(null);

  void start({required String trackId, required Iterable<String> trackIds}) {
    final originalTrackIds = List<String>.unmodifiable(trackIds);
    final originalIndex = originalTrackIds.indexOf(trackId);
    if (originalIndex < 0) {
      return;
    }
    value = TrackReorderDragState(
      draggedTrackId: trackId,
      originalTrackIds: originalTrackIds,
      destinationIndex: originalIndex,
    );
  }

  void updateDestinationIndex(int destinationIndex) {
    final current = value;
    if (current == null || current.originalTrackIds.isEmpty) {
      return;
    }
    final clamped = destinationIndex.clamp(
      0,
      current.originalTrackIds.length - 1,
    );
    if (clamped != current.destinationIndex) {
      value = current.copyWith(destinationIndex: clamped);
    }
  }

  List<String>? finish() {
    final current = value;
    value = null;
    return current?.previewTrackIds;
  }

  void cancel() => value = null;
}
