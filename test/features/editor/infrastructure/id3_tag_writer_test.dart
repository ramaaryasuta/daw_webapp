import 'dart:convert';
import 'dart:typed_data';

import 'package:daw_webapp/features/editor/domain/export_settings.dart';
import 'package:daw_webapp/features/editor/infrastructure/id3_tag_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepends standard ID3v2.3 frames without changing MP3 payload', () {
    final mp3 = Uint8List.fromList([0xff, 0xfb, 0x90, 0x64]);
    final tagged = Id3TagWriter.prepend(
      mp3,
      const ExportMetadata(
        title: 'Midnight Demo',
        artist: 'Flaudio',
        album: 'Exports',
        year: '2026',
        trackNumber: '1',
        genre: 'Electronic',
        comment: 'Local render',
      ),
    );

    expect(ascii.decode(tagged.sublist(0, 3)), 'ID3');
    expect(tagged[3], 3);
    final latin = latin1.decode(tagged, allowInvalid: true);
    for (final frame in [
      'TIT2',
      'TPE1',
      'TALB',
      'TYER',
      'TRCK',
      'TCON',
      'COMM',
    ]) {
      expect(latin, contains(frame));
    }
    expect(tagged.sublist(tagged.length - mp3.length), mp3);
  });
}
