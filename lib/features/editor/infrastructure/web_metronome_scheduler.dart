import 'dart:async';

import 'package:web/web.dart' as web;

import '../domain/musical_timing.dart';

/// Schedules metronome clicks on the Web Audio clock.
///
/// The Dart timer only replenishes a short look-ahead window. Every click is
/// given an absolute [web.AudioContext.currentTime], so UI/frame timing is not
/// used as the musical clock.
class WebMetronomeScheduler {
  WebMetronomeScheduler(this._audioContext);

  static const Duration _schedulerInterval = Duration(milliseconds: 25);
  static const double _lookAheadSeconds = 0.12;
  static const double _minimumScheduleLeadSeconds = 0.005;
  static const double _clickDurationSeconds = 0.045;
  static const double _silenceGain = 0.0001;

  final web.AudioContext _audioContext;
  final List<_ScheduledClick> _scheduledClicks = [];

  Timer? _lookAheadTimer;
  double _tempoBpm = 120;
  double _timelineStartSeconds = 0;
  double _contextStartTime = 0;
  int _nextBeatIndex = 0;
  bool _enabled = false;
  bool _transportRunning = false;

  void setEnabled(bool enabled) {
    if (_enabled == enabled) {
      return;
    }

    _enabled = enabled;

    if (_enabled && _transportRunning) {
      _restartScheduling();
    } else {
      _stopScheduling();
    }
  }

  void setTempoBpm(double tempoBpm) {
    if (_tempoBpm == tempoBpm) {
      return;
    }

    _tempoBpm = tempoBpm;

    if (_enabled && _transportRunning) {
      _restartScheduling();
    }
  }

  void startTransport({
    required double timelineStartSeconds,
    required double contextStartTime,
  }) {
    _timelineStartSeconds = timelineStartSeconds;
    _contextStartTime = contextStartTime;
    _transportRunning = true;

    if (_enabled) {
      _restartScheduling();
    }
  }

  void stopTransport() {
    _transportRunning = false;
    _stopScheduling();
  }

  void dispose() {
    _transportRunning = false;
    _enabled = false;
    _stopScheduling();
  }

  void _restartScheduling() {
    _stopScheduling();
    _nextBeatIndex = _firstBeatAtOrAfter(_currentTimelinePosition());
    _scheduleLookAhead();
    _lookAheadTimer = Timer.periodic(
      _schedulerInterval,
      (_) => _scheduleLookAhead(),
    );
  }

  void _stopScheduling() {
    _lookAheadTimer?.cancel();
    _lookAheadTimer = null;

    for (final click in _scheduledClicks) {
      try {
        click.oscillator.stop();
      } catch (_) {
        // A click may already have ended.
      }

      try {
        click.oscillator.disconnect();
      } catch (_) {}

      try {
        click.gain.disconnect();
      } catch (_) {}
    }

    _scheduledClicks.clear();
  }

  MusicalTiming get _timing => MusicalTiming(bpm: _tempoBpm);

  double _currentTimelinePosition() {
    final elapsed = _audioContext.currentTime - _contextStartTime;

    if (elapsed <= 0) {
      return _timelineStartSeconds;
    }

    return _timelineStartSeconds + elapsed;
  }

  int _firstBeatAtOrAfter(double timelineSeconds) {
    return _timing.firstBeatIndexAtOrAfter(timelineSeconds);
  }

  void _scheduleLookAhead() {
    if (!_enabled || !_transportRunning) {
      return;
    }

    final now = _audioContext.currentTime;
    _cleanUpFinishedClicks(now);
    final windowEnd = now + _lookAheadSeconds;
    final timing = _timing;

    while (true) {
      final beatTimelineSeconds = timing.beatTimeSeconds(_nextBeatIndex);
      final beatContextTime =
          _contextStartTime + (beatTimelineSeconds - _timelineStartSeconds);

      if (beatContextTime > windowEnd) {
        break;
      }

      if (beatContextTime >= now + _minimumScheduleLeadSeconds) {
        _scheduleClick(
          contextTime: beatContextTime,
          isDownbeat: timing.isDownbeat(_nextBeatIndex),
        );
      }

      _nextBeatIndex++;
    }
  }

  void _scheduleClick({required double contextTime, required bool isDownbeat}) {
    final oscillator = _audioContext.createOscillator();
    final gain = _audioContext.createGain();
    final endTime = contextTime + _clickDurationSeconds;

    oscillator.type = 'sine';
    oscillator.frequency.setValueAtTime(isDownbeat ? 1760 : 1160, contextTime);

    gain.gain.setValueAtTime(_silenceGain, contextTime);
    gain.gain.exponentialRampToValueAtTime(
      isDownbeat ? 0.24 : 0.14,
      contextTime + 0.002,
    );
    gain.gain.exponentialRampToValueAtTime(_silenceGain, endTime);

    oscillator.connect(gain);
    gain.connect(_audioContext.destination);
    oscillator.start(contextTime);
    oscillator.stop(endTime);

    _scheduledClicks.add(
      _ScheduledClick(oscillator: oscillator, gain: gain, endTime: endTime),
    );
  }

  void _cleanUpFinishedClicks(double currentTime) {
    for (var index = _scheduledClicks.length - 1; index >= 0; index--) {
      final click = _scheduledClicks[index];

      if (click.endTime >= currentTime) {
        continue;
      }

      try {
        click.oscillator.disconnect();
      } catch (_) {}

      try {
        click.gain.disconnect();
      } catch (_) {}

      _scheduledClicks.removeAt(index);
    }
  }
}

class _ScheduledClick {
  const _ScheduledClick({
    required this.oscillator,
    required this.gain,
    required this.endTime,
  });

  final web.OscillatorNode oscillator;
  final web.GainNode gain;
  final double endTime;
}
