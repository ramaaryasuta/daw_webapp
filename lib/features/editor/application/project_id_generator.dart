import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Creates collision-resistant IDs for every persistent project entity.
///
/// Saved IDs are never passed through this service: Open and Recovery preserve
/// them exactly. UUID generation only happens when a new entity is created.
class ProjectIdGenerator {
  ProjectIdGenerator({Uuid uuid = const Uuid()}) : this._(uuid);

  ProjectIdGenerator._(this._uuid);

  final Uuid _uuid;
  final Set<String> _issuedIds = {};

  /// Retains restored IDs even if their entities are temporarily removed and
  /// can later return through Undo/Redo.
  void reserveIds(Iterable<String> ids) => _issuedIds.addAll(ids);

  String newTrackId({Iterable<String> reservedIds = const []}) =>
      _newId('track', reservedIds);
  String newClipId({Iterable<String> reservedIds = const []}) =>
      _newId('clip', reservedIds);
  String newSourceId({Iterable<String> reservedIds = const []}) =>
      _newId('source', reservedIds);
  String newMarkerId({Iterable<String> reservedIds = const []}) =>
      _newId('marker', reservedIds);
  String newSectionId({Iterable<String> reservedIds = const []}) =>
      _newId('section', reservedIds);

  String _newId(String namespace, Iterable<String> reservedIds) {
    final reserved = reservedIds.toSet();
    while (true) {
      final candidate = '$namespace-${_uuid.v4()}';
      if (!reserved.contains(candidate) && _issuedIds.add(candidate)) {
        return candidate;
      }
    }
  }
}

final projectIdGeneratorProvider = Provider<ProjectIdGenerator>(
  (ref) => ProjectIdGenerator(),
);
