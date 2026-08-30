import 'dart:typed_data';

import '../domain/export_settings.dart';

abstract final class Id3TagWriter {
  static Uint8List prepend(Uint8List mp3Bytes, ExportMetadata metadata) {
    final frames = <Uint8List>[
      if (metadata.title.trim().isNotEmpty)
        _textFrame('TIT2', metadata.title.trim()),
      if (metadata.artist.trim().isNotEmpty)
        _textFrame('TPE1', metadata.artist.trim()),
      if (metadata.album.trim().isNotEmpty)
        _textFrame('TALB', metadata.album.trim()),
      if (metadata.year.trim().isNotEmpty)
        _textFrame('TYER', metadata.year.trim()),
      if (metadata.trackNumber.trim().isNotEmpty)
        _textFrame('TRCK', metadata.trackNumber.trim()),
      if (metadata.genre.trim().isNotEmpty)
        _textFrame('TCON', metadata.genre.trim()),
      if (metadata.comment.trim().isNotEmpty)
        _commentFrame(metadata.comment.trim()),
    ];
    if (frames.isEmpty) return mp3Bytes;

    final bodyLength = frames.fold<int>(0, (sum, frame) => sum + frame.length);
    final output = Uint8List(10 + bodyLength + mp3Bytes.length);
    output.setRange(0, 3, 'ID3'.codeUnits);
    output[3] = 3; // ID3v2.3 for broad player compatibility.
    output[4] = 0;
    output[5] = 0;
    _writeSynchsafe(output, 6, bodyLength);
    var offset = 10;
    for (final frame in frames) {
      output.setRange(offset, offset + frame.length, frame);
      offset += frame.length;
    }
    output.setRange(offset, output.length, mp3Bytes);
    return output;
  }

  static Uint8List _textFrame(String id, String value) {
    final text = _utf16(value);
    final body = Uint8List(1 + text.length)
      ..[0] = 1
      ..setRange(1, 1 + text.length, text);
    return _frame(id, body);
  }

  static Uint8List _commentFrame(String value) {
    final text = _utf16(value);
    final body = Uint8List(1 + 3 + 4 + text.length)
      ..[0] = 1
      ..setRange(1, 4, 'eng'.codeUnits)
      ..setRange(4, 8, const [0xff, 0xfe, 0, 0])
      ..setRange(8, 8 + text.length, text);
    return _frame('COMM', body);
  }

  static Uint8List _utf16(String value) {
    final output = Uint8List(2 + value.codeUnits.length * 2)
      ..[0] = 0xff
      ..[1] = 0xfe;
    final data = ByteData.sublistView(output);
    for (var i = 0; i < value.codeUnits.length; i++) {
      data.setUint16(2 + i * 2, value.codeUnitAt(i), Endian.little);
    }
    return output;
  }

  static Uint8List _frame(String id, Uint8List body) {
    final output = Uint8List(10 + body.length);
    output.setRange(0, 4, id.codeUnits);
    final data = ByteData.sublistView(output);
    data.setUint32(4, body.length, Endian.big);
    data.setUint16(8, 0, Endian.big);
    output.setRange(10, output.length, body);
    return output;
  }

  static void _writeSynchsafe(Uint8List output, int offset, int value) {
    output[offset] = (value >> 21) & 0x7f;
    output[offset + 1] = (value >> 14) & 0x7f;
    output[offset + 2] = (value >> 7) & 0x7f;
    output[offset + 3] = value & 0x7f;
  }
}
