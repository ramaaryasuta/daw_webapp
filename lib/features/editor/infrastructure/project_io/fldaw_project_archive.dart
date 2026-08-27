import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'fldaw_project_codec.dart';
import 'project_dto.dart';

const String fldawProjectManifestPath = 'project.json';

class FldawProjectArchive {
  const FldawProjectArchive();

  Uint8List encode(FldawProjectDocument document) {
    final archive = Archive()
      ..add(
        ArchiveFile.string(
          fldawProjectManifestPath,
          document.manifest.encodeJson(),
        ),
      );
    for (final source in document.manifest.audioSources) {
      final bytes = document.audioBytesBySourceId[source.sourceId];
      if (bytes == null) {
        throw FldawProjectException(
          'Missing bytes for source ${source.sourceId}.',
          userMessage:
              'One or more required audio sources could not be packaged.',
        );
      }
      // WAV/MP3 data is already compressed; storing it avoids costly and
      // usually counterproductive recompression and extra working memory.
      archive.add(
        ArchiveFile.noCompress(source.archivePath, bytes.length, bytes),
      );
    }
    return ZipEncoder().encodeBytes(archive);
  }

  FldawProjectDocument decode(Uint8List bytes) {
    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (error) {
      throw FldawProjectException(
        'Unable to decode ZIP container: $error',
        userMessage: 'The selected project file is invalid or corrupt.',
      );
    }

    final duplicatePaths = <String>{};
    final seenPaths = <String>{};
    for (final file in archive.files.where((entry) => entry.isFile)) {
      if (!seenPaths.add(file.name)) {
        duplicatePaths.add(file.name);
      }
    }
    if (duplicatePaths.isNotEmpty) {
      throw const FldawProjectException(
        'Archive contains duplicate entry paths.',
        userMessage: 'The selected project file is invalid or corrupt.',
      );
    }

    final manifestEntry = archive.find(fldawProjectManifestPath);
    if (manifestEntry == null || !manifestEntry.isFile) {
      throw const FldawProjectException(
        'Archive does not contain project.json.',
        userMessage: 'This file does not contain FLDAW project metadata.',
      );
    }
    if (manifestEntry.size > 4 * 1024 * 1024) {
      throw const FldawProjectException(
        'project.json exceeds the allowed size.',
        userMessage: 'The project metadata is invalid or corrupt.',
      );
    }

    FldawProjectManifest manifest;
    try {
      final manifestBytes = manifestEntry.readBytes();
      if (manifestBytes == null) {
        throw const FormatException('project.json has no readable content.');
      }
      manifest = FldawProjectManifest.decodeJson(
        utf8.decode(manifestBytes, allowMalformed: false),
      );
    } on FldawProjectException {
      rethrow;
    } catch (error) {
      throw FldawProjectException(
        'Unable to read project.json: $error',
        userMessage: 'The project metadata is invalid or corrupt.',
      );
    }

    final sourceBytes = <String, Uint8List>{};
    var totalAudioBytes = 0;
    for (final source in manifest.audioSources) {
      totalAudioBytes += source.size;
      if (source.size > 2 * 1024 * 1024 * 1024 ||
          totalAudioBytes > 2 * 1024 * 1024 * 1024) {
        throw const FldawProjectException(
          'Embedded audio exceeds the supported browser memory limit.',
          userMessage: 'This project is too large to open in the browser.',
        );
      }
      final entry = archive.find(source.archivePath);
      if (entry == null || !entry.isFile) {
        throw FldawProjectException(
          'Missing archive entry ${source.archivePath}.',
          userMessage:
              'One or more required audio sources could not be restored.',
        );
      }
      if (entry.size != source.size) {
        throw FldawProjectException(
          'Audio entry ${source.archivePath} has an unexpected size.',
          userMessage:
              'One or more required audio sources could not be restored.',
        );
      }
      final content = entry.readBytes();
      if (content == null || content.isEmpty || content.length != source.size) {
        throw FldawProjectException(
          'Audio entry ${source.archivePath} has an invalid size.',
          userMessage:
              'One or more required audio sources could not be restored.',
        );
      }
      sourceBytes[source.sourceId] = content;
    }
    return FldawProjectDocument(
      manifest: manifest,
      audioBytesBySourceId: Map.unmodifiable(sourceBytes),
    );
  }
}
