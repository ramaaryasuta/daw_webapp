import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'flaudio_project_codec.dart';
import 'project_autosave.dart';
import 'project_dto.dart';

const _databaseName = 'fldaw';
const _databaseVersion = 1;
const _autosaveStore = 'autosave';
const _audioSourcesStore = 'audioSources';
const _currentAutosaveKey = 'current';

ProjectAutosaveStore createProjectAutosaveStore() =>
    IndexedDbProjectAutosaveStore();

class IndexedDbProjectAutosaveStore implements ProjectAutosaveStore {
  final Map<String, Uint8List> _knownSourceBytes = {};

  @override
  Future<void> saveDocument(FlaudioProjectDocument document) async {
    final database = await _openDatabase();
    try {
      // Source records are insert-if-missing. Normal arrangement and mixer
      // autosaves therefore never rewrite the retained WAV/MP3 payloads.
      for (final source in document.manifest.audioSources) {
        final bytes = document.audioBytesBySourceId[source.sourceId];
        if (bytes == null || bytes.length != source.size) {
          throw ProjectAutosaveException(
            'Audio source ${source.sourceId} is missing or incomplete.',
          );
        }
        await _putAudioIfMissing(database, source.sourceId, bytes);
      }

      final payload = jsonEncode({
        'schemaVersion': flaudioAutosaveSchemaVersion,
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'manifest': document.manifest.toJson(),
      });
      final transaction = database.transaction(
        _autosaveStore.toJS,
        'readwrite',
      );
      transaction
          .objectStore(_autosaveStore)
          .put(payload.toJS, _currentAutosaveKey.toJS);
      await _transactionComplete(transaction);
    } catch (error) {
      if (error is ProjectAutosaveException) rethrow;
      throw ProjectAutosaveException('IndexedDB autosave failed: $error');
    } finally {
      database.close();
    }
  }

  @override
  Future<AutosaveRecovery?> readRecovery() async {
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(_autosaveStore.toJS);
      final result = await _requestResult(
        transaction.objectStore(_autosaveStore).get(_currentAutosaveKey.toJS),
      );
      if (result == null || result.isUndefinedOrNull) {
        return null;
      }
      if (!result.isA<JSString>()) {
        throw const ProjectAutosaveException(
          'The autosave metadata record is corrupt.',
        );
      }
      final decoded = jsonDecode((result as JSString).toDart);
      if (decoded is! Map<String, Object?> ||
          decoded['schemaVersion'] != flaudioAutosaveSchemaVersion ||
          decoded['savedAt'] is! String ||
          decoded['manifest'] is! Map<String, Object?>) {
        throw const ProjectAutosaveException(
          'The autosave schema is invalid or unsupported.',
        );
      }
      final savedAt = DateTime.tryParse(decoded['savedAt']! as String);
      if (savedAt == null) {
        throw const ProjectAutosaveException(
          'The autosave timestamp is invalid.',
        );
      }
      return AutosaveRecovery(
        manifest: FlaudioProjectManifest.fromJson(
          decoded['manifest']! as Map<String, Object?>,
        ),
        savedAt: savedAt.toLocal(),
      );
    } catch (error) {
      if (error is ProjectAutosaveException || error is FlaudioProjectException) {
        rethrow;
      }
      throw ProjectAutosaveException('IndexedDB recovery check failed: $error');
    } finally {
      database.close();
    }
  }

  @override
  Future<FlaudioProjectDocument> loadDocument(AutosaveRecovery recovery) async {
    final database = await _openDatabase();
    try {
      final bytesBySourceId = <String, Uint8List>{};
      for (final source in recovery.manifest.audioSources) {
        final transaction = database.transaction(_audioSourcesStore.toJS);
        final result = await _requestResult(
          transaction.objectStore(_audioSourcesStore).get(source.sourceId.toJS),
        );
        if (result == null || result.isUndefinedOrNull) {
          throw ProjectAutosaveException(
            'Required audio source "${source.displayFilename}" is missing.',
          );
        }
        Uint8List bytes;
        if (result.isA<JSUint8Array>()) {
          bytes = Uint8List.fromList((result as JSUint8Array).toDart);
        } else if (result.isA<JSArrayBuffer>()) {
          bytes = Uint8List.fromList(
            (result as JSArrayBuffer).toDart.asUint8List(),
          );
        } else {
          throw ProjectAutosaveException(
            'Audio source "${source.displayFilename}" is corrupt.',
          );
        }
        if (bytes.length != source.size) {
          throw ProjectAutosaveException(
            'Audio source "${source.displayFilename}" is incomplete.',
          );
        }
        bytesBySourceId[source.sourceId] = bytes;
      }
      return FlaudioProjectDocument(
        manifest: recovery.manifest,
        audioBytesBySourceId: Map.unmodifiable(bytesBySourceId),
      );
    } catch (error) {
      if (error is ProjectAutosaveException) rethrow;
      throw ProjectAutosaveException('IndexedDB recovery failed: $error');
    } finally {
      database.close();
    }
  }

  @override
  Future<void> discardRecovery() async {
    final database = await _openDatabase();
    try {
      final transaction = database.transaction(
        _autosaveStore.toJS,
        'readwrite',
      );
      transaction.objectStore(_autosaveStore).delete(_currentAutosaveKey.toJS);
      await _transactionComplete(transaction);
      // V1 intentionally retains source records. A later successful autosave
      // can reuse them, and conservative retention avoids deleting bytes still
      // used by the active in-memory project.
    } finally {
      database.close();
    }
  }

  Future<void> _putAudioIfMissing(
    web.IDBDatabase database,
    String sourceId,
    Uint8List bytes,
  ) async {
    if (identical(_knownSourceBytes[sourceId], bytes)) return;
    final transaction = database.transaction(
      _audioSourcesStore.toJS,
      'readwrite',
    );
    final store = transaction.objectStore(_audioSourcesStore);
    final request = store.get(sourceId.toJS);
    final completer = Completer<void>();
    request.onsuccess = ((web.Event _) {
      try {
        final current = request.result;
        if (current == null ||
            current.isUndefinedOrNull ||
            !_storedBytesMatch(current, bytes)) {
          store.put(bytes.toJS, sourceId.toJS);
        }
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        transaction.abort();
      }
    }).toJS;
    _completeFromTransaction(transaction, completer);
    await completer.future;
    _knownSourceBytes[sourceId] = bytes;
  }

  Future<web.IDBDatabase> _openDatabase() {
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_databaseName, _databaseVersion);
    request.onupgradeneeded = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(_autosaveStore)) {
        database.createObjectStore(_autosaveStore);
      }
      if (!database.objectStoreNames.contains(_audioSourcesStore)) {
        database.createObjectStore(_audioSourcesStore);
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.complete(request.result as web.IDBDatabase);
      }
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          ProjectAutosaveException(
            request.error?.message ?? 'IndexedDB is unavailable.',
          ),
        );
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          const ProjectAutosaveException(
            'IndexedDB is blocked by another Flaudio tab.',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }
}

bool _storedBytesMatch(JSAny stored, Uint8List expected) {
  Uint8List current;
  if (stored.isA<JSUint8Array>()) {
    current = (stored as JSUint8Array).toDart;
  } else if (stored.isA<JSArrayBuffer>()) {
    current = (stored as JSArrayBuffer).toDart.asUint8List();
  } else {
    return false;
  }
  if (current.length != expected.length) return false;
  for (var index = 0; index < current.length; index++) {
    if (current[index] != expected[index]) return false;
  }
  return true;
}

Future<JSAny?> _requestResult(web.IDBRequest request) {
  final completer = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) {
    if (!completer.isCompleted) completer.complete(request.result);
  }).toJS;
  request.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        ProjectAutosaveException(
          request.error?.message ?? 'IndexedDB request failed.',
        ),
      );
    }
  }).toJS;
  return completer.future;
}

Future<void> _transactionComplete(web.IDBTransaction transaction) {
  final completer = Completer<void>();
  _completeFromTransaction(transaction, completer);
  return completer.future;
}

void _completeFromTransaction(
  web.IDBTransaction transaction,
  Completer<void> completer,
) {
  transaction.oncomplete = ((web.Event _) {
    if (!completer.isCompleted) completer.complete();
  }).toJS;
  transaction.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        ProjectAutosaveException(
          transaction.error?.message ?? 'IndexedDB transaction failed.',
        ),
      );
    }
  }).toJS;
  transaction.onabort = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        ProjectAutosaveException(
          transaction.error?.message ?? 'IndexedDB transaction was aborted.',
        ),
      );
    }
  }).toJS;
}
