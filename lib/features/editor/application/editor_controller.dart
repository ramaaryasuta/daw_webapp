import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/audio_asset.dart';
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
  });

  final bool isPlaying;
  final bool isImporting;

  final double playheadSeconds;
  final double pixelsPerSecond;

  final List<DawTrack> tracks;
  final String? selectedTrackId;

  double get projectDurationSeconds {
    var duration = 0.0;

    for (final track in tracks) {
      if (track.endTimeSeconds > duration) {
        duration = track.endTimeSeconds;
      }
    }

    return duration;
  }

  EditorState copyWith({
    bool? isPlaying,
    bool? isImporting,
    double? playheadSeconds,
    double? pixelsPerSecond,
    List<DawTrack>? tracks,
    String? selectedTrackId,
    bool clearSelectedTrack = false,
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
    );
  }
}

class EditorController extends Notifier<EditorState> {
  int _trackCounter = 0;
  int _assetCounter = 0;

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

      final assetId = 'asset-$_assetCounter';

      final trackId = 'track-$_trackCounter';

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

        newTracks.add(DawTrack(id: trackId, name: file.name, audio: audio));
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

  void removeTrack(String trackId) {
    _audioEngine.removeTrack(trackId);

    final tracks = state.tracks.where((track) => track.id != trackId).toList();

    state = state.copyWith(
      tracks: tracks,
      clearSelectedTrack: state.selectedTrackId == trackId,
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
