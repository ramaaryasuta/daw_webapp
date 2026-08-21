enum SnapSubdivision {
  bar('1 Bar'),
  beat('1 Beat'),
  halfBeat('1/2 Beat'),
  quarterBeat('1/4 Beat'),
  eighthBeat('1/8 Beat');

  const SnapSubdivision(this.label);

  final String label;
}

class SnapSettings {
  const SnapSettings({
    this.enabled = true,
    this.subdivision = SnapSubdivision.quarterBeat,
  });

  final bool enabled;
  final SnapSubdivision subdivision;

  SnapSettings copyWith({bool? enabled, SnapSubdivision? subdivision}) {
    return SnapSettings(
      enabled: enabled ?? this.enabled,
      subdivision: subdivision ?? this.subdivision,
    );
  }
}
