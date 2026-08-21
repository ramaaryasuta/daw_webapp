import 'dart:typed_data';

class BrowserAudioFile {
  BrowserAudioFile.wav(Uint8List bytes);

  double get currentPositionSeconds => 0;

  bool get isPlaying => false;

  Future<void> play() {
    throw UnsupportedError('Audio preview is only available in a browser.');
  }

  void pause() {}

  void seek(double positionSeconds) {}

  void download({String fileName = 'daw-export.wav'}) {
    throw UnsupportedError('Audio download is only available in a browser.');
  }

  void dispose() {}
}
