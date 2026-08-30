enum TrackFxType { filter, eq, compressor }

const List<TrackFxType> defaultTrackFxChainOrder = [
  TrackFxType.filter,
  TrackFxType.eq,
  TrackFxType.compressor,
];

bool isValidTrackFxChainOrder(Iterable<TrackFxType> order) {
  final values = order.toList();
  return values.length == TrackFxType.values.length &&
      values.toSet().length == TrackFxType.values.length &&
      values.toSet().containsAll(TrackFxType.values);
}

bool hasSameTrackFxChainOrder(List<TrackFxType> left, List<TrackFxType> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

extension TrackFxTypeDisplay on TrackFxType {
  String get displayName => switch (this) {
    TrackFxType.filter => 'FILTER',
    TrackFxType.eq => '3-BAND EQ',
    TrackFxType.compressor => 'COMPRESSOR',
  };
}
