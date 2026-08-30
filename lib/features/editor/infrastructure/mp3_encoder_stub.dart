import 'dart:typed_data';

abstract final class Mp3Encoder {
  static Future<Uint8List> encode({
    required List<Float32List> channels,
    required int sampleRate,
    required int bitrateKbps,
  }) {
    throw UnsupportedError('MP3 encoding is only available in a browser.');
  }
}
