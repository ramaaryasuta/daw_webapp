import 'dart:typed_data';

abstract final class WavEncoder {
  static const int bitsPerSample = 16;
  static const int _headerLength = 44;
  static const int _defaultFramesPerChunk = 131072;

  static Uint8List encodePcm16({
    required List<Float32List> channels,
    required int sampleRate,
  }) {
    final output = _preparePcm16(channels: channels, sampleRate: sampleRate);
    _writePcmFrames(
      channels: channels,
      data: output.data,
      startFrame: 0,
      endFrame: output.frameCount,
    );

    return output.bytes;
  }

  static Future<Uint8List> encodePcm16Async({
    required List<Float32List> channels,
    required int sampleRate,
    int framesPerChunk = _defaultFramesPerChunk,
  }) async {
    if (framesPerChunk <= 0) {
      throw ArgumentError.value(
        framesPerChunk,
        'framesPerChunk',
        'Must be positive.',
      );
    }

    final output = _preparePcm16(channels: channels, sampleRate: sampleRate);
    for (
      var startFrame = 0;
      startFrame < output.frameCount;
      startFrame += framesPerChunk
    ) {
      final endFrame = (startFrame + framesPerChunk)
          .clamp(0, output.frameCount)
          .toInt();
      _writePcmFrames(
        channels: channels,
        data: output.data,
        startFrame: startFrame,
        endFrame: endFrame,
      );

      if (endFrame < output.frameCount) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    return output.bytes;
  }

  static ({Uint8List bytes, ByteData data, int frameCount}) _preparePcm16({
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

    return (bytes: bytes, data: data, frameCount: frameCount);
  }

  static void _writePcmFrames({
    required List<Float32List> channels,
    required ByteData data,
    required int startFrame,
    required int endFrame,
  }) {
    final bytesPerSample = bitsPerSample ~/ 8;
    var byteOffset =
        _headerLength + startFrame * channels.length * bytesPerSample;

    for (var frame = startFrame; frame < endFrame; frame++) {
      for (var channel = 0; channel < channels.length; channel++) {
        final sample = channels[channel][frame].clamp(-1.0, 1.0);
        final pcm = sample < 0
            ? (sample * 32768).round()
            : (sample * 32767).round();
        data.setInt16(byteOffset, pcm, Endian.little);
        byteOffset += bytesPerSample;
      }
    }
  }

  static void _writeAscii(ByteData data, int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      data.setUint8(offset + index, value.codeUnitAt(index));
    }
  }
}
