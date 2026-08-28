import 'dart:async';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../domain/musical_timing.dart';
import '../domain/loop_region.dart';

/// Schedules metronome clicks on the Web Audio clock.
///
/// The Dart timer only replenishes a short look-ahead window. Every click is
/// given an absolute [web.AudioContext.currentTime], so UI/frame timing is not
/// used as the musical clock.
class WebMetronomeScheduler {
  WebMetronomeScheduler(this._audioContext, this._output);

  static const Duration _schedulerInterval = Duration(milliseconds: 25);
  static const double _lookAheadSeconds = 0.12;
  static const double _minimumScheduleLeadSeconds = 0.005;
  static const double _clickDurationSeconds = 0.045;
  static const double _silenceGain = 0.0001;

  final web.AudioContext _audioContext;
  final web.AudioNode _output;
  final List<_ScheduledClick> _scheduledClicks = [];

  Timer? _lookAheadTimer;
  double _tempoBpm = 120;
  TimeSignature _timeSignature = defaultTimeSignature;
  double _timelineStartSeconds = 0;
  double _contextStartTime = 0;
  double _passTimelineStartSeconds = 0;
  double _passTimelineEndSeconds = double.infinity;
  double _passContextStartTime = 0;
  int _nextBeatIndex = 0;
  LoopRegion? _loopRegion;
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

  void setTimeSignature(TimeSignature timeSignature) {
    if (_timeSignature == timeSignature) {
      return;
    }

    _timeSignature = timeSignature;
    if (_enabled && _transportRunning) {
      _restartScheduling();
    }
  }

  void startTransport({
    required double timelineStartSeconds,
    required double contextStartTime,
    LoopRegion? loopRegion,
  }) {
    _timelineStartSeconds = timelineStartSeconds;
    _contextStartTime = contextStartTime;
    _loopRegion = loopRegion;
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
    final currentTimeline = _currentTimelinePosition();
    final now = _audioContext.currentTime;
    _passTimelineStartSeconds = currentTimeline;
    _passTimelineEndSeconds = _loopRegion?.endSeconds ?? double.infinity;
    _passContextStartTime = _contextStartTime > now ? _contextStartTime : now;
    _nextBeatIndex = _firstBeatAtOrAfter(currentTimeline);
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

  MusicalTiming get _timing =>
      MusicalTiming(bpm: _tempoBpm, timeSignature: _timeSignature);

  double _currentTimelinePosition() {
    final elapsed = _audioContext.currentTime - _contextStartTime;

    if (elapsed <= 0) {
      return _timelineStartSeconds;
    }

    final position = _timelineStartSeconds + elapsed;
    final loop = _loopRegion;
    if (loop != null && position >= loop.endSeconds) {
      return loop.startSeconds +
          ((position - loop.endSeconds) % loop.durationSeconds);
    }
    return position;
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

      if (beatTimelineSeconds >= _passTimelineEndSeconds) {
        final loop = _loopRegion;
        if (loop == null) {
          break;
        }
        _passContextStartTime +=
            _passTimelineEndSeconds - _passTimelineStartSeconds;
        _passTimelineStartSeconds = loop.startSeconds;
        _passTimelineEndSeconds = loop.endSeconds;
        _nextBeatIndex = _firstBeatAtOrAfter(loop.startSeconds);
        if (_passContextStartTime > windowEnd) {
          break;
        }
        continue;
      }

      final beatContextTime =
          _passContextStartTime +
          (beatTimelineSeconds - _passTimelineStartSeconds);

      if (beatContextTime > windowEnd) {
        break;
      }

      if (beatContextTime >= now + _minimumScheduleLeadSeconds) {
        _scheduleClick(
          contextTime: beatContextTime,
          isDownbeat: timing.isDownbeat(_nextBeatIndex),
          latestEndTime: _passTimelineEndSeconds.isFinite
              ? _passContextStartTime +
                    (_passTimelineEndSeconds - _passTimelineStartSeconds)
              : double.infinity,
        );
      }

      _nextBeatIndex++;
    }
  }

  void _scheduleClick({
    required double contextTime,
    required bool isDownbeat,
    required double latestEndTime,
  }) {
    final endTime = math.min(
      contextTime + _clickDurationSeconds,
      latestEndTime,
    );
    if (endTime <= contextTime) {
      return;
    }
    final attackEndTime = math.min(contextTime + 0.002, endTime);
    final oscillator = _audioContext.createOscillator();
    final gain = _audioContext.createGain();

    oscillator.type = 'sine';
    oscillator.frequency.setValueAtTime(isDownbeat ? 1760 : 1160, contextTime);

    gain.gain.setValueAtTime(_silenceGain, contextTime);
    gain.gain.exponentialRampToValueAtTime(
      isDownbeat ? 0.24 : 0.14,
      attackEndTime,
    );
    gain.gain.exponentialRampToValueAtTime(_silenceGain, endTime);

    oscillator.connect(gain);
    gain.connect(_output);
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
