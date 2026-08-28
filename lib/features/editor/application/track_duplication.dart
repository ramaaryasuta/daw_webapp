import '../domain/audio_clip.dart';
import '../domain/daw_track.dart';

/// Creates the next conventional copy name without requiring manually renamed
/// tracks to be globally unique.
String nextDuplicateTrackName({
  required String sourceName,
  required Iterable<String> existingNames,
}) {
  final names = existingNames.toSet();
  final copyMatch = RegExp(r'^(.*) Copy(?: (\d+))?$').firstMatch(sourceName);
  final baseName = copyMatch?.group(1) ?? sourceName;
  var copyNumber = copyMatch == null
      ? 1
      : (int.tryParse(copyMatch.group(2) ?? '') ?? 1) + 1;

  while (true) {
    final suffix = copyNumber == 1 ? ' Copy' : ' Copy $copyNumber';
    final maximumBaseLength = maximumTrackNameLength - suffix.length;
    final trimmedBase = baseName.length <= maximumBaseLength
        ? baseName
        : baseName.substring(0, maximumBaseLength).trimRight();
    final candidate = '$trimmedBase$suffix';
    if (!names.contains(candidate)) {
      return candidate;
    }
    copyNumber++;
  }
}

/// Clones persistent track and clip metadata while deliberately sharing each
/// clip's immutable audio source data.
DawTrack cloneTrackWithClips({
  required DawTrack source,
  required String newTrackId,
  required String newName,
  required String Function() nextClipId,
}) {
  return source.copyWith(
    id: newTrackId,
    name: newName,
    clips: List<AudioClip>.unmodifiable([
      for (final clip in source.clips) clip.copyWith(id: nextClipId()),
    ]),
  );
}
