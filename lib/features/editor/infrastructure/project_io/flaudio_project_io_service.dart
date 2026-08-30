import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_project_download.dart';
import 'flaudio_project_archive.dart';
import 'flaudio_project_codec.dart';
import 'project_dto.dart';

class PickedFlaudioProject {
  const PickedFlaudioProject({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class FlaudioProjectIoService {
  const FlaudioProjectIoService({
    this.codec = const FlaudioProjectCodec(),
    this.archive = const FlaudioProjectArchive(),
  });

  final FlaudioProjectCodec codec;
  final FlaudioProjectArchive archive;

  Future<PickedFlaudioProject?> pickProjectFile() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const [flaudioProjectFormat],
    );
    if (selected == null) {
      return null;
    }
    return PickedFlaudioProject(
      name: selected.name,
      bytes: await selected.readAsBytes(),
    );
  }

  Uint8List packageProject(FlaudioProjectSnapshot snapshot) {
    return archive.encode(codec.encodeSnapshot(snapshot));
  }

  FlaudioProjectDocument readProject(Uint8List bytes) => archive.decode(bytes);

  void downloadProject(Uint8List bytes, {required String projectName}) {
    downloadFlaudioProject(bytes, projectDownloadName(projectName));
  }
}

String projectDownloadName(String projectName) {
  var name = projectName.trim();
  while (name.toLowerCase().endsWith(projectFileExtension)) {
    name = name.substring(0, name.length - projectFileExtension.length);
  }
  name = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\.+'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) {
    name = 'Untitled';
  }
  if (name.length > 120) {
    name = name.substring(0, 120).trimRight();
  }
  return '$name$projectFileExtension';
}

final flaudioProjectIoServiceProvider = Provider<FlaudioProjectIoService>(
  (ref) => const FlaudioProjectIoService(),
);
