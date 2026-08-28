import 'fldaw_project_codec.dart';
import 'project_autosave.dart';

ProjectAutosaveStore createProjectAutosaveStore() =>
    const _UnsupportedProjectAutosaveStore();

class _UnsupportedProjectAutosaveStore implements ProjectAutosaveStore {
  const _UnsupportedProjectAutosaveStore();

  @override
  Future<void> discardRecovery() async {}

  @override
  Future<FldawProjectDocument> loadDocument(AutosaveRecovery recovery) =>
      throw const ProjectAutosaveException(
        'Browser-local recovery is only available on the web.',
      );

  @override
  Future<AutosaveRecovery?> readRecovery() async => null;

  @override
  Future<void> saveDocument(FldawProjectDocument document) async {}
}
