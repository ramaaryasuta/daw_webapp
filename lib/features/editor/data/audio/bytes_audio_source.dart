// ignore_for_file: experimental_member_use

import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';

class BytesAudioSource extends StreamAudioSource {
  BytesAudioSource({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final actualStart = start ?? 0;
    final actualEnd = end ?? bytes.length;

    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: actualEnd - actualStart,
      offset: actualStart,
      stream: Stream.value(bytes.sublist(actualStart, actualEnd)),
      contentType: contentType,
    );
  }
}
