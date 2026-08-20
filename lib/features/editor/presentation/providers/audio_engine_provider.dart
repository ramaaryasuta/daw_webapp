import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/audio/daw_audio_engine.dart';

final dawAudioEngineProvider = Provider<DawAudioEngine>((ref) {
  final engine = DawAudioEngine();

  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});
