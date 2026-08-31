import 'package:flutter/material.dart';

import '../models/timeline_ruler_mode.dart';
import '../models/editor_workspace.dart';
import '../controllers/audio_meter_controller.dart';
import '../../domain/master_limiter.dart';
import 'master_strip.dart';
import 'tempo_controls.dart';
import 'time_signature_control.dart';
import 'snap_control.dart';
import 'timeline_ruler_mode_control.dart';

class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.isPlaying,
    required this.isImporting,
    required this.isLoopEnabled,
    required this.positionSeconds,
    required this.rulerMode,
    required this.onPlayPressed,
    required this.onStopPressed,
    required this.onLoopPressed,
    required this.onRulerModeChanged,
    required this.workspace,
    required this.onWorkspaceChanged,
    this.meterController,
    this.masterVolumeDb = 0,
    this.onMasterVolumeChangeStart,
    this.onMasterVolumeChanged,
    this.onMasterVolumeChangeEnd,
    this.onMasterVolumeReset,
    this.masterLimiter = const MasterLimiterSettings(),
    this.onLimiterToggle,
    this.onLimiterChangeStart,
    this.onLimiterChanged,
    this.onLimiterChangeEnd,
    this.onLimiterParameterReset,
    this.onLimiterReset,
  });

  final bool isPlaying;
  final bool isImporting;
  final bool isLoopEnabled;
  final double positionSeconds;
  final TimelineRulerMode rulerMode;
  final EditorWorkspace workspace;
  final AudioMeterController? meterController;
  final double masterVolumeDb;
  final MasterLimiterSettings masterLimiter;

  final VoidCallback onPlayPressed;
  final VoidCallback onStopPressed;
  final VoidCallback onLoopPressed;
  final ValueChanged<TimelineRulerMode> onRulerModeChanged;
  final ValueChanged<EditorWorkspace> onWorkspaceChanged;
  final VoidCallback? onMasterVolumeChangeStart;
  final ValueChanged<double>? onMasterVolumeChanged;
  final ValueChanged<double>? onMasterVolumeChangeEnd;
  final VoidCallback? onMasterVolumeReset;
  final VoidCallback? onLimiterToggle;
  final ValueChanged<MasterLimiterParameter>? onLimiterChangeStart;
  final void Function(MasterLimiterParameter, double)? onLimiterChanged;
  final void Function(MasterLimiterParameter, double)? onLimiterChangeEnd;
  final ValueChanged<MasterLimiterParameter>? onLimiterParameterReset;
  final VoidCallback? onLimiterReset;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 64,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final masterWidth = constraints.maxWidth >= 760
              ? 236.0
              : constraints.maxWidth >= 500
              ? 210.0
              : constraints.maxWidth >= 320
              ? constraints.maxWidth * 0.48
              : (constraints.maxWidth - 32).clamp(40.0, 154.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Container(
                          height: 44,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Stop',
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                onPressed: onStopPressed,
                                icon: const Icon(Icons.stop, size: 20),
                              ),
                              const SizedBox(width: 4),
                              IconButton.filled(
                                tooltip: isPlaying ? 'Pause' : 'Play',
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                onPressed: onPlayPressed,
                                icon: Icon(
                                  isPlaying ? Icons.pause : Icons.play_arrow,
                                  size: 21,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: 'Loop playback',
                                constraints: const BoxConstraints.tightFor(
                                  width: 36,
                                  height: 36,
                                ),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                isSelected: isLoopEnabled,
                                onPressed: onLoopPressed,
                                icon: const Icon(Icons.repeat, size: 20),
                                selectedIcon: const Icon(
                                  Icons.repeat,
                                  size: 20,
                                ),
                                style: isLoopEnabled
                                    ? IconButton.styleFrom(
                                        backgroundColor:
                                            colorScheme.primaryContainer,
                                        foregroundColor:
                                            colorScheme.onPrimaryContainer,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _WorkspaceSelector(
                          workspace: workspace,
                          onChanged: onWorkspaceChanged,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 36,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                            ),
                          ),
                          child: Text(
                            _formatTime(positionSeconds),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          width: 1,
                          height: 28,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(width: 20),
                        const TempoControls(),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 20,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(width: 8),
                        const TimeSignatureControl(),
                        const SizedBox(width: 8),
                        Container(
                          width: 1,
                          height: 20,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(width: 8),
                        const SnapControl(),
                        const SizedBox(width: 10),
                        TimelineRulerModeControl(
                          mode: rulerMode,
                          onChanged: onRulerModeChanged,
                        ),
                        if (isImporting)
                          const Padding(
                            padding: EdgeInsets.only(left: 20),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Importing audio...'),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (meterController != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: masterWidth,
                    child: MasterStrip(
                      volumeDb: masterVolumeDb,
                      meterController: meterController!,
                      onChangeStart: onMasterVolumeChangeStart ?? _doNothing,
                      onChanged: onMasterVolumeChanged ?? _ignoreValue,
                      onChangeEnd: onMasterVolumeChangeEnd ?? _ignoreValue,
                      onReset: onMasterVolumeReset ?? _doNothing,
                      masterLimiter: masterLimiter,
                      onLimiterToggle: onLimiterToggle ?? _doNothing,
                      onLimiterChangeStart:
                          onLimiterChangeStart ?? _ignoreLimiterParameter,
                      onLimiterChanged: onLimiterChanged ?? _ignoreLimiterValue,
                      onLimiterChangeEnd:
                          onLimiterChangeEnd ?? _ignoreLimiterValue,
                      onLimiterParameterReset:
                          onLimiterParameterReset ?? _ignoreLimiterParameter,
                      onLimiterReset: onLimiterReset ?? _doNothing,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTime(double seconds) {
    final totalMilliseconds = (seconds * 1000).floor();

    final minutes = totalMilliseconds ~/ 60000;

    final remainingMilliseconds = totalMilliseconds % 60000;

    final secs = remainingMilliseconds ~/ 1000;

    final millis = remainingMilliseconds % 1000;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}.'
        '${millis.toString().padLeft(3, '0')}';
  }
}

class _WorkspaceSelector extends StatelessWidget {
  const _WorkspaceSelector({required this.workspace, required this.onChanged});

  final EditorWorkspace workspace;
  final ValueChanged<EditorWorkspace> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Editor workspace',
      child: Container(
        key: const ValueKey('editor-workspace-selector'),
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WorkspaceButton(
              key: const ValueKey('workspace-arrange'),
              label: 'ARRANGE',
              icon: Icons.view_timeline_outlined,
              selected: workspace == EditorWorkspace.arrange,
              onPressed: () => onChanged(EditorWorkspace.arrange),
            ),
            _WorkspaceButton(
              key: const ValueKey('workspace-mixer'),
              label: 'MIXER',
              icon: Icons.tune,
              selected: workspace == EditorWorkspace.mixer,
              onPressed: () => onChanged(EditorWorkspace.mixer),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceButton extends StatelessWidget {
  const _WorkspaceButton({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '$label workspace',
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? colors.primaryContainer.withValues(alpha: .72)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? colors.primary.withValues(alpha: .55)
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _doNothing() {}

void _ignoreValue(double _) {}

void _ignoreLimiterParameter(MasterLimiterParameter _) {}

void _ignoreLimiterValue(MasterLimiterParameter _, double _) {}
