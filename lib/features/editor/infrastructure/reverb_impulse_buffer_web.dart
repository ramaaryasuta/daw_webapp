import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'reverb_impulse_response.dart';

web.AudioBuffer createReverbImpulseBuffer(
  web.BaseAudioContext context, {
  required double decaySeconds,
}) {
  final response = generateReverbImpulseResponse(
    sampleRate: context.sampleRate,
    decaySeconds: decaySeconds,
  );
  final buffer = context.createBuffer(2, response.length, context.sampleRate);
  buffer.copyToChannel(response.left.toJS, 0);
  buffer.copyToChannel(response.right.toJS, 1);
  return buffer;
}
