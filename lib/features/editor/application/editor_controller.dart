import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_asset.dart';
import '../domain/audio_clip.dart';
import '../domain/daw_track.dart';
import '../domain/imported_audio_file.dart';
import '../domain/timeline_scale.dart';
import '../infrastructure/web_audio_engine.dart';

class EditorState {
  const EditorState({
    this.isPlaying = false,
    this.isImporting = false,
    this.playheadSeconds = 0,
    this.pixelsPerSecond = TimelineScale.defaultPixelsPerSecond,
    this.tracks = const [],
    this.selectedTrackId,
    this.selectedClipId,
  });

  final bool isPlaying;
  final bool isImporting;

  final double playheadSeconds;
  final double pixelsPerSecond;

  final List<DawTrack> tracks;
  final String? selectedTrackId;
  final String? selectedClipId;

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
    );
  }
}

class EditorController extends Notifier<EditorState> {
  int _trackCounter = 0;
  int _assetCounter = 0;
  int _clipCounter = 0;
  int _clipEditRequestId = 0;

  Timer? _playheadTimer;

  WebAudioEngine get _audioEngine => ref.read(webAudioEngineProvider);

  @override
  EditorState build() {
    ref.onDispose(() {
      _playheadTimer?.cancel();
    });

    return const EditorState();
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
    _playheadTimer?.cancel();

    await _audioEngine.seek(tracks: tracks, positionSeconds: previousPosition);

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
    _playheadTimer?.cancel();

    await _audioEngine.seek(tracks: tracks, positionSeconds: previousPosition);

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
    _playheadTimer?.cancel();

    await _audioEngine.seek(tracks: tracks, positionSeconds: previousPosition);

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

  void removeTrack(String trackId) {
    _clipEditRequestId++;
    _audioEngine.removeTrack(trackId);

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

    _audioEngine.syncMixer(tracks);
  }

  void toggleMute(String trackId) {
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
  }

  void toggleSolo(String trackId) {
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
  }

  void setVolume(String trackId, double volume) {
    state = state.copyWith(
      tracks: [
        for (final track in state.tracks)
          if (track.id == trackId)
            track.copyWith(volume: volume.clamp(0.0, 1.0))
          else
            track,
      ],
    );

    _audioEngine.syncMixer(state.tracks);
  }
}

final editorControllerProvider =
    NotifierProvider<EditorController, EditorState>(EditorController.new);
