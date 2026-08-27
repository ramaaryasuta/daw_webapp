import 'package:daw_webapp/features/editor/domain/audio_asset.dart';
import 'package:daw_webapp/features/editor/domain/audio_clip.dart';
import 'package:daw_webapp/features/editor/domain/clip_crossfade.dart';
import 'package:daw_webapp/features/editor/domain/daw_track.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const asset = AudioAsset(
    id: 'asset',
    name: 'audio.wav',
    extension: 'wav',
    size: 1024,
    durationSeconds: 20,
    sampleRate: 48000,
    numberOfChannels: 2,
    waveformPeaks: [0.2, 0.8],
  );

  AudioClip clip({
    required String id,
    required double start,
    required double duration,
    double fadeIn = 0,
    double fadeOut = 0,
  }) => AudioClip(
    id: id,
    audio: asset,
    timelineStartSeconds: start,
    clipDurationSeconds: duration,
    fadeInDurationSeconds: fadeIn,
    fadeOutDurationSeconds: fadeOut,
  );

  test('classic overlap orders clips and calculates the exact interval', () {
    final outgoing = clip(id: 'a', start: 1, duration: 5);
    final incoming = clip(id: 'b', start: 4, duration: 4);
    final track = DawTrack(
      id: 'track',
      name: 'Track',
      clips: [incoming, outgoing],
    );

    final pair = selectedCrossfadePair([track], {'a', 'b'});

    expect(pair, isNotNull);
    expect(pair!.outgoingClip.id, 'a');
    expect(pair.incomingClip.id, 'b');
    expect(pair.overlapStartSeconds, 4);
    expect(pair.overlapEndSeconds, 6);
    expect(pair.overlapDurationSeconds, 2);
    expect(pair.canCreate, isTrue);
    expect(pair.isCrossfade, isFalse);
  });

  test('crossfade detection uses facing fades and a small tolerance', () {
    final outgoing = clip(
      id: 'a',
      start: 1,
      duration: 5,
      fadeIn: 0.5,
      fadeOut: 2.0000004,
    );
    final incoming = clip(
      id: 'b',
      start: 4,
      duration: 4,
      fadeIn: 1.9999996,
      fadeOut: 0.75,
    );
    final track = DawTrack(
      id: 'track',
      name: 'Track',
      clips: [outgoing, incoming],
    );

    expect(isCrossfadePair(track, outgoing, incoming), isTrue);
    expect(activeCrossfadePairs(track), hasLength(1));
  });

  test('apply and remove change only facing fades', () {
    final outgoing = clip(
      id: 'a',
      start: 1,
      duration: 5,
      fadeIn: 0.5,
      fadeOut: 0.25,
    );
    final incoming = clip(
      id: 'b',
      start: 4,
      duration: 4,
      fadeIn: 0.3,
      fadeOut: 0.75,
    );
    final track = DawTrack(
      id: 'track',
      name: 'Track',
      clips: [outgoing, incoming],
    );
    final pair = selectedCrossfadePair([track], {'a', 'b'})!;

    final createdTracks = applyCrossfadeToTracks([track], pair);
    final created = {
      for (final current in createdTracks.single.clips) current.id: current,
    };
    expect(created['a']!.timelineStartSeconds, 1);
    expect(created['b']!.timelineStartSeconds, 4);
    expect(created['a']!.sourceStartSeconds, 0);
    expect(created['b']!.sourceStartSeconds, 0);
    expect(created['a']!.clipDurationSeconds, 5);
    expect(created['b']!.clipDurationSeconds, 4);
    expect(created['a']!.gainDb, defaultClipGainDb);
    expect(created['b']!.gainDb, defaultClipGainDb);
    expect(created['a']!.fadeInDurationSeconds, 0.5);
    expect(created['a']!.fadeOutDurationSeconds, 2);
    expect(created['b']!.fadeInDurationSeconds, 2);
    expect(created['b']!.fadeOutDurationSeconds, 0.75);

    final activePair = selectedCrossfadePair(createdTracks, {'a', 'b'})!;
    final removedTracks = removeCrossfadeFromTracks(createdTracks, activePair);
    final removed = {
      for (final current in removedTracks.single.clips) current.id: current,
    };
    expect(removed['a']!.fadeInDurationSeconds, 0.5);
    expect(removed['a']!.fadeOutDurationSeconds, 0);
    expect(removed['b']!.fadeInDurationSeconds, 0);
    expect(removed['b']!.fadeOutDurationSeconds, 0.75);
  });

  test('contained overlap and clips on different tracks fail safely', () {
    final outer = clip(id: 'outer', start: 0, duration: 10);
    final inner = clip(id: 'inner', start: 3, duration: 2);
    final firstTrack = DawTrack(id: 'one', name: 'One', clips: [outer, inner]);
    final secondTrack = DawTrack(
      id: 'two',
      name: 'Two',
      clips: [clip(id: 'other', start: 3, duration: 10)],
    );

    expect(selectedCrossfadePair([firstTrack], {'outer', 'inner'}), isNull);
    expect(
      selectedCrossfadePair([firstTrack, secondTrack], {'outer', 'other'}),
      isNull,
    );
  });

  test('creation is rejected when preserving an outer fade is impossible', () {
    final outgoing = clip(id: 'a', start: 0, duration: 5, fadeIn: 4);
    final incoming = clip(id: 'b', start: 3, duration: 4);
    final track = DawTrack(
      id: 'track',
      name: 'Track',
      clips: [outgoing, incoming],
    );

    expect(selectedCrossfadePair([track], {'a', 'b'})!.canCreate, isFalse);
  });

  test('drag update grows, shrinks, and releases a linked crossfade', () {
    final outgoing = clip(
      id: 'a',
      start: 1,
      duration: 5,
      fadeIn: 0.5,
      fadeOut: 2,
    );
    final incoming = clip(
      id: 'b',
      start: 4,
      duration: 4,
      fadeIn: 2,
      fadeOut: 0.75,
    );
    final track = DawTrack(
      id: 'track',
      name: 'Track',
      clips: [outgoing, incoming],
    );
    final pair = selectedCrossfadePair([track], {'a', 'b'})!;
    final snapshot = CrossfadeDragSnapshot.fromPair(pair, movingClipIds: {'b'});

    final grown = calculateCrossfadeDragUpdate(
      snapshot: snapshot,
      timelineDeltaSeconds: -1,
      trackDelta: 0,
    );
    expect(grown.isActive, isTrue);
    expect(grown.overlapStartSeconds, 3);
    expect(grown.overlapDurationSeconds, 3);

    final shrunk = calculateCrossfadeDragUpdate(
      snapshot: snapshot,
      timelineDeltaSeconds: 1.25,
      trackDelta: 0,
    );
    expect(shrunk.isActive, isTrue);
    expect(shrunk.overlapDurationSeconds, 0.75);

    final separated = calculateCrossfadeDragUpdate(
      snapshot: snapshot,
      timelineDeltaSeconds: 2,
      trackDelta: 0,
    );
    expect(separated.isActive, isFalse);
    expect(separated.overlapDurationSeconds, 0);

    final crossTrack = calculateCrossfadeDragUpdate(
      snapshot: snapshot,
      timelineDeltaSeconds: 0,
      trackDelta: 1,
    );
    expect(crossTrack.isActive, isFalse);
  });

  test('moving both linked clips preserves overlap across tracks', () {
    final outgoing = clip(id: 'a', start: 1, duration: 5, fadeOut: 2);
    final incoming = clip(id: 'b', start: 4, duration: 4, fadeIn: 2);
    final track = DawTrack(
      id: 'track',
      name: 'Track',
      clips: [outgoing, incoming],
    );
    final snapshot = CrossfadeDragSnapshot.fromPair(
      selectedCrossfadePair([track], {'a', 'b'})!,
      movingClipIds: {'a', 'b'},
    );

    final update = calculateCrossfadeDragUpdate(
      snapshot: snapshot,
      timelineDeltaSeconds: 3,
      trackDelta: 1,
    );

    expect(update.isActive, isTrue);
    expect(update.overlapStartSeconds, 7);
    expect(update.overlapDurationSeconds, 2);
  });

  test('final move updates both fades or releases them across tracks', () {
    final outgoing = clip(
      id: 'a',
      start: 1,
      duration: 5,
      fadeIn: 0.5,
      fadeOut: 2,
    );
    final incoming = clip(
      id: 'b',
      start: 4,
      duration: 4,
      fadeIn: 2,
      fadeOut: 0.75,
    );
    final track = DawTrack(
      id: 'track',
      name: 'Track',
      clips: [outgoing, incoming],
    );
    final snapshot = CrossfadeDragSnapshot.fromPair(
      selectedCrossfadePair([track], {'a', 'b'})!,
      movingClipIds: {'b'},
    );
    final movedIncoming = incoming.copyWith(timelineStartSeconds: 5.25);

    final resized = updateLinkedCrossfadesAfterMove(
      [
        track.copyWith(clips: [outgoing, movedIncoming]),
      ],
      [snapshot],
    );
    final resizedById = {
      for (final current in resized.single.clips) current.id: current,
    };
    expect(resizedById['a']!.fadeInDurationSeconds, 0.5);
    expect(resizedById['a']!.fadeOutDurationSeconds, 0.75);
    expect(resizedById['b']!.fadeInDurationSeconds, 0.75);
    expect(resizedById['b']!.fadeOutDurationSeconds, 0.75);

    final released = updateLinkedCrossfadesAfterMove(
      [
        track.copyWith(clips: [outgoing]),
        DawTrack(id: 'other', name: 'Other', clips: [movedIncoming]),
      ],
      [snapshot],
    );
    final releasedById = {
      for (final currentTrack in released)
        for (final current in currentTrack.clips) current.id: current,
    };
    expect(releasedById['a']!.fadeInDurationSeconds, 0.5);
    expect(releasedById['a']!.fadeOutDurationSeconds, 0);
    expect(releasedById['b']!.fadeInDurationSeconds, 0);
    expect(releasedById['b']!.fadeOutDurationSeconds, 0.75);
  });
}
