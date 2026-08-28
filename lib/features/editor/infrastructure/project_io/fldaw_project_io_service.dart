import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browser_project_download.dart';
import 'fldaw_project_archive.dart';
import 'fldaw_project_codec.dart';

class PickedFldawProject {
  const PickedFldawProject({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class FldawProjectIoService {
  const FldawProjectIoService({
    this.codec = const FldawProjectCodec(),
    this.archive = const FldawProjectArchive(),
  });

  final FldawProjectCodec codec;
  final FldawProjectArchive archive;

  Future<PickedFldawProject?> pickProjectFile() async {
    final selected = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['fldawproj'],
    );
    if (selected == null) {
      return null;
    }
    return PickedFldawProject(
      name: selected.name,
      bytes: await selected.readAsBytes(),
    );
  }

  Uint8List packageProject(FldawProjectSnapshot snapshot) {
    return archive.encode(codec.encodeSnapshot(snapshot));
  }

  FldawProjectDocument readProject(Uint8List bytes) => archive.decode(bytes);

  void downloadProject(Uint8List bytes, {required String projectName}) {
    downloadFldawProject(bytes, projectDownloadName(projectName));
  }
}

String projectDownloadName(String projectName) {
  var name = projectName.trim();
  while (name.toLowerCase().endsWith('.fldawproj')) {
    name = name.substring(0, name.length - '.fldawproj'.length);
  }
  name = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'\.{2,}'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (name.isEmpty) {
    name = 'Untitled';
  }
  if (name.length > 120) {
    name = name.substring(0, 120).trimRight();
  }
  return '$name.fldawproj';
}

final fldawProjectIoServiceProvider = Provider<FldawProjectIoService>(
  (ref) => const FldawProjectIoService(),
);
