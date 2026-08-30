import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

abstract final class Mp3Encoder {
  static const int _framesPerChunk = 65536;
  static const int _chunksPerYield = 8;

  static Future<Uint8List> encode({
    required List<Float32List> channels,
    required int sampleRate,
    required int bitrateKbps,
  }) async {
    if (channels.length != 2 || channels.first.length != channels.last.length) {
      throw ArgumentError('MP3 encoding requires equal-length stereo PCM.');
    }

    final library = globalContext['WasmMediaEncoder'];
    if (library == null || library.isUndefinedOrNull) {
      throw StateError('The local MP3 encoder runtime is unavailable.');
    }
    final wasmUrl = Uri.base.resolve('vendor/mp3.wasm').toString().toJS;
    final promise = (library as JSObject).callMethod<JSPromise<JSObject>>(
      'createEncoder'.toJS,
      'audio/mpeg'.toJS,
      wasmUrl,
    );
    final encoder = await promise.toDart;
    final options = JSObject()
      ..['channels'] = 2.toJS
      ..['sampleRate'] = sampleRate.toJS
      ..['bitrate'] = bitrateKbps.toJS;
    encoder.callMethod<JSAny?>('configure'.toJS, options);

    final chunks = <Uint8List>[];
    var byteLength = 0;
    final frameCount = channels.first.length;
    var chunkIndex = 0;
    for (var start = 0; start < frameCount; start += _framesPerChunk) {
      final end = (start + _framesPerChunk).clamp(0, frameCount);
      final pcm = <JSFloat32Array>[
        Float32List.sublistView(channels[0], start, end).toJS,
        Float32List.sublistView(channels[1], start, end).toJS,
      ].toJS;
      final encoded = encoder.callMethod<JSUint8Array>('encode'.toJS, pcm);
      final copy = Uint8List.fromList(encoded.toDart);
      if (copy.isNotEmpty) {
        chunks.add(copy);
        byteLength += copy.length;
      }
      chunkIndex++;
      if (chunkIndex % _chunksPerYield == 0 && end < frameCount) {
        await Future<void>.delayed(Duration.zero);
      }
    }
    final flushed = Uint8List.fromList(
      encoder.callMethod<JSUint8Array>('finalize'.toJS).toDart,
    );
    if (flushed.isNotEmpty) {
      chunks.add(flushed);
      byteLength += flushed.length;
    }

    final output = Uint8List(byteLength);
    var offset = 0;
    for (final chunk in chunks) {
      output.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return output;
  }
}
