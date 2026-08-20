import 'dart:typed_data';

class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.name,
    required this.bytes,
    required this.contentType,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.isMuted = false,
    this.isSolo = false,
  });

  final String id;
  final String name;

  /// Kita simpan bytes karena Flutter Web tidak bisa bergantung
  /// pada filesystem path seperti aplikasi desktop biasa.
  final Uint8List bytes;

  final String contentType;
  final Duration duration;

  final double volume;
  final bool isMuted;
  final bool isSolo;

  AudioTrack copyWith({
    String? id,
    String? name,
    Uint8List? bytes,
    String? contentType,
    Duration? duration,
    double? volume,
    bool? isMuted,
    bool? isSolo,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      bytes: bytes ?? this.bytes,
      contentType: contentType ?? this.contentType,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      isMuted: isMuted ?? this.isMuted,
      isSolo: isSolo ?? this.isSolo,
    );
  }
}
