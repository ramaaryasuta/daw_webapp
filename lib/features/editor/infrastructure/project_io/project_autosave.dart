import 'fldaw_project_codec.dart';
import 'project_dto.dart';

const int fldawAutosaveSchemaVersion = 1;

class AutosaveRecovery {
  const AutosaveRecovery({required this.manifest, required this.savedAt});

  final FldawProjectManifest manifest;
  final DateTime savedAt;
}

abstract class ProjectAutosaveStore {
  Future<void> saveDocument(FldawProjectDocument document);

  Future<AutosaveRecovery?> readRecovery();

  Future<FldawProjectDocument> loadDocument(AutosaveRecovery recovery);

  Future<void> discardRecovery();
}

class ProjectAutosaveException implements Exception {
  const ProjectAutosaveException(this.message);

  final String message;

  @override
  String toString() => 'ProjectAutosaveException: $message';
}
