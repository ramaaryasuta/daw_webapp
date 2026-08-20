import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../domain/models/audio_track.dart';
import 'bytes_audio_source.dart';

class DawAudioEngine {
  final Map<String, AudioPlayer> _players = {};

  StreamSubscription<Duration>? _masterPositionSubscription;

  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;

  Future<Duration> addTrack(AudioTrack track) async {
    // Hindari player duplikat.
    if (_players.containsKey(track.id)) {
      return track.duration;
    }

    final player = AudioPlayer();

    final source = BytesAudioSource(
      bytes: track.bytes,
      contentType: track.contentType,
    );

    final duration = await player.setAudioSource(source);

    await player.setVolume(track.volume);

    _players[track.id] = player;

    _setupMasterPositionPlayer();

    return duration ?? Duration.zero;
  }

  void _setupMasterPositionPlayer() {
    if (_players.isEmpty) {
      return;
    }

    // Sudah ada master.
    if (_masterPositionSubscription != null) {
      return;
    }

    final masterPlayer = _players.values.first;

    _masterPositionSubscription = masterPlayer.positionStream.listen((
      position,
    ) {
      _positionController.add(position);
    });
  }

  void play() {
    for (final player in _players.values) {
      // Jangan await di sini.
      //
      // Future dari play() selesai ketika playback selesai,
      // bukan ketika playback baru mulai.
      unawaited(player.play());
    }
  }

  Future<void> pause() async {
    await Future.wait(_players.values.map((player) => player.pause()));
  }

  Future<void> stop() async {
    await pause();

    await seek(Duration.zero);
  }

  Future<void> seek(Duration position) async {
    await Future.wait(_players.values.map((player) => player.seek(position)));

    _positionController.add(position);
  }

  Future<void> setTrackVolume(String trackId, double volume) async {
    final player = _players[trackId];

    if (player == null) {
      return;
    }

    await player.setVolume(volume);
  }

  Future<void> setTrackMuted(
    String trackId,
    bool muted,
    double normalVolume,
  ) async {
    final player = _players[trackId];

    if (player == null) {
      return;
    }

    await player.setVolume(muted ? 0 : normalVolume);
  }

  Future<void> removeTrack(String trackId) async {
    final player = _players.remove(trackId);

    if (player == null) {
      return;
    }

    await player.dispose();

    // Untuk sementara kita reset master listener.
    await _masterPositionSubscription?.cancel();
    _masterPositionSubscription = null;

    _setupMasterPositionPlayer();
  }

  Future<void> dispose() async {
    await _masterPositionSubscription?.cancel();

    for (final player in _players.values) {
      await player.dispose();
    }

    _players.clear();

    await _positionController.close();
  }
}
