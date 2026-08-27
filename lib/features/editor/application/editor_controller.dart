import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_asset.dart';
import '../domain/audio_clip.dart';
import '../domain/daw_track.dart';
import '../domain/imported_audio_file.dart';
import '../domain/loop_region.dart';
import '../domain/musical_timing.dart';
import '../domain/timeline_scale.dart';
import '../domain/track_color.dart';
import '../domain/track_mixer.dart';
import '../domain/timeline_snapper.dart';
import '../infrastructure/web_audio_engine.dart';
import 'editor_clipboard.dart';
import 'editor_history.dart';
import 'snap_controller.dart';
import 'tempo_controller.dart';

class EditorState {
  EditorState({
    this.isPlaying = false,
    this.isImporting = false,
    this.playheadSeconds = 0,
    this.pixelsPerSecond = TimelineScale.defaultPixelsPerSecond,
    this.isLoopEnabled = false,
    this.loopRegion,
    this.tracks = const [],
    this.selectedTrackId,
    Set<String> selectedClipIds = const {},
    String? selectedClipId,
    EditorClipClipboard? clipClipboard,
    EditorHistory? history,
  }) : selectedClipIds = _immutableClipSelection(
         selectedClipIds,
         selectedClipId,
       ),
       clipClipboard = clipClipboard ?? EditorClipClipboard.empty,
       history = history ?? EditorHistory();

  final bool isPlaying;
  final bool isImporting;

  final double playheadSeconds;
  final double pixelsPerSecond;
  final bool isLoopEnabled;
  final LoopRegion? loopRegion;

  final List<DawTrack> tracks;
  final String? selectedTrackId;
  final Set<String> selectedClipIds;
  final EditorClipClipboard clipClipboard;
  final EditorHistory history;

  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;

  double get projectDurationSeconds {
    return calculateProjectDurationSeconds(tracks);
  }

  double get timelineDurationSeconds {
    return math.max(projectDurationSeconds, loopRegion?.endSeconds ?? 0);
  }

  String? get selectedClipId =>
      selectedClipIds.length == 1 ? selectedClipIds.single : null;

  AudioClip? get selectedClip {
    final clipId = selectedClipId;
    if (clipId == null) {
      return null;
    }

    for (final track in tracks) {
      for (final clip in track.clips) {
        if (clip.id == clipId) {
          return clip;
        }
      }
    }
    return null;
  }

  bool get canSplitSelectedClip {
    final clip = selectedClip;
    return clip != null && canSplitAudioClip(clip, playheadSeconds);
  }

  bool get canDeleteSelectedClip => selectedClipIds.isNotEmpty;
  bool get canCopySelectedClip => selectedClipIds.isNotEmpty;
  bool get canDuplicateSelectedClip => selectedClipIds.isNotEmpty;
  bool get canPasteClip {
    if (clipClipboard.isEmpty) {
      return false;
    }
    final trackIds = tracks.map((track) => track.id).toSet();
    return clipClipboard.clips.every(
      (copied) => trackIds.contains(copied.originalTrackId),
    );
  }

  EditorState copyWith({
    bool? isPlaying,
    bool? isImporting,
    double? playheadSeconds,
    double? pixelsPerSecond,
    bool? isLoopEnabled,
    LoopRegion? loopRegion,
    List<DawTrack>? tracks,
    String? selectedTrackId,
    Set<String>? selectedClipIds,
    String? selectedClipId,
    bool clearSelectedTrack = false,
    bool clearSelectedClip = false,
    EditorClipClipboard? clipClipboard,
    EditorHistory? history,
  }) {
    return EditorState(
      isPlaying: isPlaying ?? this.isPlaying,
      isImporting: isImporting ?? this.isImporting,
      playheadSeconds: playheadSeconds ?? this.playheadSeconds,
      pixelsPerSecond: pixelsPerSecond ?? this.pixelsPerSecond,
      isLoopEnabled: isLoopEnabled ?? this.isLoopEnabled,
      loopRegion: loopRegion ?? this.loopRegion,
      tracks: tracks ?? this.tracks,
      selectedTrackId: clearSelectedTrack
          ? null
          : selectedTrackId ?? this.selectedTrackId,
      selectedClipIds: clearSelectedClip
          ? const {}
          : selectedClipIds ??
                (selectedClipId != null
                    ? {selectedClipId}
                    : this.selectedClipIds),
      clipClipboard: clipClipboard ?? this.clipClipboard,
      history: history ?? this.history,
    );
  }
}

Set<String> _immutableClipSelection(
  Set<String> selectedClipIds,
  String? selectedClipId,
) {
  if (selectedClipIds.isEmpty) {
    return selectedClipId == null
        ? const {}
        : UnmodifiableSetView({selectedClipId});
  }
  return selectedClipIds is UnmodifiableSetView<String>
      ? selectedClipIds
      : UnmodifiableSetView({...selectedClipIds});
}

class EditorController extends Notifier<EditorState> {
  int _trackCounter = 0;
  int _assetCounter = 0;
  int _clipCounter = 0;
  int _clipEditRequestId = 0;

  ProjectSnapshot? _tempoEditStartSnapshot;
  ProjectSnapshot? _volumeEditStartSnapshot;
  String? _volumeEditTrackId;
  ProjectSnapshot? _panEditStartSnapshot;
  String? _panEditTrackId;
  ProjectSnapshot? _trackColorEditStartSnapshot;
  String? _trackColorEditTrackId;
  int? _trackColorEditOriginalValue;
  ProjectSnapshot? _clipFadeEditStartSnapshot;
  String? _clipFadeEditClipId;
  _ClipFadeEdge? _clipFadeEditEdge;
  ProjectSnapshot? _clipGainEditStartSnapshot;
  String? _clipGainEditClipId;

  Timer? _playheadTimer;

  WebAudioEngine get _audioEngine => ref.read(webAudioEngineProvider);

  @override
  EditorState build() {
    ref.onDispose(() {
      _playheadTimer?.cancel();
    });

    return EditorState();
  }

  ProjectSnapshot _captureProjectSnapshot() {
    return ProjectSnapshot(
      tracks: state.tracks,
      bpm: ref.read(tempoControllerProvider).bpm,
      selectedTrackId: state.selectedTrackId,
      selectedClipIds: state.selectedClipIds,
    );
  }

  void _recordEdit(String label, ProjectSnapshot before) {
    final history = state.history.record(
      label: label,
      before: before,
      after: _captureProjectSnapshot(),
    );
    if (!identical(history, state.history)) {
      state = state.copyWith(history: history);
    }
  }

  void _clearPendingEditTransactions() {
    _tempoEditStartSnapshot = null;
    _volumeEditStartSnapshot = null;
    _volumeEditTrackId = null;
    _panEditStartSnapshot = null;
    _panEditTrackId = null;
    _trackColorEditStartSnapshot = null;
    _trackColorEditTrackId = null;
    _trackColorEditOriginalValue = null;
    _clipFadeEditStartSnapshot = null;
    _clipFadeEditClipId = null;
    _clipFadeEditEdge = null;
    _clipGainEditStartSnapshot = null;
    _clipGainEditClipId = null;
  }

  Future<void> undo() async {
    if (state.isImporting) {
      return;
    }

    final transition = state.history.undo(_captureProjectSnapshot());
    if (transition == null) {
      return;
    }

    _clearPendingEditTransactions();
    await _restoreProjectSnapshot(transition.snapshot, transition.history);
  }

  Future<void> redo() async {
    if (state.isImporting) {
      return;
    }

    final transition = state.history.redo(_captureProjectSnapshot());
    if (transition == null) {
      return;
    }

    _clearPendingEditTransactions();
    await _restoreProjectSnapshot(transition.snapshot, transition.history);
  }

  Future<void> _restoreProjectSnapshot(
    ProjectSnapshot snapshot,
    EditorHistory history,
  ) async {
    final previousTracks = state.tracks;
    final arrangementChanged = !_hasSameAudioArrangement(
      previousTracks,
      snapshot.tracks,
    );
    final mixerChanged = !_hasSameMixerState(previousTracks, snapshot.tracks);
    final clipGainChanged = !_hasSameClipGainState(
      previousTracks,
      snapshot.tracks,
    );
    final requestId = arrangementChanged ? ++_clipEditRequestId : null;
    final previousPosition = _audioEngine.currentPositionSeconds;
    final selectedTrackId =
        snapshot.tracks.any((track) => track.id == snapshot.selectedTrackId)
        ? snapshot.selectedTrackId
        : null;
    final existingClipIds = {
      for (final track in snapshot.tracks)
        for (final clip in track.clips) clip.id,
    };
    final selectedClipIds = snapshot.selectedClipIds
        .where(existingClipIds.contains)
        .toSet();

    state = EditorState(
      isPlaying: state.isPlaying,
      isImporting: state.isImporting,
      playheadSeconds: state.playheadSeconds,
      pixelsPerSecond: state.pixelsPerSecond,
      isLoopEnabled: state.isLoopEnabled,
      loopRegion: state.loopRegion,
      tracks: snapshot.tracks,
      selectedTrackId: selectedTrackId,
      selectedClipIds: selectedClipIds,
      clipClipboard: state.clipClipboard,
      history: history,
    );
    ref.read(tempoControllerProvider.notifier).setBpm(snapshot.bpm);

    if (arrangementChanged) {
      await _resynchronizeArrangement(
        requestId: requestId!,
        positionSeconds: previousPosition,
      );
    } else {
      if (clipGainChanged) {
        _audioEngine.syncClipGains(state.tracks);
      }
      if (mixerChanged) {
        _audioEngine.syncMixer(state.tracks);
      }
    }
  }

  bool _hasSameAudioArrangement(List<DawTrack> left, List<DawTrack> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var trackIndex = 0; trackIndex < left.length; trackIndex++) {
      final leftTrack = left[trackIndex];
      final rightTrack = right[trackIndex];
      if (leftTrack.id != rightTrack.id ||
          leftTrack.clips.length != rightTrack.clips.length) {
        return false;
      }

      for (var clipIndex = 0; clipIndex < leftTrack.clips.length; clipIndex++) {
        final leftClip = leftTrack.clips[clipIndex];
        final rightClip = rightTrack.clips[clipIndex];
        if (leftClip.id != rightClip.id ||
            leftClip.audio.id != rightClip.audio.id ||
            leftClip.timelineStartSeconds != rightClip.timelineStartSeconds ||
            leftClip.sourceStartSeconds != rightClip.sourceStartSeconds ||
            leftClip.clipDurationSeconds != rightClip.clipDurationSeconds ||
            leftClip.fadeInDurationSeconds != rightClip.fadeInDurationSeconds ||
            leftClip.fadeOutDurationSeconds !=
                rightClip.fadeOutDurationSeconds) {
          return false;
        }
      }
    }

    return true;
  }

  bool _hasSameMixerState(List<DawTrack> left, List<DawTrack> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      final leftTrack = left[index];
      final rightTrack = right[index];
      if (leftTrack.id != rightTrack.id ||
          leftTrack.volumeDb != rightTrack.volumeDb ||
          leftTrack.pan != rightTrack.pan ||
          leftTrack.isMuted != rightTrack.isMuted ||
          leftTrack.isSolo != rightTrack.isSolo) {
        return false;
      }
    }

    return true;
  }

  bool _hasSameClipGainState(List<DawTrack> left, List<DawTrack> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var trackIndex = 0; trackIndex < left.length; trackIndex++) {
      final leftClips = left[trackIndex].clips;
      final rightClips = right[trackIndex].clips;
      if (leftClips.length != rightClips.length) {
        return false;
      }
      for (var clipIndex = 0; clipIndex < leftClips.length; clipIndex++) {
        if (leftClips[clipIndex].id != rightClips[clipIndex].id ||
            leftClips[clipIndex].gainDb != rightClips[clipIndex].gainDb) {
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _resynchronizeArrangement({
    required int requestId,
    required double positionSeconds,
  }) async {
    _playheadTimer?.cancel();
    await _audioEngine.seek(
      tracks: state.tracks,
      positionSeconds: positionSeconds,
      loopRegion: state.isLoopEnabled ? state.loopRegion : null,
    );

    if (requestId != _clipEditRequestId) {
      return;
    }

    state = state.copyWith(
      isPlaying: _audioEngine.isPlaying,
      playheadSeconds: _audioEngine.currentPositionSeconds,
    );

    if (_audioEngine.isPlaying) {
      _startPlayheadTicker();
    }
  }

  Future<List<String>> importAudioFiles(List<ImportedAudioFile> files) async {
    if (files.isEmpty) {
      return [];
    }

    if (state.isPlaying) {
      stop();
    }

    state = state.copyWith(isImporting: true);

    final newTracks = <DawTrack>[];
    final failedFiles = <String>[];

    for (final file in files) {
      _assetCounter++;
      _clipCounter++;

      final assetId = 'asset-$_assetCounter';

      final trackId = _nextTrackId();
      final clipId = 'clip-$_clipCounter';

      try {
        final decoded = await _audioEngine.decode(
          assetId: assetId,
          bytes: file.bytes,
        );

        final audio = AudioAsset(
          id: assetId,
          name: file.name,
          extension: file.extension,
          size: file.size,
          durationSeconds: decoded.durationSeconds,
          sampleRate: decoded.sampleRate,
          numberOfChannels: decoded.numberOfChannels,
          waveformPeaks: decoded.waveformPeaks,
        );

        newTracks.add(
          DawTrack(
            id: trackId,
            name: file.name,
            colorValue: defaultTrackColorForIndex(_trackCounter - 1),
            clips: [
              AudioClip(
                id: clipId,
                audio: audio,
                clipDurationSeconds: audio.durationSeconds,
              ),
            ],
          ),
        );
      } catch (_) {
        failedFiles.add(file.name);
      }
    }

    final before = _captureProjectSnapshot();
    state = state.copyWith(
      isImporting: false,
      tracks: [...state.tracks, ...newTracks],
      selectedTrackId: newTracks.isEmpty
          ? state.selectedTrackId
          : newTracks.last.id,
      selectedClipId: newTracks.isEmpty
          ? state.selectedClipId
          : newTracks.last.clips.single.id,
    );

    if (newTracks.isNotEmpty) {
      _recordEdit('Import Audio', before);
    }

    return failedFiles;
  }

  String addTrack() {
    final before = _captureProjectSnapshot();
    final trackId = _nextTrackId();
    final track = DawTrack(
      id: trackId,
      name: _nextDefaultTrackName(),
      colorValue: defaultTrackColorForIndex(_trackCounter - 1),
      clips: const [],
    );

    state = state.copyWith(
      tracks: [...state.tracks, track],
      selectedTrackId: track.id,
    );
    _recordEdit('Add Track', before);
    return track.id;
  }

  String _nextTrackId() {
    final existingIds = state.tracks.map((track) => track.id).toSet();
    do {
      _trackCounter++;
    } while (existingIds.contains('track-$_trackCounter'));
    return 'track-$_trackCounter';
  }

  String _nextDefaultTrackName() {
    final existingNames = state.tracks.map((track) => track.name).toSet();
    var number = 1;
    while (existingNames.contains('Track $number')) {
      number++;
    }
    return 'Track $number';
  }

  void setPixelsPerSecond(double pixelsPerSecond) {
    final clamped = TimelineScale.clampPixelsPerSecond(pixelsPerSecond);

    if (clamped == state.pixelsPerSecond) {
      return;
    }

    state = state.copyWith(pixelsPerSecond: clamped);
  }

  Future<void> play() async {
    final loop = state.isLoopEnabled ? state.loopRegion : null;
    if (state.tracks.isEmpty && loop == null) {
      return;
    }

    final startPosition = loop != null && !loop.contains(state.playheadSeconds)
        ? loop.startSeconds
        : state.playheadSeconds;

    await _audioEngine.play(
      tracks: state.tracks,
      fromSeconds: startPosition,
      loopRegion: loop,
    );

    state = state.copyWith(
      isPlaying: _audioEngine.isPlaying,
      playheadSeconds: _audioEngine.currentPositionSeconds,
    );

    if (_audioEngine.isPlaying) {
      _startPlayheadTicker();
    }
  }

  void pause() {
    _audioEngine.pause();

    _playheadTimer?.cancel();

    state = state.copyWith(
      isPlaying: false,
      playheadSeconds: _audioEngine.currentPositionSeconds,
    );
  }

  Future<void> togglePlayback() async {
    if (state.isPlaying) {
      pause();
    } else {
      await play();
    }
  }

  void stop() {
    _audioEngine.stop();

    _playheadTimer?.cancel();

    state = state.copyWith(isPlaying: false, playheadSeconds: 0);
  }

  Future<void> seek(double positionSeconds) async {
    final duration = state.timelineDurationSeconds;

    if (duration <= 0) {
      return;
    }

    final position = positionSeconds.clamp(0.0, duration);

    _playheadTimer?.cancel();
    state = state.copyWith(playheadSeconds: position);

    final loop = state.isLoopEnabled ? state.loopRegion : null;
    final enginePosition =
        state.isPlaying && loop != null && !loop.contains(position)
        ? loop.startSeconds
        : position;
    await _audioEngine.seek(
      tracks: state.tracks,
      positionSeconds: enginePosition,
      loopRegion: loop,
    );

    state = state.copyWith(
      isPlaying: _audioEngine.isPlaying,
      playheadSeconds: _audioEngine.currentPositionSeconds,
    );

    if (_audioEngine.isPlaying) {
      _startPlayheadTicker();
    }
  }

  void _startPlayheadTicker() {
    _playheadTimer?.cancel();

    _playheadTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final position = _audioEngine.currentPositionSeconds;

      final duration = state.projectDurationSeconds;

      if (!state.isLoopEnabled && duration > 0 && position >= duration) {
        _playheadTimer?.cancel();

        _audioEngine.stop();

        state = state.copyWith(isPlaying: false, playheadSeconds: 0);

        return;
      }

      state = state.copyWith(playheadSeconds: position);
    });
  }

  Future<void> setLoopRegion(LoopRegion region) async {
    if (region == state.loopRegion) {
      return;
    }

    final wasPlaying = state.isPlaying;
    final currentPosition = wasPlaying
        ? _audioEngine.currentPositionSeconds
        : state.playheadSeconds;
    state = state.copyWith(loopRegion: region);

    if (!wasPlaying || !state.isLoopEnabled) {
      return;
    }

    final resyncPosition = region.contains(currentPosition)
        ? currentPosition
        : region.startSeconds;
    await _resynchronizeLoopPlayback(resyncPosition);
  }

  Future<void> toggleLoop() async {
    var region = state.loopRegion;
    if (region == null) {
      final timing = MusicalTiming(bpm: ref.read(tempoControllerProvider).bpm);
      final barDuration = timing.barDurationSeconds;
      final start = (state.playheadSeconds / barDuration).floor() * barDuration;
      region = LoopRegion(startSeconds: start, endSeconds: start + barDuration);
    }

    final enabled = state.loopRegion == null ? true : !state.isLoopEnabled;
    final wasPlaying = state.isPlaying;
    final currentPosition = wasPlaying
        ? _audioEngine.currentPositionSeconds
        : state.playheadSeconds;
    state = state.copyWith(isLoopEnabled: enabled, loopRegion: region);

    if (!wasPlaying) {
      return;
    }

    final resyncPosition = enabled && !region.contains(currentPosition)
        ? region.startSeconds
        : currentPosition;
    await _resynchronizeLoopPlayback(resyncPosition);
  }

  Future<void> _resynchronizeLoopPlayback(double positionSeconds) async {
    _playheadTimer?.cancel();
    await _audioEngine.seek(
      tracks: state.tracks,
      positionSeconds: positionSeconds,
      loopRegion: state.isLoopEnabled ? state.loopRegion : null,
    );
    state = state.copyWith(
      isPlaying: _audioEngine.isPlaying,
      playheadSeconds: _audioEngine.currentPositionSeconds,
    );
    if (_audioEngine.isPlaying) {
      _startPlayheadTicker();
    }
  }

  void selectTrack(String trackId) {
    state = state.copyWith(selectedTrackId: trackId);
  }

  void selectClip({
    required String trackId,
    required String clipId,
    bool toggle = false,
    bool preserveExistingIfSelected = false,
  }) {
    if (!_containsClip(clipId)) {
      return;
    }
    final selected = {...state.selectedClipIds};
    if (toggle) {
      selected.contains(clipId)
          ? selected.remove(clipId)
          : selected.add(clipId);
    } else if (!preserveExistingIfSelected || !selected.contains(clipId)) {
      selected
        ..clear()
        ..add(clipId);
    }
    state = state.copyWith(selectedTrackId: trackId, selectedClipIds: selected);
  }

  void setSelectedClipIds(Iterable<String> clipIds) {
    final existingIds = {
      for (final track in state.tracks)
        for (final clip in track.clips) clip.id,
    };
    state = state.copyWith(
      selectedClipIds: clipIds.where(existingIds.contains).toSet(),
    );
  }

  void clearClipSelection() {
    if (state.selectedClipIds.isEmpty) {
      return;
    }
    state = state.copyWith(clearSelectedClip: true);
  }

  void copySelectedClip() {
    final locations = [
      for (final track in state.tracks)
        for (final clip in track.clips)
          if (state.selectedClipIds.contains(clip.id))
            (track: track, clip: clip),
    ];
    if (locations.isEmpty) {
      return;
    }
    locations.sort((left, right) {
      final timeOrder = left.clip.timelineStartSeconds.compareTo(
        right.clip.timelineStartSeconds,
      );
      return timeOrder != 0 ? timeOrder : left.clip.id.compareTo(right.clip.id);
    });
    final origin = locations.first.clip.timelineStartSeconds;

    state = state.copyWith(
      clipClipboard: EditorClipClipboard(
        locations.map(
          (location) => CopiedClipData.fromClip(
            trackId: location.track.id,
            clip: location.clip,
            timelineOriginSeconds: origin,
          ),
        ),
      ),
    );
  }

  Future<void> pasteCopiedClip() async {
    final copied = state.clipClipboard.clips;
    final trackIds = state.tracks.map((track) => track.id).toSet();
    if (copied.isEmpty ||
        !copied.every((clip) => trackIds.contains(clip.originalTrackId))) {
      return;
    }

    final anchorSeconds = TimelineSnapper.snapTime(
      candidateSeconds: state.playheadSeconds,
      bpm: ref.read(tempoControllerProvider).bpm,
      settings: ref.read(snapControllerProvider),
    );
    await _insertCopiedClips(
      copied: copied,
      anchorSeconds: anchorSeconds,
      historyLabel: 'Paste Clips',
    );
  }

  Future<void> duplicateSelectedClip() async {
    final locations = [
      for (final track in state.tracks)
        for (final clip in track.clips)
          if (state.selectedClipIds.contains(clip.id))
            (track: track, clip: clip),
    ];
    if (locations.isEmpty) {
      return;
    }
    final groupStart = locations
        .map((location) => location.clip.timelineStartSeconds)
        .reduce(math.min);
    final groupEnd = locations
        .map((location) => location.clip.timelineEndSeconds)
        .reduce(math.max);

    await _insertCopiedClips(
      copied: [
        for (final location in locations)
          CopiedClipData.fromClip(
            trackId: location.track.id,
            clip: location.clip,
            timelineOriginSeconds: groupStart,
          ),
      ],
      anchorSeconds: groupStart + (groupEnd - groupStart),
      historyLabel: 'Duplicate Clips',
    );
  }

  Future<void> _insertCopiedClips({
    required List<CopiedClipData> copied,
    required double anchorSeconds,
    required String historyLabel,
  }) async {
    final trackIds = state.tracks.map((track) => track.id).toSet();
    if (!anchorSeconds.isFinite ||
        copied.isEmpty ||
        !copied.every((clip) => trackIds.contains(clip.originalTrackId))) {
      return;
    }

    final normalizedAnchor = anchorSeconds
        .clamp(0.0, double.infinity)
        .toDouble();
    final insertions = <({CopiedClipData copied, AudioClip newClip})>[];
    for (final clip in copied) {
      final id = _nextClipId();
      insertions.add((
        copied: clip,
        newClip: clip.createClip(
          id: id,
          timelineStartSeconds: normalizedAnchor + clip.timelineOffsetSeconds,
        ),
      ));
    }
    final before = _captureProjectSnapshot();
    final requestId = ++_clipEditRequestId;
    final previousPosition = _audioEngine.currentPositionSeconds;
    final tracks = [
      for (final track in state.tracks)
        track.copyWith(
          clips: _orderedClips([
            ...track.clips,
            for (final insertion in insertions)
              if (insertion.copied.originalTrackId == track.id)
                insertion.newClip,
          ]),
        ),
    ];

    state = state.copyWith(
      tracks: tracks,
      selectedTrackId: copied.first.originalTrackId,
      selectedClipIds: insertions
          .map((insertion) => insertion.newClip.id)
          .toSet(),
    );
    _recordEdit(historyLabel, before);
    await _resynchronizeArrangement(
      requestId: requestId,
      positionSeconds: previousPosition,
    );
  }

  void renameTrack(String trackId, String name) {
    var normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      return;
    }
    if (normalizedName.length > maximumTrackNameLength) {
      normalizedName = normalizedName
          .substring(0, maximumTrackNameLength)
          .trimRight();
    }

    final track = state.tracks
        .where((track) => track.id == trackId)
        .firstOrNull;
    if (track == null || track.name == normalizedName) {
      return;
    }

    final before = _captureProjectSnapshot();
    state = state.copyWith(
      tracks: [
        for (final currentTrack in state.tracks)
          if (currentTrack.id == trackId)
            currentTrack.copyWith(name: normalizedName)
          else
            currentTrack,
      ],
    );
    _recordEdit('Rename Track', before);
  }

  void setTrackColor(String trackId, int colorValue) {
    final track = state.tracks
        .where((track) => track.id == trackId)
        .firstOrNull;
    final normalizedColor = opaqueTrackColor(colorValue);
    if (track == null || track.colorValue == normalizedColor) {
      return;
    }

    final before = _captureProjectSnapshot();
    _setTrackColorValue(trackId, normalizedColor);
    _recordEdit('Change Track Color', before);
  }

  void beginTrackColorChange(String trackId) {
    if (_trackColorEditStartSnapshot != null) {
      return;
    }

    final track = state.tracks
        .where((track) => track.id == trackId)
        .firstOrNull;
    if (track == null) {
      return;
    }

    _trackColorEditStartSnapshot = _captureProjectSnapshot();
    _trackColorEditTrackId = trackId;
    _trackColorEditOriginalValue = track.colorValue;
  }

  void previewTrackColor(String trackId, int colorValue) {
    if (_trackColorEditTrackId != trackId) {
      return;
    }
    _setTrackColorValue(trackId, colorValue);
  }

  void commitTrackColorChange(String trackId) {
    if (_trackColorEditTrackId != trackId) {
      return;
    }

    final before = _trackColorEditStartSnapshot;
    _clearTrackColorEditTransaction();
    if (before != null) {
      _recordEdit('Change Track Color', before);
    }
  }

  void cancelTrackColorChange(String trackId) {
    if (_trackColorEditTrackId != trackId) {
      return;
    }

    final originalColor = _trackColorEditOriginalValue;
    _clearTrackColorEditTransaction();
    if (originalColor != null) {
      _setTrackColorValue(trackId, originalColor);
    }
  }

  void _clearTrackColorEditTransaction() {
    _trackColorEditStartSnapshot = null;
    _trackColorEditTrackId = null;
    _trackColorEditOriginalValue = null;
  }

  void _setTrackColorValue(String trackId, int colorValue) {
    final normalizedColor = opaqueTrackColor(colorValue);
    state = state.copyWith(
      tracks: [
        for (final currentTrack in state.tracks)
          if (currentTrack.id == trackId)
            currentTrack.copyWith(colorValue: normalizedColor)
          else
            currentTrack,
      ],
    );
  }

  Future<void> moveClip(
    String clipId,
    double timelineStartSeconds, {
    int trackDelta = 0,
  }) async {
    if (!timelineStartSeconds.isFinite) {
      return;
    }

    final anchor = _findClip(clipId);
    if (anchor == null) {
      return;
    }
    final movingIds = state.selectedClipIds.contains(clipId)
        ? state.selectedClipIds
        : {clipId};
    final movingClips = [
      for (var trackIndex = 0; trackIndex < state.tracks.length; trackIndex++)
        for (final clip in state.tracks[trackIndex].clips)
          if (movingIds.contains(clip.id)) (clip: clip, trackIndex: trackIndex),
    ];
    if (movingClips.isEmpty || state.tracks.isEmpty) {
      return;
    }
    final minimumTrackIndex = movingClips
        .map((location) => location.trackIndex)
        .reduce(math.min);
    final maximumTrackIndex = movingClips
        .map((location) => location.trackIndex)
        .reduce(math.max);
    final clampedTrackDelta = trackDelta
        .clamp(-minimumTrackIndex, state.tracks.length - 1 - maximumTrackIndex)
        .toInt();
    final minimumStart = movingClips
        .map((location) => location.clip.timelineStartSeconds)
        .reduce(math.min);
    final requestedDelta = timelineStartSeconds - anchor.timelineStartSeconds;
    final timelineDelta = math.max(requestedDelta, -minimumStart);
    if (timelineDelta.abs() < 0.000001 && clampedTrackDelta == 0) {
      return;
    }

    final clipsByDestinationTrackId = <String, List<AudioClip>>{};
    var anchorDestinationTrackId = state.selectedTrackId;
    for (final location in movingClips) {
      final destinationTrack =
          state.tracks[location.trackIndex + clampedTrackDelta];
      final movedClip = location.clip.copyWith(
        timelineStartSeconds:
            location.clip.timelineStartSeconds + timelineDelta,
      );
      (clipsByDestinationTrackId[destinationTrack.id] ??= []).add(movedClip);
      if (location.clip.id == clipId) {
        anchorDestinationTrackId = destinationTrack.id;
      }
    }
    final effectiveMovingIds = {
      for (final location in movingClips) location.clip.id,
    };

    final before = _captureProjectSnapshot();
    final requestId = ++_clipEditRequestId;
    final tracks = [
      for (final track in state.tracks)
        track.copyWith(
          clips: _orderedClips([
            for (final clip in track.clips)
              if (!effectiveMovingIds.contains(clip.id)) clip,
            ...(clipsByDestinationTrackId[track.id] ?? const <AudioClip>[]),
          ]),
        ),
    ];
    final previousPosition = _audioEngine.currentPositionSeconds;

    state = state.copyWith(
      tracks: tracks,
      selectedTrackId: anchorDestinationTrackId,
      selectedClipIds: effectiveMovingIds,
    );
    _recordEdit('Move Clips', before);
    await _resynchronizeArrangement(
      requestId: requestId,
      positionSeconds: previousPosition,
    );
  }

  Future<void> updateClipTrim({
    required String clipId,
    required double timelineStartSeconds,
    required double sourceStartSeconds,
    required double clipDurationSeconds,
  }) async {
    if (!timelineStartSeconds.isFinite ||
        !sourceStartSeconds.isFinite ||
        !clipDurationSeconds.isFinite) {
      return;
    }

    AudioClip? currentClip;
    for (final track in state.tracks) {
      for (final clip in track.clips) {
        if (clip.id == clipId) {
          currentClip = clip;
          break;
        }
      }
      if (currentClip != null) {
        break;
      }
    }

    if (currentClip == null) {
      return;
    }

    final sourceDuration = currentClip.sourceAudioDurationSeconds;
    final minimumDuration = math.min(
      minimumClipDurationSeconds,
      sourceDuration,
    );
    final normalizedSourceStart = sourceStartSeconds
        .clamp(0.0, math.max(0.0, sourceDuration - minimumDuration))
        .toDouble();
    final maximumDuration = sourceDuration - normalizedSourceStart;
    final normalizedDuration = clipDurationSeconds
        .clamp(minimumDuration, maximumDuration)
        .toDouble();
    final normalizedTimelineStart = timelineStartSeconds
        .clamp(0.0, double.infinity)
        .toDouble();
    if ((currentClip.timelineStartSeconds - normalizedTimelineStart).abs() <
            0.000001 &&
        (currentClip.sourceStartSeconds - normalizedSourceStart).abs() <
            0.000001 &&
        (currentClip.clipDurationSeconds - normalizedDuration).abs() <
            0.000001) {
      return;
    }

    final before = _captureProjectSnapshot();
    final requestId = ++_clipEditRequestId;
    final tracks = [
      for (final track in state.tracks)
        track.copyWith(
          clips: _orderedClips([
            for (final clip in track.clips)
              if (clip.id == clipId)
                clip.copyWith(
                  timelineStartSeconds: normalizedTimelineStart,
                  sourceStartSeconds: normalizedSourceStart,
                  clipDurationSeconds: normalizedDuration,
                )
              else
                clip,
          ]),
        ),
    ];
    final previousPosition = _audioEngine.currentPositionSeconds;

    state = state.copyWith(tracks: tracks, selectedClipId: clipId);
    _recordEdit('Trim Clip', before);
    await _resynchronizeArrangement(
      requestId: requestId,
      positionSeconds: previousPosition,
    );
  }

  Future<void> splitClip(String clipId, double timelineSeconds) async {
    if (!timelineSeconds.isFinite) {
      return;
    }

    DawTrack? containingTrack;
    AudioClip? originalClip;
    for (final track in state.tracks) {
      for (final clip in track.clips) {
        if (clip.id == clipId) {
          containingTrack = track;
          originalClip = clip;
          break;
        }
      }
      if (originalClip != null) {
        break;
      }
    }

    if (containingTrack == null ||
        originalClip == null ||
        !canSplitAudioClip(originalClip, timelineSeconds)) {
      return;
    }

    final rightClipId = _nextClipId();
    final split = splitAudioClip(
      clip: originalClip,
      rightClipId: rightClipId,
      timelineSeconds: timelineSeconds,
    );
    if (split == null) {
      return;
    }

    final before = _captureProjectSnapshot();
    final requestId = ++_clipEditRequestId;
    final tracks = [
      for (final track in state.tracks)
        if (track.id == containingTrack.id)
          track.copyWith(
            clips: _orderedClips([
              for (final clip in track.clips)
                if (clip.id == clipId) ...[split.left, split.right] else clip,
            ]),
          )
        else
          track,
    ];
    final previousPosition = _audioEngine.currentPositionSeconds;

    state = state.copyWith(
      tracks: tracks,
      selectedTrackId: containingTrack.id,
      selectedClipId: rightClipId,
    );
    _recordEdit('Split Clip', before);
    await _resynchronizeArrangement(
      requestId: requestId,
      positionSeconds: previousPosition,
    );
  }

  void beginClipGainChange(String clipId) {
    if (_clipGainEditStartSnapshot != null || !_containsClip(clipId)) {
      return;
    }
    _clipGainEditStartSnapshot = _captureProjectSnapshot();
    _clipGainEditClipId = clipId;
  }

  void previewClipGain(String clipId, double gainDb) {
    if (_clipGainEditClipId != clipId || !gainDb.isFinite) {
      return;
    }
    _setClipGain(clipId, gainDb);
  }

  void commitClipGainChange(String clipId) {
    if (_clipGainEditClipId != clipId) {
      return;
    }
    final before = _clipGainEditStartSnapshot;
    _clipGainEditStartSnapshot = null;
    _clipGainEditClipId = null;
    if (before == null ||
        before.hasSameProjectState(_captureProjectSnapshot())) {
      return;
    }
    _recordEdit('Change Clip Gain', before);
  }

  void resetClipGain(String clipId) {
    final clip = _findClip(clipId);
    if (clip == null || clip.gainDb == defaultClipGainDb) {
      return;
    }
    final pendingBefore = _clipGainEditClipId == clipId
        ? _clipGainEditStartSnapshot
        : null;
    _clipGainEditStartSnapshot = null;
    _clipGainEditClipId = null;
    final before = pendingBefore ?? _captureProjectSnapshot();
    _setClipGain(clipId, defaultClipGainDb);
    _recordEdit('Change Clip Gain', before);
  }

  void _setClipGain(String clipId, double gainDb) {
    final clampedGainDb = clampClipGainDb(gainDb);
    state = state.copyWith(
      tracks: [
        for (final track in state.tracks)
          track.copyWith(
            clips: [
              for (final clip in track.clips)
                clip.id == clipId ? clip.copyWith(gainDb: clampedGainDb) : clip,
            ],
          ),
      ],
    );
    _audioEngine.setClipGain(clipId, clampedGainDb);
  }

  void beginFadeInChange(String clipId) {
    _beginClipFadeChange(clipId, _ClipFadeEdge.fadeIn);
  }

  void beginFadeOutChange(String clipId) {
    _beginClipFadeChange(clipId, _ClipFadeEdge.fadeOut);
  }

  void _beginClipFadeChange(String clipId, _ClipFadeEdge edge) {
    if (_clipFadeEditStartSnapshot != null || !_containsClip(clipId)) {
      return;
    }
    _clipFadeEditStartSnapshot = _captureProjectSnapshot();
    _clipFadeEditClipId = clipId;
    _clipFadeEditEdge = edge;
  }

  void previewFadeIn(String clipId, double durationSeconds) {
    _previewClipFade(clipId, _ClipFadeEdge.fadeIn, durationSeconds);
  }

  void previewFadeOut(String clipId, double durationSeconds) {
    _previewClipFade(clipId, _ClipFadeEdge.fadeOut, durationSeconds);
  }

  void _previewClipFade(
    String clipId,
    _ClipFadeEdge edge,
    double durationSeconds,
  ) {
    if (_clipFadeEditClipId != clipId ||
        _clipFadeEditEdge != edge ||
        !durationSeconds.isFinite) {
      return;
    }
    _setClipFade(clipId, edge, durationSeconds);
  }

  Future<void> commitFadeInChange(String clipId) {
    return _commitClipFadeChange(clipId, _ClipFadeEdge.fadeIn);
  }

  Future<void> commitFadeOutChange(String clipId) {
    return _commitClipFadeChange(clipId, _ClipFadeEdge.fadeOut);
  }

  Future<void> _commitClipFadeChange(String clipId, _ClipFadeEdge edge) async {
    if (_clipFadeEditClipId != clipId || _clipFadeEditEdge != edge) {
      return;
    }
    final before = _clipFadeEditStartSnapshot;
    _clipFadeEditStartSnapshot = null;
    _clipFadeEditClipId = null;
    _clipFadeEditEdge = null;
    if (before == null ||
        before.hasSameProjectState(_captureProjectSnapshot())) {
      return;
    }
    _recordEdit(
      edge == _ClipFadeEdge.fadeIn ? 'Change Fade In' : 'Change Fade Out',
      before,
    );
    await _resynchronizeFadePlayback();
  }

  Future<void> resetFadeIn(String clipId) {
    return _resetClipFade(clipId, _ClipFadeEdge.fadeIn);
  }

  Future<void> resetFadeOut(String clipId) {
    return _resetClipFade(clipId, _ClipFadeEdge.fadeOut);
  }

  Future<void> _resetClipFade(String clipId, _ClipFadeEdge edge) async {
    final clip = _findClip(clipId);
    if (clip == null ||
        (edge == _ClipFadeEdge.fadeIn
                ? clip.fadeInDurationSeconds
                : clip.fadeOutDurationSeconds) ==
            0) {
      return;
    }
    final pendingBefore =
        _clipFadeEditClipId == clipId && _clipFadeEditEdge == edge
        ? _clipFadeEditStartSnapshot
        : null;
    _clipFadeEditStartSnapshot = null;
    _clipFadeEditClipId = null;
    _clipFadeEditEdge = null;
    final before = pendingBefore ?? _captureProjectSnapshot();
    _setClipFade(clipId, edge, 0);
    _recordEdit(
      edge == _ClipFadeEdge.fadeIn ? 'Change Fade In' : 'Change Fade Out',
      before,
    );
    await _resynchronizeFadePlayback();
  }

  void _setClipFade(String clipId, _ClipFadeEdge edge, double durationSeconds) {
    state = state.copyWith(
      tracks: [
        for (final track in state.tracks)
          track.copyWith(
            clips: [
              for (final clip in track.clips)
                if (clip.id == clipId)
                  edge == _ClipFadeEdge.fadeIn
                      ? clip.copyWith(
                          fadeInDurationSeconds: durationSeconds
                              .clamp(
                                0.0,
                                clip.clipDurationSeconds -
                                    clip.fadeOutDurationSeconds,
                              )
                              .toDouble(),
                        )
                      : clip.copyWith(
                          fadeOutDurationSeconds: durationSeconds
                              .clamp(
                                0.0,
                                clip.clipDurationSeconds -
                                    clip.fadeInDurationSeconds,
                              )
                              .toDouble(),
                        )
                else
                  clip,
            ],
          ),
      ],
    );
  }

  Future<void> _resynchronizeFadePlayback() async {
    if (!state.isPlaying) {
      return;
    }
    final requestId = ++_clipEditRequestId;
    await _resynchronizeArrangement(
      requestId: requestId,
      positionSeconds: _audioEngine.currentPositionSeconds,
    );
  }

  bool _containsClip(String clipId) => _findClip(clipId) != null;

  AudioClip? _findClip(String clipId) {
    return _findClipLocation(clipId)?.clip;
  }

  ({DawTrack track, AudioClip clip})? _findClipLocation(String clipId) {
    for (final track in state.tracks) {
      for (final clip in track.clips) {
        if (clip.id == clipId) {
          return (track: track, clip: clip);
        }
      }
    }
    return null;
  }

  Future<void> deleteSelectedClip() async {
    if (state.selectedClipIds.isEmpty) {
      return;
    }
    await _deleteClips(state.selectedClipIds, label: 'Delete Clips');
  }

  Future<void> deleteClip(String clipId) async {
    await _deleteClips({clipId}, label: 'Delete Clip');
  }

  Future<void> _deleteClips(
    Set<String> clipIds, {
    required String label,
  }) async {
    final existingIds = {
      for (final track in state.tracks)
        for (final clip in track.clips)
          if (clipIds.contains(clip.id)) clip.id,
    };
    if (existingIds.isEmpty) {
      return;
    }

    final before = _captureProjectSnapshot();
    final requestId = ++_clipEditRequestId;
    final previousPosition = _audioEngine.currentPositionSeconds;
    final tracks = [
      for (final track in state.tracks)
        track.copyWith(
          clips: [
            for (final clip in track.clips)
              if (!existingIds.contains(clip.id)) clip,
          ],
        ),
    ];
    final after = ProjectSnapshot(
      tracks: tracks,
      bpm: ref.read(tempoControllerProvider).bpm,
      selectedTrackId: state.selectedTrackId,
      selectedClipIds: const {},
    );
    final history = state.history.record(
      label: label,
      before: before,
      after: after,
    );

    state = state.copyWith(
      tracks: tracks,
      clearSelectedClip: true,
      history: history,
    );
    await _resynchronizeArrangement(
      requestId: requestId,
      positionSeconds: previousPosition,
    );
  }

  String _nextClipId() {
    final existingIds = {
      for (final track in state.tracks)
        for (final clip in track.clips) clip.id,
    };

    do {
      _clipCounter++;
    } while (existingIds.contains('clip-$_clipCounter'));

    return 'clip-$_clipCounter';
  }

  static List<AudioClip> _orderedClips(Iterable<AudioClip> clips) {
    final ordered = clips.toList();
    ordered.sort((left, right) {
      final timeOrder = left.timelineStartSeconds.compareTo(
        right.timelineStartSeconds,
      );
      return timeOrder != 0 ? timeOrder : left.id.compareTo(right.id);
    });
    return ordered;
  }

  Future<void> removeTrack(String trackId) async {
    final matchingTracks = state.tracks.where((track) => track.id == trackId);
    if (matchingTracks.isEmpty) {
      return;
    }

    final removedTrack = matchingTracks.single;
    final before = _captureProjectSnapshot();
    final tracks = state.tracks.where((track) => track.id != trackId).toList();
    final removedClipIds = removedTrack.clips.map((clip) => clip.id).toSet();
    final hasAudioArrangementChange = removedTrack.clips.isNotEmpty;
    final requestId = hasAudioArrangementChange ? ++_clipEditRequestId : null;
    final previousPosition = hasAudioArrangementChange
        ? _audioEngine.currentPositionSeconds
        : null;

    state = state.copyWith(
      tracks: tracks,
      clearSelectedTrack: state.selectedTrackId == trackId,
      selectedClipIds: state.selectedClipIds.difference(removedClipIds),
    );
    _recordEdit('Delete Track', before);
    if (hasAudioArrangementChange) {
      await _resynchronizeArrangement(
        requestId: requestId!,
        positionSeconds: previousPosition!,
      );
    } else {
      _audioEngine.removeTrack(trackId);
      _audioEngine.syncMixer(state.tracks);
    }
  }

  void toggleMute(String trackId) {
    final before = _captureProjectSnapshot();
    state = state.copyWith(
      tracks: [
        for (final track in state.tracks)
          if (track.id == trackId)
            track.copyWith(isMuted: !track.isMuted)
          else
            track,
      ],
    );

    _audioEngine.syncMixer(state.tracks);
    _recordEdit('Mute Track', before);
  }

  void toggleSolo(String trackId) {
    final before = _captureProjectSnapshot();
    state = state.copyWith(
      tracks: [
        for (final track in state.tracks)
          if (track.id == trackId)
            track.copyWith(isSolo: !track.isSolo)
          else
            track,
      ],
    );

    _audioEngine.syncMixer(state.tracks);
    _recordEdit('Solo Track', before);
  }

  void beginVolumeChange(String trackId) {
    if (_volumeEditStartSnapshot != null ||
        !state.tracks.any((track) => track.id == trackId)) {
      return;
    }

    _volumeEditStartSnapshot = _captureProjectSnapshot();
    _volumeEditTrackId = trackId;
  }

  void previewVolume(String trackId, double volumeDb) {
    if (_volumeEditTrackId != trackId) {
      return;
    }

    _setVolume(trackId, volumeDb);
  }

  void commitVolumeChange(String trackId) {
    if (_volumeEditTrackId != trackId) {
      return;
    }

    final before = _volumeEditStartSnapshot;
    _volumeEditStartSnapshot = null;
    _volumeEditTrackId = null;
    if (before != null) {
      _recordEdit('Change Track Volume', before);
    }
  }

  void resetVolume(String trackId) {
    final track = state.tracks
        .where((track) => track.id == trackId)
        .firstOrNull;
    if (track == null) {
      return;
    }

    final pendingBefore = _volumeEditTrackId == trackId
        ? _volumeEditStartSnapshot
        : null;
    if (_volumeEditTrackId == trackId) {
      _volumeEditStartSnapshot = null;
      _volumeEditTrackId = null;
    }
    final before = pendingBefore ?? _captureProjectSnapshot();
    if (track.volumeDb == unityTrackVolumeDb) {
      _recordEdit('Reset Track Volume', before);
      return;
    }

    _setVolume(trackId, unityTrackVolumeDb);
    _recordEdit('Reset Track Volume', before);
  }

  void _setVolume(String trackId, double volumeDb) {
    state = state.copyWith(
      tracks: [
        for (final track in state.tracks)
          if (track.id == trackId)
            track.copyWith(volumeDb: clampTrackVolumeDb(volumeDb))
          else
            track,
      ],
    );

    _audioEngine.syncMixer(state.tracks);
  }

  void beginPanChange(String trackId) {
    if (_panEditStartSnapshot != null ||
        !state.tracks.any((track) => track.id == trackId)) {
      return;
    }

    _panEditStartSnapshot = _captureProjectSnapshot();
    _panEditTrackId = trackId;
  }

  void previewPan(String trackId, double pan) {
    if (_panEditTrackId != trackId) {
      return;
    }

    _setPan(trackId, pan);
  }

  void commitPanChange(String trackId) {
    if (_panEditTrackId != trackId) {
      return;
    }

    final before = _panEditStartSnapshot;
    _panEditStartSnapshot = null;
    _panEditTrackId = null;
    if (before != null) {
      _recordEdit('Change Track Pan', before);
    }
  }

  void resetPan(String trackId) {
    final track = state.tracks
        .where((track) => track.id == trackId)
        .firstOrNull;
    if (track == null) {
      return;
    }

    final pendingBefore = _panEditTrackId == trackId
        ? _panEditStartSnapshot
        : null;
    if (_panEditTrackId == trackId) {
      _panEditStartSnapshot = null;
      _panEditTrackId = null;
    }
    if (track.pan == centerTrackPan) {
      return;
    }

    final before = pendingBefore ?? _captureProjectSnapshot();
    _setPan(trackId, centerTrackPan);
    _recordEdit('Change Track Pan', before);
  }

  void _setPan(String trackId, double pan) {
    state = state.copyWith(
      tracks: [
        for (final track in state.tracks)
          if (track.id == trackId)
            track.copyWith(pan: clampTrackPan(pan))
          else
            track,
      ],
    );

    _audioEngine.syncMixer(state.tracks);
  }

  void setTempoBpm(double bpm) {
    final before = _captureProjectSnapshot();
    ref.read(tempoControllerProvider.notifier).setBpm(bpm);
    _recordEdit('Change Tempo', before);
  }

  void beginTempoChange() {
    _tempoEditStartSnapshot ??= _captureProjectSnapshot();
  }

  void previewTempoBpm(double bpm) {
    if (_tempoEditStartSnapshot == null) {
      return;
    }

    ref.read(tempoControllerProvider.notifier).setBpm(bpm);
  }

  void commitTempoChange() {
    final before = _tempoEditStartSnapshot;
    _tempoEditStartSnapshot = null;
    if (before != null) {
      _recordEdit('Change Tempo', before);
    }
  }
}

enum _ClipFadeEdge { fadeIn, fadeOut }

final editorControllerProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);
