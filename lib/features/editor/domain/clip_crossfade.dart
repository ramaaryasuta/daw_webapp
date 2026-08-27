import 'audio_clip.dart';
import 'daw_track.dart';

const double crossfadeComparisonToleranceSeconds = 0.000001;

/// The classic partial-overlap geometry supported by the edge-based fade model.
///
/// [outgoingClip] starts first and ends inside [incomingClip]. No project object
/// is stored for a crossfade; this value is derived from current clip geometry.
class ClipCrossfadePair {
  const ClipCrossfadePair({
    required this.trackId,
    required this.outgoingClip,
    required this.incomingClip,
    required this.overlapStartSeconds,
    required this.overlapEndSeconds,
  });

  final String trackId;
  final AudioClip outgoingClip;
  final AudioClip incomingClip;
  final double overlapStartSeconds;
  final double overlapEndSeconds;

  double get overlapDurationSeconds => overlapEndSeconds - overlapStartSeconds;

  /// Whether the overlap can replace the two facing fades without changing
  /// either outer fade or violating the clip fade-duration invariant.
  bool get canCreate {
    return outgoingClip.fadeInDurationSeconds + overlapDurationSeconds <=
            outgoingClip.clipDurationSeconds &&
        incomingClip.fadeOutDurationSeconds + overlapDurationSeconds <=
            incomingClip.clipDurationSeconds;
  }

  bool get isCrossfade =>
      _approximatelyEqual(
        outgoingClip.fadeOutDurationSeconds,
        overlapDurationSeconds,
      ) &&
      _approximatelyEqual(
        incomingClip.fadeInDurationSeconds,
        overlapDurationSeconds,
      );
}

/// Temporary interaction-only record of a crossfade recognized at drag start.
///
/// It is carried by the timeline drag preview and is never stored in editor
/// state, project history, or serialization.
class CrossfadeDragSnapshot {
  const CrossfadeDragSnapshot({
    required this.trackId,
    required this.outgoingClipId,
    required this.incomingClipId,
    required this.outgoingTimelineStartSeconds,
    required this.incomingTimelineStartSeconds,
    required this.outgoingClipDurationSeconds,
    required this.incomingClipDurationSeconds,
    required this.outgoingFadeInDurationSeconds,
    required this.incomingFadeOutDurationSeconds,
    required this.originalOutgoingFadeOutDurationSeconds,
    required this.originalIncomingFadeInDurationSeconds,
    required this.outgoingMoves,
    required this.incomingMoves,
  });

  factory CrossfadeDragSnapshot.fromPair(
    ClipCrossfadePair pair, {
    required Set<String> movingClipIds,
  }) {
    return CrossfadeDragSnapshot(
      trackId: pair.trackId,
      outgoingClipId: pair.outgoingClip.id,
      incomingClipId: pair.incomingClip.id,
      outgoingTimelineStartSeconds: pair.outgoingClip.timelineStartSeconds,
      incomingTimelineStartSeconds: pair.incomingClip.timelineStartSeconds,
      outgoingClipDurationSeconds: pair.outgoingClip.clipDurationSeconds,
      incomingClipDurationSeconds: pair.incomingClip.clipDurationSeconds,
      outgoingFadeInDurationSeconds: pair.outgoingClip.fadeInDurationSeconds,
      incomingFadeOutDurationSeconds: pair.incomingClip.fadeOutDurationSeconds,
      originalOutgoingFadeOutDurationSeconds:
          pair.outgoingClip.fadeOutDurationSeconds,
      originalIncomingFadeInDurationSeconds:
          pair.incomingClip.fadeInDurationSeconds,
      outgoingMoves: movingClipIds.contains(pair.outgoingClip.id),
      incomingMoves: movingClipIds.contains(pair.incomingClip.id),
    );
  }

  final String trackId;
  final String outgoingClipId;
  final String incomingClipId;
  final double outgoingTimelineStartSeconds;
  final double incomingTimelineStartSeconds;
  final double outgoingClipDurationSeconds;
  final double incomingClipDurationSeconds;
  final double outgoingFadeInDurationSeconds;
  final double incomingFadeOutDurationSeconds;
  final double originalOutgoingFadeOutDurationSeconds;
  final double originalIncomingFadeInDurationSeconds;
  final bool outgoingMoves;
  final bool incomingMoves;

  bool containsClip(String clipId) =>
      outgoingClipId == clipId || incomingClipId == clipId;
}

class CrossfadeDragUpdate {
  const CrossfadeDragUpdate({
    required this.snapshot,
    required this.outgoingTimelineStartSeconds,
    required this.incomingTimelineStartSeconds,
    required this.overlapStartSeconds,
    required this.overlapDurationSeconds,
    required this.isActive,
  });

  final CrossfadeDragSnapshot snapshot;
  final double outgoingTimelineStartSeconds;
  final double incomingTimelineStartSeconds;
  final double overlapStartSeconds;
  final double overlapDurationSeconds;
  final bool isActive;
}

/// Calculates the lightweight linked-fade preview for one drag update.
CrossfadeDragUpdate calculateCrossfadeDragUpdate({
  required CrossfadeDragSnapshot snapshot,
  required double timelineDeltaSeconds,
  required int trackDelta,
}) {
  final outgoingStart =
      snapshot.outgoingTimelineStartSeconds +
      (snapshot.outgoingMoves ? timelineDeltaSeconds : 0);
  final incomingStart =
      snapshot.incomingTimelineStartSeconds +
      (snapshot.incomingMoves ? timelineDeltaSeconds : 0);
  final outgoingEnd = outgoingStart + snapshot.outgoingClipDurationSeconds;
  final incomingEnd = incomingStart + snapshot.incomingClipDurationSeconds;
  final remainsOnSameTrack =
      snapshot.outgoingMoves == snapshot.incomingMoves || trackDelta == 0;
  final hasClassicGeometry =
      outgoingStart < incomingStart &&
      incomingStart < outgoingEnd &&
      outgoingEnd < incomingEnd;
  final overlapDuration = hasClassicGeometry
      ? outgoingEnd - incomingStart
      : 0.0;
  final fitsOuterFades =
      snapshot.outgoingFadeInDurationSeconds + overlapDuration <=
          snapshot.outgoingClipDurationSeconds &&
      snapshot.incomingFadeOutDurationSeconds + overlapDuration <=
          snapshot.incomingClipDurationSeconds;
  final isActive =
      remainsOnSameTrack &&
      hasClassicGeometry &&
      overlapDuration > 0 &&
      fitsOuterFades;

  return CrossfadeDragUpdate(
    snapshot: snapshot,
    outgoingTimelineStartSeconds: outgoingStart,
    incomingTimelineStartSeconds: incomingStart,
    overlapStartSeconds: isActive ? incomingStart : 0,
    overlapDurationSeconds: isActive ? overlapDuration : 0,
    isActive: isActive,
  );
}

/// Returns a classic partial overlap for two clips known to be on [track].
///
/// Equal starts/ends, touching clips, and contained overlaps are deliberately
/// rejected because they cannot be represented by one fade edge on each clip.
ClipCrossfadePair? classicCrossfadePair(
  DawTrack track,
  AudioClip first,
  AudioClip second,
) {
  if (!track.clips.any((clip) => clip.id == first.id) ||
      !track.clips.any((clip) => clip.id == second.id) ||
      first.id == second.id) {
    return null;
  }

  final outgoing = first.timelineStartSeconds < second.timelineStartSeconds
      ? first
      : second;
  final incoming = identical(outgoing, first) ? second : first;
  if (!(outgoing.timelineStartSeconds < incoming.timelineStartSeconds &&
      incoming.timelineStartSeconds < outgoing.timelineEndSeconds &&
      outgoing.timelineEndSeconds < incoming.timelineEndSeconds)) {
    return null;
  }

  return ClipCrossfadePair(
    trackId: track.id,
    outgoingClip: outgoing,
    incomingClip: incoming,
    overlapStartSeconds: incoming.timelineStartSeconds,
    overlapEndSeconds: outgoing.timelineEndSeconds,
  );
}

/// Finds the one V1 crossfade candidate represented by exactly two clip IDs.
ClipCrossfadePair? selectedCrossfadePair(
  List<DawTrack> tracks,
  Set<String> selectedClipIds,
) {
  if (selectedClipIds.length != 2) {
    return null;
  }

  for (final track in tracks) {
    final selected = track.clips
        .where((clip) => selectedClipIds.contains(clip.id))
        .toList();
    if (selected.length == 2) {
      return classicCrossfadePair(track, selected[0], selected[1]);
    }
  }
  return null;
}

/// Derives all currently active crossfades on one track.
List<ClipCrossfadePair> activeCrossfadePairs(DawTrack track) {
  final pairs = <ClipCrossfadePair>[];
  for (var firstIndex = 0; firstIndex < track.clips.length; firstIndex++) {
    for (
      var secondIndex = firstIndex + 1;
      secondIndex < track.clips.length;
      secondIndex++
    ) {
      final pair = classicCrossfadePair(
        track,
        track.clips[firstIndex],
        track.clips[secondIndex],
      );
      if (pair?.isCrossfade ?? false) {
        pairs.add(pair!);
      }
    }
  }
  return pairs;
}

/// Applies the two facing fades while preserving all clip geometry and outer
/// fade values. Callers remain responsible for recording one history entry.
List<DawTrack> applyCrossfadeToTracks(
  List<DawTrack> tracks,
  ClipCrossfadePair pair,
) {
  if (!pair.canCreate) {
    return tracks;
  }
  final overlapDuration = pair.overlapDurationSeconds;
  return [
    for (final track in tracks)
      if (track.id == pair.trackId)
        track.copyWith(
          clips: [
            for (final clip in track.clips)
              if (clip.id == pair.outgoingClip.id)
                clip.copyWith(fadeOutDurationSeconds: overlapDuration)
              else if (clip.id == pair.incomingClip.id)
                clip.copyWith(fadeInDurationSeconds: overlapDuration)
              else
                clip,
          ],
        )
      else
        track,
  ];
}

/// Clears only the two crossfade-facing edges of an active pair.
List<DawTrack> removeCrossfadeFromTracks(
  List<DawTrack> tracks,
  ClipCrossfadePair pair,
) {
  if (!pair.isCrossfade) {
    return tracks;
  }
  return [
    for (final track in tracks)
      if (track.id == pair.trackId)
        track.copyWith(
          clips: [
            for (final clip in track.clips)
              if (clip.id == pair.outgoingClip.id)
                clip.copyWith(fadeOutDurationSeconds: 0)
              else if (clip.id == pair.incomingClip.id)
                clip.copyWith(fadeInDurationSeconds: 0)
              else
                clip,
          ],
        )
      else
        track,
  ];
}

/// Applies drag-linked fades to the final moved arrangement.
///
/// Both members moving together keep their existing fades. If just one member
/// moves, the pair is resized only while it remains on one track with the
/// supported classic geometry; otherwise its two facing fades are released.
List<DawTrack> updateLinkedCrossfadesAfterMove(
  List<DawTrack> tracks,
  List<CrossfadeDragSnapshot> snapshots,
) {
  var updatedTracks = tracks;
  for (final snapshot in snapshots) {
    if (snapshot.outgoingMoves && snapshot.incomingMoves) {
      continue;
    }

    ({DawTrack track, AudioClip clip})? outgoingLocation;
    ({DawTrack track, AudioClip clip})? incomingLocation;
    for (final track in updatedTracks) {
      for (final clip in track.clips) {
        if (clip.id == snapshot.outgoingClipId) {
          outgoingLocation = (track: track, clip: clip);
        } else if (clip.id == snapshot.incomingClipId) {
          incomingLocation = (track: track, clip: clip);
        }
      }
    }
    if (outgoingLocation == null || incomingLocation == null) {
      continue;
    }

    final onSameTrack = outgoingLocation.track.id == incomingLocation.track.id;
    final outgoing = outgoingLocation.clip;
    final incoming = incomingLocation.clip;
    final hasClassicGeometry =
        outgoing.timelineStartSeconds < incoming.timelineStartSeconds &&
        incoming.timelineStartSeconds < outgoing.timelineEndSeconds &&
        outgoing.timelineEndSeconds < incoming.timelineEndSeconds;
    final overlapDuration = hasClassicGeometry
        ? outgoing.timelineEndSeconds - incoming.timelineStartSeconds
        : 0.0;
    final fitsOuterFades =
        outgoing.fadeInDurationSeconds + overlapDuration <=
            outgoing.clipDurationSeconds &&
        incoming.fadeOutDurationSeconds + overlapDuration <=
            incoming.clipDurationSeconds;
    final keepLinked =
        onSameTrack &&
        hasClassicGeometry &&
        overlapDuration > 0 &&
        fitsOuterFades;

    updatedTracks = [
      for (final track in updatedTracks)
        track.copyWith(
          clips: [
            for (final clip in track.clips)
              if (clip.id == snapshot.outgoingClipId)
                clip.copyWith(
                  fadeOutDurationSeconds: keepLinked ? overlapDuration : 0,
                )
              else if (clip.id == snapshot.incomingClipId)
                clip.copyWith(
                  fadeInDurationSeconds: keepLinked ? overlapDuration : 0,
                )
              else
                clip,
          ],
        ),
    ];
  }
  return updatedTracks;
}

bool isCrossfadePair(
  DawTrack track,
  AudioClip first,
  AudioClip second, {
  double toleranceSeconds = crossfadeComparisonToleranceSeconds,
}) {
  final pair = classicCrossfadePair(track, first, second);
  if (pair == null) {
    return false;
  }
  return _approximatelyEqual(
        pair.outgoingClip.fadeOutDurationSeconds,
        pair.overlapDurationSeconds,
        toleranceSeconds: toleranceSeconds,
      ) &&
      _approximatelyEqual(
        pair.incomingClip.fadeInDurationSeconds,
        pair.overlapDurationSeconds,
        toleranceSeconds: toleranceSeconds,
      );
}

bool _approximatelyEqual(
  double left,
  double right, {
  double toleranceSeconds = crossfadeComparisonToleranceSeconds,
}) => (left - right).abs() <= toleranceSeconds;
