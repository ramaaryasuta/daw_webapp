import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/tempo_controller.dart';
import 'time_signature_button.dart';

class TimeSignatureControl extends ConsumerWidget {
  const TimeSignatureControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      tempoControllerProvider.select((state) => state.timeSignature),
    );
    return TimeSignatureButton(
      selected: selected,
      onSelected: ref
          .read(editorControllerProvider.notifier)
          .setProjectTimeSignature,
    );
  }
}
