import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Owns the Blob URL and media element used to preview and download one render.
class BrowserAudioFile {
  BrowserAudioFile.wav(Uint8List bytes) : this(bytes, mimeType: 'audio/wav');

  BrowserAudioFile(Uint8List bytes, {required String mimeType})
    : _audioElement = web.HTMLAudioElement(),
      _objectUrl = web.URL.createObjectURL(
        web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType)),
      ) {
    _audioElement
      ..src = _objectUrl
      ..preload = 'auto';
  }

  final web.HTMLAudioElement _audioElement;
  final String _objectUrl;
  bool _isDisposed = false;

  double get currentPositionSeconds => _audioElement.currentTime;

  bool get isPlaying => !_audioElement.paused;

  Future<void> play() async {
    _ensureNotDisposed();
    await _audioElement.play().toDart;
  }

  void pause() {
    if (_isDisposed) {
      return;
    }
    _audioElement.pause();
  }

  void seek(double positionSeconds) {
    _ensureNotDisposed();
    _audioElement.currentTime = positionSeconds;
  }

  void download({String fileName = 'daw-export.wav'}) {
    _ensureNotDisposed();
    final anchor = web.HTMLAnchorElement()
      ..href = _objectUrl
      ..download = fileName
      ..style.display = 'none';

    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _audioElement
      ..pause()
      ..removeAttribute('src')
      ..load();
    web.URL.revokeObjectURL(_objectUrl);
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('The rendered audio file has been disposed.');
    }
  }
}
