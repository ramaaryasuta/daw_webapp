import 'dart:typed_data';

abstract final class WavEncoder {
  static const int bitsPerSample = 16;
  static const int _headerLength = 44;

  static Uint8List encodePcm16({
    required List<Float32List> channels,
    required int sampleRate,
  }) {
    if (channels.isEmpty) {
      throw ArgumentError.value(channels, 'channels', 'Must not be empty.');
    }
    if (sampleRate <= 0) {
      throw ArgumentError.value(sampleRate, 'sampleRate', 'Must be positive.');
    }

    final frameCount = channels.first.length;
    if (channels.any((channel) => channel.length != frameCount)) {
      throw ArgumentError('All WAV channels must have the same frame count.');
    }

    final channelCount = channels.length;
    final bytesPerSample = bitsPerSample ~/ 8;
    final blockAlign = channelCount * bytesPerSample;
    final dataLength = frameCount * blockAlign;
    if (dataLength > 0xffffffff - 36) {
      throw ArgumentError(
        'The rendered audio is too large for a RIFF WAV file.',
      );
    }
    final bytes = Uint8List(_headerLength + dataLength);
    final data = ByteData.sublistView(bytes);

    _writeAscii(data, 0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    _writeAscii(data, 8, 'WAVE');
    _writeAscii(data, 12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channelCount, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * blockAlign, Endian.little);
    data.setUint16(32, blockAlign, Endian.little);
    data.setUint16(34, bitsPerSample, Endian.little);
    _writeAscii(data, 36, 'data');
    data.setUint32(40, dataLength, Endian.little);

    var byteOffset = _headerLength;
    for (var frame = 0; frame < frameCount; frame++) {
      for (var channel = 0; channel < channelCount; channel++) {
        final sample = channels[channel][frame].clamp(-1.0, 1.0);
        final pcm = sample < 0
            ? (sample * 32768).round()
            : (sample * 32767).round();
        data.setInt16(byteOffset, pcm, Endian.little);
        byteOffset += bytesPerSample;
      }
    }

    return bytes;
  }

  static void _writeAscii(ByteData data, int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      data.setUint8(offset + index, value.codeUnitAt(index));
    }
  }
}
