import 'dart:convert';
import 'dart:typed_data';

import '../../domain/audio_asset.dart';
import '../../domain/audio_clip.dart';
import '../../domain/daw_track.dart';
import '../../domain/loop_region.dart';
import '../../domain/musical_timing.dart';
import '../../domain/snap_settings.dart';
import '../../domain/timeline_marker.dart';
import '../../presentation/models/timeline_ruler_mode.dart';
import 'project_dto.dart';

class FldawProjectSnapshot {
  const FldawProjectSnapshot({
    required this.name,
    required this.bpm,
    this.timeSignature = defaultTimeSignature,
    required this.snapSettings,
    required this.rulerMode,
    required this.isLoopEnabled,
    required this.loopRegion,
    required this.masterVolumeDb,
    required this.tracks,
    required this.markers,
  });

  final String name;
  final double bpm;
  final TimeSignature timeSignature;
  final SnapSettings snapSettings;
  final TimelineRulerMode rulerMode;
  final bool isLoopEnabled;
  final LoopRegion? loopRegion;
  final double masterVolumeDb;
  final List<DawTrack> tracks;
  final List<TimelineMarker> markers;

  int get retainedAudioByteCount {
    final seen = <String>{};
    var total = 0;
    for (final track in tracks) {
      for (final clip in track.clips) {
        if (seen.add(clip.audio.id)) {
          total += clip.audio.sourceBytes?.length ?? 0;
        }
      }
    }
    return total;
  }
}

class FldawProjectDocument {
  const FldawProjectDocument({
    required this.manifest,
    required this.audioBytesBySourceId,
  });

  final FldawProjectManifest manifest;
  final Map<String, Uint8List> audioBytesBySourceId;
}

class RestoredFldawProject {
  const RestoredFldawProject({
    required this.name,
    required this.bpm,
    this.timeSignature = defaultTimeSignature,
    required this.snapSettings,
    required this.rulerMode,
    required this.isLoopEnabled,
    required this.loopRegion,
    required this.masterVolumeDb,
    required this.tracks,
    required this.markers,
  });

  final String name;
  final double bpm;
  final TimeSignature timeSignature;
  final SnapSettings snapSettings;
  final TimelineRulerMode rulerMode;
  final bool isLoopEnabled;
  final LoopRegion? loopRegion;
  final double masterVolumeDb;
  final List<DawTrack> tracks;
  final List<TimelineMarker> markers;
}

class FldawProjectCodec {
  const FldawProjectCodec();

  FldawProjectDocument encodeSnapshot(FldawProjectSnapshot snapshot) {
    final assets = <String, AudioAsset>{};
    for (final track in snapshot.tracks) {
      for (final clip in track.clips) {
        final previous = assets[clip.audio.id];
        if (previous != null && !identical(previous, clip.audio)) {
          throw FldawProjectException(
            'Source ID ${clip.audio.id} is represented by multiple assets.',
            userMessage: 'The project contains conflicting audio sources.',
          );
        }
        assets[clip.audio.id] = clip.audio;
        if (clip.sourceEndSeconds > clip.audio.durationSeconds + 0.001) {
          throw FldawProjectException(
            'Clip ${clip.id} extends beyond source ${clip.audio.id}.',
            userMessage: 'The project contains an invalid audio clip.',
          );
        }
      }
    }

    final sourceDtos = <ProjectAudioSourceDto>[];
    final bytesBySourceId = <String, Uint8List>{};
    final usedPaths = <String>{};
    for (final asset in assets.values) {
      final bytes = asset.sourceBytes;
      if (bytes == null || bytes.isEmpty) {
        throw FldawProjectException(
          'Source ${asset.id} does not retain original bytes.',
          userMessage:
              'One or more audio sources cannot be packaged. Re-import the audio and try again.',
        );
      }
      final extension = _safeExtension(asset.extension);
      final archivePath = _uniqueArchivePath(asset.id, extension, usedPaths);
      bytesBySourceId[asset.id] = bytes;
      sourceDtos.add(
        ProjectAudioSourceDto(
          sourceId: asset.id,
          archivePath: archivePath,
          originalFilename: _displayFilename(asset.name),
          extension: extension,
          mimeType: asset.mimeType ?? _mimeTypeForExtension(extension),
          size: bytes.length,
          durationSeconds: asset.durationSeconds,
          sampleRate: asset.sampleRate,
          numberOfChannels: asset.numberOfChannels,
        ),
      );
    }

    final manifest = FldawProjectManifest(
      project: ProjectSettingsDto(
        name: _projectName(snapshot.name),
        bpm: snapshot.bpm,
        timeSignature: snapshot.timeSignature,
        snapEnabled: snapshot.snapSettings.enabled,
        snapSubdivision: snapshot.snapSettings.subdivision.name,
        rulerDisplayMode: snapshot.rulerMode.name,
        loopEnabled: snapshot.isLoopEnabled,
        loopStartSeconds: snapshot.loopRegion?.startSeconds,
        loopEndSeconds: snapshot.loopRegion?.endSeconds,
        masterVolumeDb: snapshot.masterVolumeDb,
      ),
      tracks: [
        for (var index = 0; index < snapshot.tracks.length; index++)
          ProjectTrackDto(
            id: snapshot.tracks[index].id,
            order: index,
            name: snapshot.tracks[index].name,
            colorArgb: snapshot.tracks[index].colorValue,
            volumeDb: snapshot.tracks[index].volumeDb,
            muted: snapshot.tracks[index].isMuted,
            solo: snapshot.tracks[index].isSolo,
            pan: snapshot.tracks[index].pan,
          ),
      ],
      clips: [
        for (final track in snapshot.tracks)
          for (var index = 0; index < track.clips.length; index++)
            ProjectClipDto(
              id: track.clips[index].id,
              trackId: track.id,
              order: index,
              sourceId: track.clips[index].audio.id,
              timelineStartSeconds: track.clips[index].timelineStartSeconds,
              sourceStartSeconds: track.clips[index].sourceStartSeconds,
              clipDurationSeconds: track.clips[index].clipDurationSeconds,
              gainDb: track.clips[index].gainDb,
              fadeInDurationSeconds: track.clips[index].fadeInDurationSeconds,
              fadeOutDurationSeconds: track.clips[index].fadeOutDurationSeconds,
            ),
      ],
      markers: [
        for (final marker in snapshot.markers)
          ProjectMarkerDto(
            id: marker.id,
            timeSeconds: marker.timeSeconds,
            name: marker.name,
            colorArgb: marker.colorArgb,
          ),
      ],
      audioSources: sourceDtos,
    );

    // Run the same strict validator used by Open before writing anything.
    final validated = FldawProjectManifest.fromJson(manifest.toJson());
    return FldawProjectDocument(
      manifest: validated,
      audioBytesBySourceId: Map.unmodifiable(bytesBySourceId),
    );
  }

  RestoredFldawProject restore(
    FldawProjectManifest manifest,
    Map<String, AudioAsset> assets,
  ) {
    final expectedSourceIds = manifest.audioSources
        .map((source) => source.sourceId)
        .toSet();
    if (assets.length != expectedSourceIds.length ||
        !assets.keys.toSet().containsAll(expectedSourceIds)) {
      throw const FldawProjectException(
        'Not all decoded audio assets were supplied.',
        userMessage:
            'One or more required audio sources could not be restored.',
      );
    }

    final clipDtosByTrack = <String, List<ProjectClipDto>>{};
    for (final clip in manifest.clips) {
      clipDtosByTrack.putIfAbsent(clip.trackId, () => []).add(clip);
    }
    for (final clips in clipDtosByTrack.values) {
      clips.sort((left, right) => left.order.compareTo(right.order));
    }
    final trackDtos = [...manifest.tracks]
      ..sort((left, right) => left.order.compareTo(right.order));
    final tracks = <DawTrack>[];
    for (final track in trackDtos) {
      final clips = <AudioClip>[];
      for (final clip in clipDtosByTrack[track.id] ?? const []) {
        final asset = assets[clip.sourceId]!;
        if (clip.sourceStartSeconds + clip.clipDurationSeconds >
            asset.durationSeconds + 0.001) {
          throw FldawProjectException(
            'Clip ${clip.id} extends beyond decoded source ${asset.id}.',
            userMessage: 'The project contains an invalid audio clip.',
          );
        }
        clips.add(
          AudioClip(
            id: clip.id,
            audio: asset,
            timelineStartSeconds: clip.timelineStartSeconds,
            sourceStartSeconds: clip.sourceStartSeconds,
            clipDurationSeconds: clip.clipDurationSeconds,
            gainDb: clip.gainDb,
            fadeInDurationSeconds: clip.fadeInDurationSeconds,
            fadeOutDurationSeconds: clip.fadeOutDurationSeconds,
          ),
        );
      }
      tracks.add(
        DawTrack(
          id: track.id,
          name: track.name,
          clips: List.unmodifiable(clips),
          colorValue: track.colorArgb,
          volumeDb: track.volumeDb,
          pan: track.pan,
          isMuted: track.muted,
          isSolo: track.solo,
        ),
      );
    }

    final settings = manifest.project;
    final loopRegion = settings.loopStartSeconds == null
        ? null
        : LoopRegion(
            startSeconds: settings.loopStartSeconds!,
            endSeconds: settings.loopEndSeconds!,
          );
    return RestoredFldawProject(
      name: settings.name,
      bpm: settings.bpm,
      timeSignature: settings.timeSignature,
      snapSettings: SnapSettings(
        enabled: settings.snapEnabled,
        subdivision: SnapSubdivision.values.byName(settings.snapSubdivision),
      ),
      rulerMode: TimelineRulerMode.values.byName(settings.rulerDisplayMode),
      isLoopEnabled: settings.loopEnabled,
      loopRegion: loopRegion,
      masterVolumeDb: settings.masterVolumeDb,
      tracks: List.unmodifiable(tracks),
      markers: List.unmodifiable([
        for (final marker in manifest.markers)
          TimelineMarker(
            id: marker.id,
            timeSeconds: marker.timeSeconds,
            name: marker.name,
            colorArgb: marker.colorArgb,
          ),
      ]),
    );
  }
}

String _safeExtension(String extension) {
  final normalized = extension.toLowerCase().replaceFirst('.', '');
  if (!const {'wav', 'mp3'}.contains(normalized)) {
    throw FldawProjectException(
      'Unsupported source extension: $extension.',
      userMessage: 'The project contains an unsupported audio source.',
    );
  }
  return normalized;
}

String _uniqueArchivePath(
  String sourceId,
  String extension,
  Set<String> usedPaths,
) {
  final safeId = RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(sourceId)
      ? sourceId
      : 'source_${_stableIdHash(utf8.encode(sourceId))}';
  var path = 'audio/$safeId.$extension';
  if (!usedPaths.add(path)) {
    path = 'audio/${safeId}_${_stableIdHash(utf8.encode(sourceId))}.$extension';
    if (!usedPaths.add(path)) {
      throw const FldawProjectException(
        'Unable to create unique source archive paths.',
        userMessage: 'The project contains conflicting audio sources.',
      );
    }
  }
  return path;
}

String _stableIdHash(List<int> bytes) {
  // Two small polynomial hashes stay exactly representable by dart2js while
  // producing a deterministic, path-safe suffix for unusual source IDs.
  var first = 17;
  var second = 5381;
  for (final byte in bytes) {
    first = ((first * 31) + byte) & 0x7fffffff;
    second = ((second * 33) + byte) & 0x7fffffff;
  }
  return '${first.toRadixString(16).padLeft(8, '0')}'
      '${second.toRadixString(16).padLeft(8, '0')}';
}

String _displayFilename(String name) {
  final normalized = name.replaceAll('\\', '/').split('/').last.trim();
  return normalized.isEmpty ? 'audio' : normalized;
}

String _projectName(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'Untitled' : trimmed;
}

String? _mimeTypeForExtension(String extension) => switch (extension) {
  'wav' => 'audio/wav',
  'mp3' => 'audio/mpeg',
  _ => null,
};
