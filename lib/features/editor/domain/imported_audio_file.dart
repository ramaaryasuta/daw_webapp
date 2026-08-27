import 'dart:typed_data';

class ImportedAudioFile {
  const ImportedAudioFile({
    required this.name,
    required this.extension,
    required this.bytes,
    required this.size,
    this.mimeType,
  });

  final String name;
  final String extension;
  final Uint8List bytes;
  final int size;
  final String? mimeType;
}
