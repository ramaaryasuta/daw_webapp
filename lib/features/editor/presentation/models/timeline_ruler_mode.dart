enum TimelineRulerMode {
  barsBeats('Bars / Beats', 'Bars'),
  time('Time', 'Time');

  const TimelineRulerMode(this.label, this.compactLabel);

  final String label;
  final String compactLabel;
}
