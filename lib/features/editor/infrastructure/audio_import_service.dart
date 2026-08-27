import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/imported_audio_file.dart';

class AudioImportResult {
  const AudioImportResult({required this.files, required this.rejectedFiles});

  final List<ImportedAudioFile> files;
  final List<String> rejectedFiles;
}

class AudioImportService {
  const AudioImportService();

  static const supportedExtensions = <String>{'wav', 'mp3'};

  Future<AudioImportResult> pickAudioFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions.toList(),
    );

    if (files.isEmpty) {
      return const AudioImportResult(files: [], rejectedFiles: []);
    }

    final imported = <ImportedAudioFile>[];
    final rejected = <String>[];

    for (final file in files) {
      if (!_isSupported(file.name)) {
        rejected.add(file.name);
        continue;
      }

      try {
        final bytes = await file.readAsBytes();

        imported.add(
          ImportedAudioFile(
            name: file.name,
            extension: _getExtension(file.name),
            bytes: bytes,
            size: bytes.length,
            mimeType: _mimeTypeForExtension(_getExtension(file.name)),
          ),
        );
      } catch (_) {
        rejected.add(file.name);
      }
    }

    return AudioImportResult(files: imported, rejectedFiles: rejected);
  }

  Future<AudioImportResult> importDroppedItems(List<DropItem> items) async {
    final imported = <ImportedAudioFile>[];
    final rejected = <String>[];

    for (final item in items) {
      if (item is! DropItemFile) {
        rejected.add(item.name);
        continue;
      }

      if (!_isSupported(item.name)) {
        rejected.add(item.name);
        continue;
      }

      try {
        final bytes = await item.readAsBytes();

        imported.add(
          ImportedAudioFile(
            name: item.name,
            extension: _getExtension(item.name),
            bytes: bytes,
            size: bytes.length,
            mimeType: _mimeTypeForExtension(_getExtension(item.name)),
          ),
        );
      } catch (_) {
        rejected.add(item.name);
      }
    }

    return AudioImportResult(files: imported, rejectedFiles: rejected);
  }

  bool _isSupported(String fileName) {
    return supportedExtensions.contains(_getExtension(fileName));
  }

  String _getExtension(String fileName) {
    final index = fileName.lastIndexOf('.');

    if (index < 0 || index >= fileName.length - 1) {
      return '';
    }

    return fileName.substring(index + 1).toLowerCase();
  }

  String? _mimeTypeForExtension(String extension) => switch (extension) {
    'wav' => 'audio/wav',
    'mp3' => 'audio/mpeg',
    _ => null,
  };
}

final audioImportServiceProvider = Provider<AudioImportService>(
  (ref) => const AudioImportService(),
);
