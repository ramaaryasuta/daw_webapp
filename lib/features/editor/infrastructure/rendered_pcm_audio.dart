import 'dart:typed_data';

class RenderedPcmAudio {
  const RenderedPcmAudio({
    required this.channels,
    required this.durationSeconds,
    required this.sampleRate,
  });

  final List<Float32List> channels;
  final double durationSeconds;
  final int sampleRate;

  int get channelCount => channels.length;
}
