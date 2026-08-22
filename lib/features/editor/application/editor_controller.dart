import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_asset.dart';
import '../domain/audio_clip.dart';
import '../domain/daw_track.dart';
import '../domain/imported_audio_file.dart';
import '../domain/timeline_scale.dart';
import '../domain/track_color.dart';
import '../domain/track_mixer.dart';
import '../infrastructure/web_audio_engine.dart';
import 'editor_history.dart';
import 'tempo_controller.dart';

class EditorState {
  EditorState({
    this.isPlaying = false,
    this.isImporting = false,
    this.playheadSeconds = 0,
    this.pixelsPerSecond = TimelineScale.defaultPixelsPerSecond,
    this.tracks = const [],
    this.selectedTrackId,
    this.selectedClipId,
    EditorHistory? history,
  }) : history = history ?? EditorHistory();

  final bool isPlaying;
  final bool isImporting;

  final double playheadSeconds;
  final double pixelsPerSecond;

  final List<DawTrack> tracks;
  final String? selectedTrackId;
  final String? selectedClipId;
  final EditorHistory history;

  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;

  double get projectDurationSeconds {
    return calculateProjectDurationSeconds(tracks);
  }

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

  bool get canDeleteSelectedClip => selectedClip != null;

  EditorState copyWith({
    bool? isPlaying,
    bool? isImporting,
    double? playheadSeconds,
    double? pixelsPerSecond,
    List<DawTrack>? tracks,
    String? selectedTrackId,
    String? selectedClipId,
    bool clearSelectedTrack = false,
    bool clearSelectedClip = false,
    EditorHistory? history,
  }) {
    return EditorState(
      isPlaying: isPlaying ?? this.isPlaying,
      isImporting: isImporting ?? this.isImporting,
      playheadSeconds: playheadSeconds ?? this.playheadSeconds,
      pixelsPerSecond: pixelsPerSecond ?? this.pixelsPerSecond,
      tracks: tracks ?? this.tracks,
      selectedTrackId: clearSelectedTrack
          ? null
          : selectedTrackId ?? this.selectedTrackId,
      selectedClipId: clearSelectedClip
          ? null
          : selectedClipId ?? this.selectedClipId,
      history: history ?? this.history,
    );
  }
}

class EditorController extends Notifier<EditorState> {
  int _trackCounter = 0;
  int _assetCounter = 0;
  int _clipCounter = 0;
  int _clipEditRequestId = 0;

  ProjectSnapshot? _tempoEditStartSnapshot;
  ProjectSnapshot? _volumeEditStartSnapshot;
  String? _volumeEditTrackId;
  ProjectSnapshot? _trackColorEditStartSnapshot;
  String? _trackColorEditTrackId;
  int? _trackColorEditOriginalValue;

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
      selectedClipId: state.selectedClipId,
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
    _trackColorEditStartSnapshot = null;
    _trackColorEditTrackId = null;
    _trackColorEditOriginalValue = null;
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
    final requestId = arrangementChanged ? ++_clipEditRequestId : null;
    final previousPosition = _audioEngine.currentPositionSeconds;
    final selectedTrackId =
        snapshot.tracks.any((track) => track.id == snapshot.selectedTrackId)
        ? snapshot.selectedTrackId
        : null;
    final selectedClipId =
        snapshot.tracks.any(
          (track) =>
              track.clips.any((clip) => clip.id == snapshot.selectedClipId),
        )
        ? snapshot.selectedClipId
        : null;

    state = EditorState(
      isPlaying: state.isPlaying,
      isImporting: state.isImporting,
      playheadSeconds: state.playheadSeconds,
      pixelsPerSecond: state.pixelsPerSecond,
      tracks: snapshot.tracks,
      selectedTrackId: selectedTrackId,
      selectedClipId: selectedClipId,
      history: history,
    );
    ref.read(tempoControllerProvider.notifier).setBpm(snapshot.bpm);

    if (arrangementChanged) {
      await _resynchronizeArrangement(
        requestId: requestId!,
        positionSeconds: previousPosition,
      );
    } else if (mixerChanged) {
      _audioEngine.syncMixer(state.tracks);
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
            leftClip.clipDurationSeconds != rightClip.clipDurationSeconds) {
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
          leftTrack.isMuted != rightTrack.isMuted ||
          leftTrack.isSolo != rightTrack.isSolo) {
        return false;
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
      _trackCounter++;
      _clipCounter++;

      final assetId = 'asset-$_assetCounter';

      final trackId = 'track-$_trackCounter';
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

  void setPixelsPerSecond(double pixelsPerSecond) {
    final clamped = TimelineScale.clampPixelsPerSecond(pixelsPerSecond);

    if (clamped == state.pixelsPerSecond) {
      return;
    }

    state = state.copyWith(pixelsPerSecond: clamped);
  }

  Future<void> play() async {
    if (state.tracks.isEmpty) {
      return;
    }

    await _audioEngine.play(
      tracks: state.tracks,
      fromSeconds: state.playheadSeconds,
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
    final duration = state.projectDurationSeconds;

    if (duration <= 0) {
      return;
    }

    final position = positionSeconds.clamp(0.0, duration);

    _playheadTimer?.cancel();
    state = state.copyWith(playheadSeconds: position);

    await _audioEngine.seek(tracks: state.tracks, positionSeconds: position);

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

      if (duration > 0 && position >= duration) {
        _playheadTimer?.cancel();

        _audioEngine.stop();

        state = state.copyWith(isPlaying: false, playheadSeconds: 0);

        return;
      }

      state = state.copyWith(playheadSeconds: position);
    });
  }

  void selectTrack(String trackId) {
    state = state.copyWith(selectedTrackId: trackId);
  }

  void selectClip({required String trackId, required String clipId}) {
    state = state.copyWith(selectedTrackId: trackId, selectedClipId: clipId);
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

  Future<void> moveClip(String clipId, double timelineStartSeconds) async {
    if (!timelineStartSeconds.isFinite) {
      return;
    }

    final normalizedStart = timelineStartSeconds
        .clamp(0.0, double.infinity)
        .toDouble();
    AudioClip? movedClip;

    for (final track in state.tracks) {
      for (final clip in track.clips) {
        if (clip.id == clipId) {
          movedClip = clip;
          break;
        }
      }
      if (movedClip != null) {
        break;
      }
    }

    if (movedClip == null ||
        (movedClip.timelineStartSeconds - normalizedStart).abs() < 0.000001) {
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
                clip.copyWith(timelineStartSeconds: normalizedStart)
              else
                clip,
          ]),
        ),
    ];
    final previousPosition = _audioEngine.currentPositionSeconds;

    state = state.copyWith(tracks: tracks, selectedClipId: clipId);
    _recordEdit('Move Clip', before);
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

  Future<void> deleteSelectedClip() async {
    final clipId = state.selectedClipId;
    if (clipId == null) {
      return;
    }

    await deleteClip(clipId);
  }

  Future<void> deleteClip(String clipId) async {
    DawTrack? containingTrack;
    for (final track in state.tracks) {
      if (track.clips.any((clip) => clip.id == clipId)) {
        containingTrack = track;
        break;
      }
    }
    if (containingTrack == null) {
      return;
    }

    final before = _captureProjectSnapshot();
    final requestId = ++_clipEditRequestId;
    final previousPosition = _audioEngine.currentPositionSeconds;
    final tracks = [
      for (final track in state.tracks)
        if (track.id == containingTrack.id)
          track.copyWith(
            clips: [
              for (final clip in track.clips)
                if (clip.id != clipId) clip,
            ],
          )
        else
          track,
    ];
    final selectedClipId = state.selectedClipId == clipId
        ? null
        : state.selectedClipId;
    final after = ProjectSnapshot(
      tracks: tracks,
      bpm: ref.read(tempoControllerProvider).bpm,
      selectedTrackId: state.selectedTrackId,
      selectedClipId: selectedClipId,
    );
    final history = state.history.record(
      label: 'Delete Clip',
      before: before,
      after: after,
    );

    state = state.copyWith(
      tracks: tracks,
      selectedClipId: selectedClipId,
      clearSelectedClip: selectedClipId == null,
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
    if (!state.tracks.any((track) => track.id == trackId)) {
      return;
    }

    final before = _captureProjectSnapshot();
    final requestId = ++_clipEditRequestId;
    final previousPosition = _audioEngine.currentPositionSeconds;
    final tracks = state.tracks.where((track) => track.id != trackId).toList();

    state = state.copyWith(
      tracks: tracks,
      clearSelectedTrack: state.selectedTrackId == trackId,
      clearSelectedClip: state.tracks.any(
        (track) =>
            track.id == trackId &&
            track.clips.any((clip) => clip.id == state.selectedClipId),
      ),
    );
    _recordEdit('Delete Track', before);
    await _resynchronizeArrangement(
      requestId: requestId,
      positionSeconds: previousPosition,
    );
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

final editorControllerProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);
