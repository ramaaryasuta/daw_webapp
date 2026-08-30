import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../domain/audio_meter.dart';

const double meterFloorDb = -60;
const double meterClipDb = 0;

@immutable
class StereoMeterLevel {
  const StereoMeterLevel({
    required this.leftDb,
    required this.rightDb,
    required this.leftPeakDb,
    required this.rightPeakDb,
    required this.leftClipped,
    required this.rightClipped,
  });

  static const silence = StereoMeterLevel(
    leftDb: meterFloorDb,
    rightDb: meterFloorDb,
    leftPeakDb: meterFloorDb,
    rightPeakDb: meterFloorDb,
    leftClipped: false,
    rightClipped: false,
  );

  final double leftDb;
  final double rightDb;
  final double leftPeakDb;
  final double rightPeakDb;
  final bool leftClipped;
  final bool rightClipped;
}

class AudioMeterController extends ChangeNotifier {
  AudioMeterController(this._peakSource);

  static const double _releaseToSilenceSeconds = 0.5;
  static const double _peakHoldSeconds = 0.85;
  static const double _clipHoldSeconds = 1.0;

  final AudioMeterPeakSource _peakSource;
  final Map<String, _StereoBallistics> _tracks = {};
  final Map<String, _GainReductionBallistics> _compressors = {};
  final _GainReductionBallistics _masterLimiter = _GainReductionBallistics();
  final _StereoBallistics _master = _StereoBallistics();
  late final Ticker _ticker = Ticker(_onTick);

  Duration? _lastElapsed;
  bool _transportActive = false;

  StereoMeterLevel get masterLevel => _master.level;

  StereoMeterLevel levelForTrack(String trackId) =>
      _tracks[trackId]?.level ?? StereoMeterLevel.silence;

  double compressorReductionForTrack(String trackId) =>
      _compressors[trackId]?.reductionDb ?? 0;

  double get masterLimiterReductionDb => _masterLimiter.reductionDb;

  void setTransportActive(bool active) {
    _transportActive = active;
    if (active || !_isAtRest) {
      if (!_ticker.isActive) {
        _lastElapsed = null;
        _ticker.start();
      }
    } else if (_ticker.isActive) {
      _ticker.stop();
      _lastElapsed = null;
    }
  }

  bool get _isAtRest =>
      _master.isAtRest &&
      _tracks.values.every((track) => track.isAtRest) &&
      _compressors.values.every((compressor) => compressor.isAtRest) &&
      _masterLimiter.isAtRest;

  void _onTick(Duration elapsed) {
    final previousElapsed = _lastElapsed;
    _lastElapsed = elapsed;
    final deltaSeconds = previousElapsed == null
        ? 1 / 60
        : ((elapsed - previousElapsed).inMicroseconds / 1000000)
              .clamp(0.001, 0.1)
              .toDouble();
    final peaks = _peakSource.readMeterPeaks();
    var changed = _master.update(peaks.master, deltaSeconds);
    changed =
        _masterLimiter.update(peaks.masterLimiterReductionDb, deltaSeconds) ||
        changed;

    for (final entry in peaks.tracks.entries) {
      final track = _tracks.putIfAbsent(entry.key, _StereoBallistics.new);
      changed = track.update(entry.value, deltaSeconds) || changed;
    }

    for (final trackId in _tracks.keys.toList()) {
      if (peaks.tracks.containsKey(trackId)) {
        continue;
      }
      final track = _tracks[trackId]!;
      changed = track.update(StereoPeak.silence, deltaSeconds) || changed;
      if (track.isAtRest) {
        _tracks.remove(trackId);
      }
    }

    for (final entry in peaks.compressorReductionDb.entries) {
      final compressor = _compressors.putIfAbsent(
        entry.key,
        _GainReductionBallistics.new,
      );
      changed = compressor.update(entry.value, deltaSeconds) || changed;
    }

    for (final trackId in _compressors.keys.toList()) {
      if (peaks.compressorReductionDb.containsKey(trackId)) continue;
      final compressor = _compressors[trackId]!;
      changed = compressor.update(0, deltaSeconds) || changed;
      if (compressor.isAtRest) _compressors.remove(trackId);
    }

    if (changed) {
      notifyListeners();
    }
    if (!_transportActive && _isAtRest) {
      _ticker.stop();
      _lastElapsed = null;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tracks.clear();
    _compressors.clear();
    super.dispose();
  }
}

class _GainReductionBallistics {
  static const double _returnSeconds = 0.22;
  double reductionDb = 0;

  bool get isAtRest => reductionDb.abs() < 0.01;

  bool update(double rawReductionDb, double deltaSeconds) {
    final previous = reductionDb;
    final target = rawReductionDb.isFinite
        ? rawReductionDb.clamp(-24.0, 0.0)
        : 0.0;
    if (target < reductionDb) {
      reductionDb = target;
    } else {
      final release = math.exp(-deltaSeconds / _returnSeconds);
      reductionDb = target + (reductionDb - target) * release;
    }
    if (reductionDb.abs() < 0.01) reductionDb = 0;
    return previous != reductionDb;
  }
}

class _StereoBallistics {
  final _MeterChannelBallistics left = _MeterChannelBallistics();
  final _MeterChannelBallistics right = _MeterChannelBallistics();

  StereoMeterLevel get level => StereoMeterLevel(
    leftDb: left.levelDb,
    rightDb: right.levelDb,
    leftPeakDb: left.peakDb,
    rightPeakDb: right.peakDb,
    leftClipped: left.isClipped,
    rightClipped: right.isClipped,
  );

  bool get isAtRest => left.isAtRest && right.isAtRest;

  bool update(StereoPeak peak, double deltaSeconds) {
    final previous = level;
    left.update(peak.left, deltaSeconds);
    right.update(peak.right, deltaSeconds);
    final next = level;
    return previous.leftDb != next.leftDb ||
        previous.rightDb != next.rightDb ||
        previous.leftPeakDb != next.leftPeakDb ||
        previous.rightPeakDb != next.rightPeakDb ||
        previous.leftClipped != next.leftClipped ||
        previous.rightClipped != next.rightClipped;
  }
}

class _MeterChannelBallistics {
  static const double _floorAmplitude = 0.001;

  double _levelAmplitude = 0;
  double _peakAmplitude = 0;
  double _peakHoldRemaining = 0;
  double _clipHoldRemaining = 0;

  double get levelDb => amplitudeToDb(_levelAmplitude);
  double get peakDb => amplitudeToDb(_peakAmplitude);
  bool get isClipped => _clipHoldRemaining > 0;
  bool get isAtRest =>
      _levelAmplitude <= _floorAmplitude &&
      _peakAmplitude <= _floorAmplitude &&
      _peakHoldRemaining <= 0 &&
      _clipHoldRemaining <= 0;

  void update(double rawAmplitude, double deltaSeconds) {
    final amplitude = math.max(0.0, rawAmplitude);
    final releaseMultiplier = math.exp(
      -math.ln10 *
          3 *
          deltaSeconds /
          AudioMeterController._releaseToSilenceSeconds,
    );

    _levelAmplitude = amplitude >= _levelAmplitude
        ? amplitude
        : math.max(amplitude, _levelAmplitude * releaseMultiplier);

    if (amplitude >= _peakAmplitude) {
      _peakAmplitude = amplitude;
      _peakHoldRemaining = AudioMeterController._peakHoldSeconds;
    } else if (_peakHoldRemaining > 0) {
      _peakHoldRemaining = math.max(0.0, _peakHoldRemaining - deltaSeconds);
    } else {
      _peakAmplitude = math.max(amplitude, _peakAmplitude * releaseMultiplier);
    }

    if (amplitude >= 1) {
      _clipHoldRemaining = AudioMeterController._clipHoldSeconds;
    } else {
      _clipHoldRemaining = math.max(0.0, _clipHoldRemaining - deltaSeconds);
    }

    if (_levelAmplitude < _floorAmplitude) {
      _levelAmplitude = 0;
    }
    if (_peakAmplitude < _floorAmplitude && _peakHoldRemaining <= 0) {
      _peakAmplitude = 0;
    }
  }
}

double amplitudeToDb(double amplitude) {
  if (amplitude <= 0) {
    return meterFloorDb;
  }
  return math.max(meterFloorDb, 20 * math.log(amplitude) / math.ln10);
}
