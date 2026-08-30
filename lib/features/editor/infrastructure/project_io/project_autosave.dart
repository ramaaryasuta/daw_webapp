import 'flaudio_project_codec.dart';
import 'project_dto.dart';

const int flaudioAutosaveSchemaVersion = 1;

class AutosaveRecovery {
  const AutosaveRecovery({required this.manifest, required this.savedAt});

  final FlaudioProjectManifest manifest;
  final DateTime savedAt;
}

abstract class ProjectAutosaveStore {
  Future<void> saveDocument(FlaudioProjectDocument document);

  Future<AutosaveRecovery?> readRecovery();

  Future<FlaudioProjectDocument> loadDocument(AutosaveRecovery recovery);

  Future<void> discardRecovery();
}

class ProjectAutosaveException implements Exception {
  const ProjectAutosaveException(this.message);

  final String message;

  @override
  String toString() => 'ProjectAutosaveException: $message';
}
