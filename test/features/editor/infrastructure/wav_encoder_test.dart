import 'dart:convert';
import 'dart:typed_data';

import 'package:daw_webapp/features/editor/infrastructure/wav_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes a valid stereo 16-bit PCM WAV header', () {
    final bytes = WavEncoder.encodePcm16(
      channels: [
        Float32List.fromList([0, 0.5]),
        Float32List.fromList([0, -0.5]),
      ],
      sampleRate: 48000,
    );
    final data = ByteData.sublistView(bytes);

    expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
    expect(data.getUint32(4, Endian.little), bytes.length - 8);
    expect(ascii.decode(bytes.sublist(8, 12)), 'WAVE');
    expect(ascii.decode(bytes.sublist(12, 16)), 'fmt ');
    expect(data.getUint16(20, Endian.little), 1);
    expect(data.getUint16(22, Endian.little), 2);
    expect(data.getUint32(24, Endian.little), 48000);
    expect(data.getUint16(34, Endian.little), 16);
    expect(ascii.decode(bytes.sublist(36, 40)), 'data');
    expect(data.getUint32(40, Endian.little), 8);
  });

  test('interleaves channels and clamps samples before PCM conversion', () {
    final bytes = WavEncoder.encodePcm16(
      channels: [
        Float32List.fromList([-2, 0.25]),
        Float32List.fromList([2, -0.25]),
      ],
      sampleRate: 44100,
    );
    final data = ByteData.sublistView(bytes);

    expect(data.getInt16(44, Endian.little), -32768);
    expect(data.getInt16(46, Endian.little), 32767);
    expect(data.getInt16(48, Endian.little), 8192);
    expect(data.getInt16(50, Endian.little), -8192);
  });

  test('rejects mismatched channel lengths', () {
    expect(
      () => WavEncoder.encodePcm16(
        channels: [Float32List(1), Float32List(2)],
        sampleRate: 44100,
      ),
      throwsArgumentError,
    );
  });
}
