/// Default project meter used by the metronome and musical timeline grid.
///
/// Keeping this in the domain layer allows a future time-signature model to
/// replace the default without coupling editor features to the audio engine.
const int defaultBeatsPerBar = 4;

double secondsPerBeat(double bpm) {
  if (!bpm.isFinite || bpm <= 0) {
    throw ArgumentError.value(bpm, 'bpm', 'Must be finite and greater than 0');
  }

  return 60 / bpm;
}
