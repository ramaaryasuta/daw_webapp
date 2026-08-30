enum ExportFormat { wav, mp3 }

extension ExportFormatInfo on ExportFormat {
  String get label => switch (this) {
    ExportFormat.wav => 'WAV',
    ExportFormat.mp3 => 'MP3',
  };

  String get extension => switch (this) {
    ExportFormat.wav => 'wav',
    ExportFormat.mp3 => 'mp3',
  };

  String get mimeType => switch (this) {
    ExportFormat.wav => 'audio/wav',
    ExportFormat.mp3 => 'audio/mpeg',
  };
}

class ExportMetadata {
  const ExportMetadata({
    this.title = '',
    this.artist = '',
    this.album = '',
    this.year = '',
    this.trackNumber = '',
    this.genre = '',
    this.comment = '',
  });

  final String title;
  final String artist;
  final String album;
  final String year;
  final String trackNumber;
  final String genre;
  final String comment;

  bool get isEmpty =>
      title.trim().isEmpty &&
      artist.trim().isEmpty &&
      album.trim().isEmpty &&
      year.trim().isEmpty &&
      trackNumber.trim().isEmpty &&
      genre.trim().isEmpty &&
      comment.trim().isEmpty;
}

class ExportSettings {
  const ExportSettings({
    required this.format,
    required this.fileName,
    this.mp3BitrateKbps = 256,
    this.metadata = const ExportMetadata(),
  });

  final ExportFormat format;
  final int mp3BitrateKbps;
  final String fileName;
  final ExportMetadata metadata;

  String get outputFileName => exportFileName(fileName, format);

  String get fingerprint => <Object>[
    format.name,
    mp3BitrateKbps,
    outputFileName,
    metadata.title,
    metadata.artist,
    metadata.album,
    metadata.year,
    metadata.trackNumber,
    metadata.genre,
    metadata.comment,
  ].join('\u001f');
}

const supportedMp3BitratesKbps = <int>[128, 192, 256, 320];

String exportFileName(String value, ExportFormat format) {
  var name = value.trim();
  name = name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '-');
  name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  name = name.replaceAll(RegExp(r'[. ]+$'), '');
  name = name.replaceFirst(RegExp(r'\.(wav|mp3)$', caseSensitive: false), '');
  name = name.replaceAll(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) name = 'Flaudio Export';
  return '$name.${format.extension}';
}

int estimateExportBytes({
  required ExportFormat format,
  required double durationSeconds,
  required int sampleRate,
  required int channelCount,
  int mp3BitrateKbps = 256,
  int metadataAllowanceBytes = 2048,
}) {
  if (durationSeconds <= 0 || !durationSeconds.isFinite) return 0;
  return switch (format) {
    ExportFormat.wav =>
      44 + (durationSeconds * sampleRate * channelCount * 2).ceil(),
    ExportFormat.mp3 =>
      (mp3BitrateKbps * 1000 * durationSeconds / 8).ceil() +
          metadataAllowanceBytes,
  };
}
