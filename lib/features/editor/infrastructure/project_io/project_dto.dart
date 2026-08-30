import 'dart:convert';

import '../../domain/musical_timing.dart';
import '../../domain/master_limiter.dart';
import '../../domain/track_filter_fx.dart';
import '../../domain/track_eq_fx.dart';
import '../../domain/track_compressor_fx.dart';
import '../../domain/track_delay_fx.dart';
import '../../domain/track_reverb_fx.dart';
import '../../domain/track_fx_chain.dart';

const String flaudioProjectFormat = 'flaudioproject';
const String projectFileExtension = '.$flaudioProjectFormat';
const int flaudioProjectFormatVersion = 1;

class FlaudioProjectException implements Exception {
  const FlaudioProjectException(this.message, {required this.userMessage});

  final String message;
  final String userMessage;

  @override
  String toString() => 'FlaudioProjectException: $message';
}

class FlaudioProjectManifest {
  const FlaudioProjectManifest({
    required this.project,
    required this.tracks,
    required this.clips,
    required this.markers,
    this.sections = const [],
    required this.audioSources,
  });

  final ProjectSettingsDto project;
  final List<ProjectTrackDto> tracks;
  final List<ProjectClipDto> clips;
  final List<ProjectMarkerDto> markers;
  final List<ProjectSectionDto> sections;
  final List<ProjectAudioSourceDto> audioSources;

  Map<String, Object?> toJson() => {
    'format': flaudioProjectFormat,
    'formatVersion': flaudioProjectFormatVersion,
    'project': project.toJson(),
    'tracks': [for (final track in tracks) track.toJson()],
    'clips': [for (final clip in clips) clip.toJson()],
    'markers': [for (final marker in markers) marker.toJson()],
    'sections': [for (final section in sections) section.toJson()],
    'audioSources': [for (final source in audioSources) source.toJson()],
  };

  String encodeJson() => jsonEncode(toJson());

  factory FlaudioProjectManifest.decodeJson(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw FlaudioProjectException(
        'project.json is not valid JSON: $error',
        userMessage: 'The project metadata is invalid or corrupt.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const FlaudioProjectException(
        'project.json root must be an object.',
        userMessage: 'The project metadata is invalid or corrupt.',
      );
    }
    return FlaudioProjectManifest.fromJson(decoded);
  }

  factory FlaudioProjectManifest.fromJson(Map<String, Object?> json) {
    final format = _requiredString(json, 'format');
    if (format != flaudioProjectFormat) {
      throw const FlaudioProjectException(
        'Manifest format identifier is invalid.',
        userMessage: 'This file is not a valid Flaudio project.',
      );
    }
    final version = _requiredInt(json, 'formatVersion');
    if (version > flaudioProjectFormatVersion) {
      throw const FlaudioProjectException(
        'Manifest uses a newer format version.',
        userMessage:
            'This project was created with a newer Flaudio project format.',
      );
    }
    if (version != flaudioProjectFormatVersion) {
      throw FlaudioProjectException(
        'Unsupported format version: $version.',
        userMessage: 'This Flaudio project format is not supported.',
      );
    }

    final manifest = FlaudioProjectManifest(
      project: ProjectSettingsDto.fromJson(_requiredMap(json, 'project')),
      tracks: _objectList(json, 'tracks', ProjectTrackDto.fromJson),
      clips: _objectList(json, 'clips', ProjectClipDto.fromJson),
      markers: _objectList(json, 'markers', ProjectMarkerDto.fromJson),
      sections: _optionalObjectList(
        json,
        'sections',
        ProjectSectionDto.fromJson,
      ),
      audioSources: _objectList(
        json,
        'audioSources',
        ProjectAudioSourceDto.fromJson,
      ),
    );
    manifest.validateIntegrity();
    return manifest;
  }

  /// Performs the full persistent-identity and reference audit used by Save,
  /// archive Open, and IndexedDB Recovery.
  void validateIntegrity() {
    _requireUniqueObjectIds(tracks.map((track) => track.id), 'track ID');
    _requireUniqueObjectIds(clips.map((clip) => clip.id), 'clip ID');
    _requireUniqueObjectIds(markers.map((marker) => marker.id), 'marker ID');
    _requireUniqueObjectIds(
      sections.map((section) => section.id),
      'section ID',
    );
    _requireUniqueObjectIds(
      audioSources.map((source) => source.sourceId),
      'source ID',
    );
    _requireUnique(
      audioSources.map((source) => source.archivePath),
      'audio archive path',
    );
    _requireContiguousOrder(tracks.map((track) => track.order), 'track');

    final trackIds = tracks.map((track) => track.id).toSet();
    final sourceIds = audioSources.map((source) => source.sourceId).toSet();
    final clipOrdersByTrack = <String, List<int>>{};
    for (final clip in clips) {
      if (!trackIds.contains(clip.trackId)) {
        _invalid('Clip ${clip.id} references an unknown track.');
      }
      if (!sourceIds.contains(clip.sourceId)) {
        _invalid('Clip ${clip.id} references an unknown audio source.');
      }
      clipOrdersByTrack.putIfAbsent(clip.trackId, () => []).add(clip.order);
    }
    for (final entry in clipOrdersByTrack.entries) {
      _requireContiguousOrder(entry.value, 'clip in track ${entry.key}');
    }

    final usedSourceIds = clips.map((clip) => clip.sourceId).toSet();
    if (!sourceIds.containsAll(usedSourceIds)) {
      _invalid('One or more used audio sources are missing.');
    }
  }
}

class ProjectSettingsDto {
  const ProjectSettingsDto({
    required this.name,
    required this.bpm,
    this.timeSignature = defaultTimeSignature,
    required this.snapEnabled,
    required this.snapSubdivision,
    required this.rulerDisplayMode,
    required this.loopEnabled,
    required this.loopStartSeconds,
    required this.loopEndSeconds,
    required this.masterVolumeDb,
    this.masterLimiter = const MasterLimiterSettings(),
  });

  final String name;
  final double bpm;
  final TimeSignature timeSignature;
  final bool snapEnabled;
  final String snapSubdivision;
  final String rulerDisplayMode;
  final bool loopEnabled;
  final double? loopStartSeconds;
  final double? loopEndSeconds;
  final double masterVolumeDb;
  final MasterLimiterSettings masterLimiter;

  Map<String, Object?> toJson() => {
    'name': name,
    'bpm': bpm,
    'timeSignature': {
      'numerator': timeSignature.numerator,
      'denominator': timeSignature.denominator,
    },
    'snap': {'enabled': snapEnabled, 'subdivision': snapSubdivision},
    'rulerDisplayMode': rulerDisplayMode,
    'loop': {
      'enabled': loopEnabled,
      if (loopStartSeconds != null && loopEndSeconds != null) ...{
        'startSeconds': loopStartSeconds,
        'endSeconds': loopEndSeconds,
      },
    },
    'masterVolumeDb': masterVolumeDb,
    'masterLimiter': {
      'enabled': masterLimiter.enabled,
      'thresholdDb': masterLimiter.thresholdDb,
      'ceilingDb': masterLimiter.ceilingDb,
      'releaseSeconds': masterLimiter.releaseSeconds,
    },
  };

  factory ProjectSettingsDto.fromJson(Map<String, Object?> json) {
    final name = _requiredString(json, 'name');
    final bpm = _finiteNumber(json, 'bpm');
    final timeSignature = _timeSignature(json);
    final snap = _requiredMap(json, 'snap');
    final subdivision = _requiredString(snap, 'subdivision');
    if (!const {
      'bar',
      'beat',
      'halfBeat',
      'quarterBeat',
      'eighthBeat',
    }.contains(subdivision)) {
      _invalid('Unknown snap subdivision: $subdivision.');
    }
    final rulerMode = _requiredString(json, 'rulerDisplayMode');
    if (!const {'barsBeats', 'time'}.contains(rulerMode)) {
      _invalid('Unknown ruler display mode: $rulerMode.');
    }
    final loop = _requiredMap(json, 'loop');
    final loopEnabled = _requiredBool(loop, 'enabled');
    final hasLoopStart = loop.containsKey('startSeconds');
    final hasLoopEnd = loop.containsKey('endSeconds');
    if (hasLoopStart != hasLoopEnd) {
      _invalid('Loop region must contain both boundaries.');
    }
    final loopStart = hasLoopStart ? _finiteNumber(loop, 'startSeconds') : null;
    final loopEnd = hasLoopEnd ? _finiteNumber(loop, 'endSeconds') : null;
    if (loopStart != null && (loopStart < 0 || loopEnd! <= loopStart)) {
      _invalid('Loop region is invalid.');
    }
    if (loopEnabled && loopStart == null) {
      _invalid('An enabled loop requires a region.');
    }
    if (bpm < 20 || bpm > 300) {
      _invalid('BPM is outside the supported range.');
    }
    final limiterJson = json['masterLimiter'];
    final masterLimiter = limiterJson == null
        ? const MasterLimiterSettings()
        : _masterLimiterSettings(limiterJson);
    return ProjectSettingsDto(
      name: name,
      bpm: bpm,
      timeSignature: timeSignature,
      snapEnabled: _requiredBool(snap, 'enabled'),
      snapSubdivision: subdivision,
      rulerDisplayMode: rulerMode,
      loopEnabled: loopEnabled,
      loopStartSeconds: loopStart,
      loopEndSeconds: loopEnd,
      masterVolumeDb: _boundedNumber(json, 'masterVolumeDb', -60, 6),
      masterLimiter: masterLimiter,
    );
  }
}

MasterLimiterSettings _masterLimiterSettings(Object? value) {
  if (value is! Map<String, Object?>) {
    _invalid('masterLimiter must be an object.');
  }
  return MasterLimiterSettings(
    enabled: _requiredBool(value, 'enabled'),
    thresholdDb: _boundedNumber(
      value,
      'thresholdDb',
      minimumMasterLimiterThresholdDb,
      maximumMasterLimiterThresholdDb,
    ),
    ceilingDb: _boundedNumber(
      value,
      'ceilingDb',
      minimumMasterLimiterCeilingDb,
      maximumMasterLimiterCeilingDb,
    ),
    releaseSeconds: _boundedNumber(
      value,
      'releaseSeconds',
      minimumMasterLimiterReleaseSeconds,
      maximumMasterLimiterReleaseSeconds,
    ),
  );
}

TimeSignature _timeSignature(Map<String, Object?> json) {
  final value = json['timeSignature'];
  if (value == null) {
    return defaultTimeSignature;
  }
  if (value is! Map<String, Object?>) {
    _invalid('timeSignature must be an object.');
  }
  final numerator = _requiredInt(value, 'numerator');
  final denominator = _requiredInt(value, 'denominator');
  if (numerator <= 0 || denominator <= 0) {
    _invalid('Time signature values must be positive.');
  }
  final signature = TimeSignature(
    numerator: numerator,
    denominator: denominator,
  );
  if (!signature.isSupported) {
    _invalid('Unsupported time signature: ${signature.label}.');
  }
  return signature;
}

class ProjectTrackDto {
  const ProjectTrackDto({
    required this.id,
    required this.order,
    required this.name,
    required this.colorArgb,
    required this.volumeDb,
    required this.muted,
    required this.solo,
    required this.pan,
    this.filterFx = const TrackFilterFx(),
    this.eqFx = const TrackEqFx(),
    this.compressorFx = const TrackCompressorFx(),
    this.delayFx = const TrackDelayFx(),
    this.reverbFx = const TrackReverbFx(),
    this.fxChainOrder = defaultTrackFxChainOrder,
  });

  final String id;
  final int order;
  final String name;
  final int colorArgb;
  final double volumeDb;
  final bool muted;
  final bool solo;
  final double pan;
  final TrackFilterFx filterFx;
  final TrackEqFx eqFx;
  final TrackCompressorFx compressorFx;
  final TrackDelayFx delayFx;
  final TrackReverbFx reverbFx;
  final List<TrackFxType> fxChainOrder;

  Map<String, Object?> toJson() => {
    'id': id,
    'order': order,
    'name': name,
    'colorArgb': colorArgb,
    'volumeDb': volumeDb,
    'mute': muted,
    'solo': solo,
    'pan': pan,
    'fxChainOrder': [for (final effect in fxChainOrder) effect.name],
    'filterFx': {
      'enabled': filterFx.enabled,
      'highPass': {
        'enabled': filterFx.highPass.enabled,
        'frequencyHz': filterFx.highPass.frequencyHz,
        'q': filterFx.highPass.q,
      },
      'lowPass': {
        'enabled': filterFx.lowPass.enabled,
        'frequencyHz': filterFx.lowPass.frequencyHz,
        'q': filterFx.lowPass.q,
      },
    },
    'eq': {
      'enabled': eqFx.enabled,
      'lowGainDb': eqFx.lowGainDb,
      'midGainDb': eqFx.midGainDb,
      'midFrequencyHz': eqFx.midFrequencyHz,
      'midQ': eqFx.midQ,
      'highGainDb': eqFx.highGainDb,
    },
    'compressorFx': {
      'enabled': compressorFx.enabled,
      'thresholdDb': compressorFx.thresholdDb,
      'ratio': compressorFx.ratio,
      'attackSeconds': compressorFx.attackSeconds,
      'releaseSeconds': compressorFx.releaseSeconds,
      'makeupGainDb': compressorFx.makeupGainDb,
    },
    'delayFx': {
      'enabled': delayFx.enabled,
      'syncToBpm': delayFx.syncToBpm,
      'timeSeconds': delayFx.timeSeconds,
      'syncDivision': delayFx.syncDivision.name,
      'feedback': delayFx.feedback,
      'mix': delayFx.mix,
    },
    'reverbFx': {
      'enabled': reverbFx.enabled,
      'preDelaySeconds': reverbFx.preDelaySeconds,
      'decaySeconds': reverbFx.decaySeconds,
      'dampingHz': reverbFx.dampingHz,
      'mix': reverbFx.mix,
    },
  };

  factory ProjectTrackDto.fromJson(Map<String, Object?> json) =>
      ProjectTrackDto(
        id: _nonEmptyId(json, 'id'),
        order: _nonNegativeInt(json, 'order'),
        name: _requiredString(json, 'name'),
        colorArgb: _argb(json, 'colorArgb'),
        volumeDb: _boundedNumber(json, 'volumeDb', -60, 6),
        muted: _requiredBool(json, 'mute'),
        solo: _requiredBool(json, 'solo'),
        pan: _boundedNumber(json, 'pan', -1, 1),
        fxChainOrder: _trackFxChainOrder(json),
        filterFx: _trackFilterFx(json),
        eqFx: _trackEqFx(json),
        compressorFx: _trackCompressorFx(json),
        delayFx: _trackDelayFx(json),
        reverbFx: _trackReverbFx(json),
      );
}

List<TrackFxType> _trackFxChainOrder(Map<String, Object?> trackJson) {
  if (!trackJson.containsKey('fxChainOrder')) {
    return defaultTrackFxChainOrder;
  }
  final value = trackJson['fxChainOrder'];
  if (value is! List<Object?>) {
    _invalid('fxChainOrder must be a list.');
  }
  final order = <TrackFxType>[];
  for (final item in value) {
    if (item is! String) {
      _invalid('fxChainOrder contains a non-string value.');
    }
    final effect = TrackFxType.values
        .where((candidate) => candidate.name == item)
        .firstOrNull;
    if (effect == null) {
      _invalid('Unknown Track FX type: $item.');
    }
    order.add(effect);
  }
  final uniqueOrder = order.toSet();
  final hasStableCore = uniqueOrder.containsAll(const [
    TrackFxType.filter,
    TrackFxType.eq,
    TrackFxType.compressor,
  ]);
  if (uniqueOrder.length != order.length || !hasStableCore) {
    _invalid('fxChainOrder must contain each built-in effect exactly once.');
  }
  if (!uniqueOrder.contains(TrackFxType.delay)) {
    order.add(TrackFxType.delay);
  }
  if (!uniqueOrder.contains(TrackFxType.reverb)) {
    order.add(TrackFxType.reverb);
  }
  if (!isValidTrackFxChainOrder(order)) {
    _invalid('fxChainOrder must contain each built-in effect exactly once.');
  }
  return List<TrackFxType>.unmodifiable(order);
}

TrackReverbFx _trackReverbFx(Map<String, Object?> trackJson) {
  if (!trackJson.containsKey('reverbFx')) {
    return const TrackReverbFx();
  }
  final json = _requiredMap(trackJson, 'reverbFx');
  return TrackReverbFx(
    enabled: _requiredBool(json, 'enabled'),
    preDelaySeconds: _boundedNumber(
      json,
      'preDelaySeconds',
      minimumReverbPreDelaySeconds,
      maximumReverbPreDelaySeconds,
    ),
    decaySeconds: _boundedNumber(
      json,
      'decaySeconds',
      minimumReverbDecaySeconds,
      maximumReverbDecaySeconds,
    ),
    dampingHz: _boundedNumber(
      json,
      'dampingHz',
      minimumReverbDampingHz,
      maximumReverbDampingHz,
    ),
    mix: _boundedNumber(json, 'mix', minimumReverbMix, maximumReverbMix),
  );
}

TrackDelayFx _trackDelayFx(Map<String, Object?> trackJson) {
  if (!trackJson.containsKey('delayFx')) {
    return const TrackDelayFx();
  }
  final json = _requiredMap(trackJson, 'delayFx');
  final divisionName = _requiredString(json, 'syncDivision');
  final division = DelaySyncDivision.values
      .where((candidate) => candidate.name == divisionName)
      .firstOrNull;
  if (division == null) {
    _invalid('Unknown Delay sync division: $divisionName.');
  }
  return TrackDelayFx(
    enabled: _requiredBool(json, 'enabled'),
    syncToBpm: _requiredBool(json, 'syncToBpm'),
    timeSeconds: _boundedNumber(
      json,
      'timeSeconds',
      minimumDelayTimeSeconds,
      maximumDelayTimeSeconds,
    ),
    syncDivision: division,
    feedback: _boundedNumber(
      json,
      'feedback',
      minimumDelayFeedback,
      maximumDelayFeedback,
    ),
    mix: _boundedNumber(json, 'mix', minimumDelayMix, maximumDelayMix),
  );
}

TrackCompressorFx _trackCompressorFx(Map<String, Object?> trackJson) {
  if (!trackJson.containsKey('compressorFx')) {
    return const TrackCompressorFx();
  }
  final json = _requiredMap(trackJson, 'compressorFx');
  return TrackCompressorFx(
    enabled: _requiredBool(json, 'enabled'),
    thresholdDb: _boundedNumber(
      json,
      'thresholdDb',
      minimumCompressorThresholdDb,
      maximumCompressorThresholdDb,
    ),
    ratio: _boundedNumber(
      json,
      'ratio',
      minimumCompressorRatio,
      maximumCompressorRatio,
    ),
    attackSeconds: _boundedNumber(
      json,
      'attackSeconds',
      minimumCompressorAttackSeconds,
      maximumCompressorAttackSeconds,
    ),
    releaseSeconds: _boundedNumber(
      json,
      'releaseSeconds',
      minimumCompressorReleaseSeconds,
      maximumCompressorReleaseSeconds,
    ),
    makeupGainDb: _boundedNumber(
      json,
      'makeupGainDb',
      minimumCompressorMakeupGainDb,
      maximumCompressorMakeupGainDb,
    ),
  );
}

TrackEqFx _trackEqFx(Map<String, Object?> trackJson) {
  if (!trackJson.containsKey('eq')) return const TrackEqFx();
  final json = _requiredMap(trackJson, 'eq');
  return TrackEqFx(
    enabled: _requiredBool(json, 'enabled'),
    lowGainDb: _boundedNumber(
      json,
      'lowGainDb',
      minimumEqGainDb,
      maximumEqGainDb,
    ),
    midGainDb: _boundedNumber(
      json,
      'midGainDb',
      minimumEqGainDb,
      maximumEqGainDb,
    ),
    midFrequencyHz: _boundedNumber(
      json,
      'midFrequencyHz',
      minimumEqMidFrequencyHz,
      maximumEqMidFrequencyHz,
    ),
    midQ: _boundedNumber(json, 'midQ', minimumEqMidQ, maximumEqMidQ),
    highGainDb: _boundedNumber(
      json,
      'highGainDb',
      minimumEqGainDb,
      maximumEqGainDb,
    ),
  );
}

TrackFilterFx _trackFilterFx(Map<String, Object?> trackJson) {
  if (!trackJson.containsKey('filterFx')) {
    return const TrackFilterFx();
  }
  final json = _requiredMap(trackJson, 'filterFx');
  final highPass = _requiredMap(json, 'highPass');
  final lowPass = _requiredMap(json, 'lowPass');
  return TrackFilterFx(
    enabled: _requiredBool(json, 'enabled'),
    highPass: TrackFilterModule(
      enabled: _requiredBool(highPass, 'enabled'),
      frequencyHz: _boundedNumber(
        highPass,
        'frequencyHz',
        minimumFilterFrequencyHz,
        maximumFilterFrequencyHz,
      ),
      q: _boundedNumber(highPass, 'q', minimumFilterQ, maximumFilterQ),
    ),
    lowPass: TrackFilterModule(
      enabled: _requiredBool(lowPass, 'enabled'),
      frequencyHz: _boundedNumber(
        lowPass,
        'frequencyHz',
        minimumFilterFrequencyHz,
        maximumFilterFrequencyHz,
      ),
      q: _boundedNumber(lowPass, 'q', minimumFilterQ, maximumFilterQ),
    ),
  );
}

class ProjectClipDto {
  const ProjectClipDto({
    required this.id,
    required this.trackId,
    required this.order,
    required this.sourceId,
    required this.timelineStartSeconds,
    required this.sourceStartSeconds,
    required this.clipDurationSeconds,
    required this.gainDb,
    required this.fadeInDurationSeconds,
    required this.fadeOutDurationSeconds,
    this.isReversed = false,
  });

  final String id;
  final String trackId;
  final int order;
  final String sourceId;
  final double timelineStartSeconds;
  final double sourceStartSeconds;
  final double clipDurationSeconds;
  final double gainDb;
  final double fadeInDurationSeconds;
  final double fadeOutDurationSeconds;
  final bool isReversed;

  Map<String, Object?> toJson() => {
    'id': id,
    'trackId': trackId,
    'order': order,
    'sourceId': sourceId,
    'timelineStartSeconds': timelineStartSeconds,
    'sourceStartSeconds': sourceStartSeconds,
    'clipDurationSeconds': clipDurationSeconds,
    'gainDb': gainDb,
    'fadeInDurationSeconds': fadeInDurationSeconds,
    'fadeOutDurationSeconds': fadeOutDurationSeconds,
    'isReversed': isReversed,
  };

  factory ProjectClipDto.fromJson(Map<String, Object?> json) {
    final timelineStart = _nonNegativeNumber(json, 'timelineStartSeconds');
    final sourceStart = _nonNegativeNumber(json, 'sourceStartSeconds');
    final duration = _positiveNumber(json, 'clipDurationSeconds');
    final fadeIn = _nonNegativeNumber(json, 'fadeInDurationSeconds');
    final fadeOut = _nonNegativeNumber(json, 'fadeOutDurationSeconds');
    if (fadeIn + fadeOut > duration + 0.0000001) {
      _invalid('Clip fades exceed clip duration.');
    }
    return ProjectClipDto(
      id: _nonEmptyId(json, 'id'),
      trackId: _nonEmptyId(json, 'trackId'),
      order: _nonNegativeInt(json, 'order'),
      sourceId: _nonEmptyId(json, 'sourceId'),
      timelineStartSeconds: timelineStart,
      sourceStartSeconds: sourceStart,
      clipDurationSeconds: duration,
      gainDb: _boundedNumber(json, 'gainDb', -24, 12),
      fadeInDurationSeconds: fadeIn,
      fadeOutDurationSeconds: fadeOut,
      isReversed: _optionalBool(json, 'isReversed', fallback: false),
    );
  }
}

class ProjectMarkerDto {
  const ProjectMarkerDto({
    required this.id,
    required this.timeSeconds,
    required this.name,
    required this.colorArgb,
  });

  final String id;
  final double timeSeconds;
  final String name;
  final int colorArgb;

  Map<String, Object?> toJson() => {
    'id': id,
    'timeSeconds': timeSeconds,
    'name': name,
    'colorArgb': colorArgb,
  };

  factory ProjectMarkerDto.fromJson(Map<String, Object?> json) =>
      ProjectMarkerDto(
        id: _nonEmptyId(json, 'id'),
        timeSeconds: _nonNegativeNumber(json, 'timeSeconds'),
        name: _requiredString(json, 'name'),
        colorArgb: _argb(json, 'colorArgb'),
      );
}

class ProjectSectionDto {
  const ProjectSectionDto({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.name,
    required this.colorArgb,
  });

  final String id;
  final double startTime;
  final double endTime;
  final String name;
  final int colorArgb;

  Map<String, Object?> toJson() => {
    'id': id,
    'startTime': startTime,
    'endTime': endTime,
    'name': name,
    'colorArgb': colorArgb,
  };

  factory ProjectSectionDto.fromJson(Map<String, Object?> json) {
    final startTime = _nonNegativeNumber(json, 'startTime');
    final endTime = _positiveNumber(json, 'endTime');
    if (endTime <= startTime) {
      _invalid('Section endTime must be greater than startTime.');
    }
    return ProjectSectionDto(
      id: _nonEmptyId(json, 'id'),
      startTime: startTime,
      endTime: endTime,
      name: _requiredString(json, 'name'),
      colorArgb: _argb(json, 'colorArgb'),
    );
  }
}

class ProjectAudioSourceDto {
  const ProjectAudioSourceDto({
    required this.sourceId,
    required this.archivePath,
    required this.originalFilename,
    required this.extension,
    required this.mimeType,
    required this.size,
    required this.durationSeconds,
    required this.sampleRate,
    required this.numberOfChannels,
  });

  final String sourceId;
  final String archivePath;
  final String originalFilename;
  final String extension;
  final String? mimeType;
  final int size;
  final double durationSeconds;
  final double sampleRate;
  final int numberOfChannels;

  String get displayFilename {
    final normalized = originalFilename
        .replaceAll('\\', '/')
        .split('/')
        .last
        .trim();
    return normalized.isEmpty ? 'audio.$extension' : normalized;
  }

  Map<String, Object?> toJson() => {
    'sourceId': sourceId,
    'archivePath': archivePath,
    'originalFilename': originalFilename,
    'extension': extension,
    if (mimeType != null) 'mimeType': mimeType,
    'size': size,
    'durationSeconds': durationSeconds,
    'sampleRate': sampleRate,
    'numberOfChannels': numberOfChannels,
  };

  factory ProjectAudioSourceDto.fromJson(Map<String, Object?> json) {
    final extension = _requiredString(json, 'extension').toLowerCase();
    if (!const {'wav', 'mp3'}.contains(extension)) {
      _invalid('Unsupported audio source extension: $extension.');
    }
    final archivePath = _requiredString(json, 'archivePath');
    if (!_isSafeAudioPath(archivePath) ||
        !archivePath.toLowerCase().endsWith('.$extension')) {
      _invalid('Unsafe or inconsistent audio archive path: $archivePath.');
    }
    final mime = json['mimeType'];
    if (mime != null && mime is! String) {
      _invalid('mimeType must be a string when present.');
    }
    return ProjectAudioSourceDto(
      sourceId: _nonEmptyId(json, 'sourceId'),
      archivePath: archivePath,
      originalFilename: _requiredString(json, 'originalFilename'),
      extension: extension,
      mimeType: mime as String?,
      size: _positiveInt(json, 'size'),
      durationSeconds: _positiveNumber(json, 'durationSeconds'),
      sampleRate: _positiveNumber(json, 'sampleRate'),
      numberOfChannels: _positiveInt(json, 'numberOfChannels'),
    );
  }
}

bool _isSafeAudioPath(String path) {
  if (!path.startsWith('audio/') ||
      path.contains('\\') ||
      path.contains('..') ||
      path.startsWith('/') ||
      path.contains(':')) {
    return false;
  }
  final segments = path.split('/');
  return segments.length == 2 && segments.every((part) => part.isNotEmpty);
}

void _requireUnique(Iterable<String> values, String label) {
  final seen = <String>{};
  for (final value in values) {
    if (!seen.add(value)) {
      _invalid('Duplicate $label: $value.');
    }
  }
}

void _requireUniqueObjectIds(Iterable<String> values, String label) {
  final seen = <String>{};
  for (final value in values) {
    if (!seen.add(value)) {
      throw FlaudioProjectException(
        'Duplicate $label: $value.',
        userMessage:
            'The project contains duplicate object identifiers and cannot be loaded safely.',
      );
    }
  }
}

void _requireContiguousOrder(Iterable<int> values, String label) {
  final sorted = values.toList()..sort();
  for (var index = 0; index < sorted.length; index++) {
    if (sorted[index] != index) {
      _invalid('Invalid $label ordering.');
    }
  }
}

List<T> _objectList<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?>) decode,
) {
  final value = json[key];
  if (value is! List<Object?>) {
    _invalid('$key must be a list.');
  }
  return [
    for (final item in value)
      if (item is Map<String, Object?>)
        decode(item)
      else
        throw FlaudioProjectException(
          '$key contains a non-object value.',
          userMessage: 'The project metadata is invalid or corrupt.',
        ),
  ];
}

List<T> _optionalObjectList<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?>) decode,
) {
  if (!json.containsKey(key)) {
    return const [];
  }
  return _objectList(json, key, decode);
}

Map<String, Object?> _requiredMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map<String, Object?>) {
    _invalid('$key must be an object.');
  }
  return value;
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty || value.length > 1024) {
    _invalid('$key must be a non-empty string.');
  }
  return value;
}

String _nonEmptyId(Map<String, Object?> json, String key) {
  final value = _requiredString(json, key);
  if (value.length > 200) {
    _invalid('$key is too long.');
  }
  return value;
}

bool _requiredBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) {
    _invalid('$key must be a boolean.');
  }
  return value;
}

bool _optionalBool(
  Map<String, Object?> json,
  String key, {
  required bool fallback,
}) {
  if (!json.containsKey(key)) {
    return fallback;
  }
  return _requiredBool(json, key);
}

int _requiredInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) {
    _invalid('$key must be an integer.');
  }
  return value;
}

int _nonNegativeInt(Map<String, Object?> json, String key) {
  final value = _requiredInt(json, key);
  if (value < 0) {
    _invalid('$key must not be negative.');
  }
  return value;
}

int _positiveInt(Map<String, Object?> json, String key) {
  final value = _requiredInt(json, key);
  if (value <= 0) {
    _invalid('$key must be positive.');
  }
  return value;
}

int _argb(Map<String, Object?> json, String key) {
  final value = _requiredInt(json, key);
  if (value < 0 || value > 0xffffffff) {
    _invalid('$key must be a 32-bit ARGB value.');
  }
  return value;
}

double _finiteNumber(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num || !value.isFinite) {
    _invalid('$key must be a finite number.');
  }
  return value.toDouble();
}

double _nonNegativeNumber(Map<String, Object?> json, String key) {
  final value = _finiteNumber(json, key);
  if (value < 0) {
    _invalid('$key must not be negative.');
  }
  return value;
}

double _positiveNumber(Map<String, Object?> json, String key) {
  final value = _finiteNumber(json, key);
  if (value <= 0) {
    _invalid('$key must be positive.');
  }
  return value;
}

double _boundedNumber(
  Map<String, Object?> json,
  String key,
  double minimum,
  double maximum,
) {
  final value = _finiteNumber(json, key);
  if (value < minimum || value > maximum) {
    _invalid('$key is outside the supported range.');
  }
  return value;
}

Never _invalid(String message) => throw FlaudioProjectException(
  message,
  userMessage: 'The project metadata is invalid or corrupt.',
);
