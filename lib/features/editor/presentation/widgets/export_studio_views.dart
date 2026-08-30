import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/export_settings.dart';
import '../../infrastructure/generated_export.dart';
import '../formatters/export_duration_formatter.dart';

enum ExportStudioMode { general, advanced }

abstract final class _ExportSpacing {
  static const double xs = 4;
  static const double fieldLabel = 6;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

class ExportConfigurationView extends StatelessWidget {
  const ExportConfigurationView({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.format,
    required this.onFormatChanged,
    required this.bitrateKbps,
    required this.onBitrateChanged,
    required this.renderInfo,
    required this.estimatedBytes,
    required this.fileNameController,
    required this.titleController,
    required this.artistController,
    required this.albumController,
    required this.yearController,
    required this.trackController,
    required this.genreController,
    required this.commentController,
    this.notice,
    this.noticeIsError = false,
  });

  final ExportStudioMode mode;
  final ValueChanged<ExportStudioMode> onModeChanged;
  final ExportFormat format;
  final ValueChanged<ExportFormat> onFormatChanged;
  final int bitrateKbps;
  final ValueChanged<int> onBitrateChanged;
  final ExportRenderInfo? renderInfo;
  final int Function(ExportFormat format) estimatedBytes;
  final TextEditingController fileNameController;
  final TextEditingController titleController;
  final TextEditingController artistController;
  final TextEditingController albumController;
  final TextEditingController yearController;
  final TextEditingController trackController;
  final TextEditingController genreController;
  final TextEditingController commentController;
  final String? notice;
  final bool noticeIsError;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('configuration'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExportModeTabs(mode: mode, onChanged: onModeChanged),
        const SizedBox(height: _ExportSpacing.xl),
        const ExportSectionLabel('OUTPUT FORMAT'),
        const SizedBox(height: _ExportSpacing.sm),
        ExportFormatSelector(
          selected: format,
          wavEstimate: estimatedBytes(ExportFormat.wav),
          mp3Estimate: estimatedBytes(ExportFormat.mp3),
          onChanged: onFormatChanged,
        ),
        if (format == ExportFormat.mp3) ...[
          const SizedBox(height: _ExportSpacing.lg),
          ExportQualitySelector(
            bitrateKbps: bitrateKbps,
            onChanged: onBitrateChanged,
          ),
        ],
        const SizedBox(height: _ExportSpacing.xl),
        if (mode == ExportStudioMode.general)
          _GeneralConfiguration(
            format: format,
            bitrateKbps: bitrateKbps,
            renderInfo: renderInfo,
            estimatedBytes: estimatedBytes(format),
            fileNameController: fileNameController,
          )
        else
          _AdvancedConfiguration(
            format: format,
            bitrateKbps: bitrateKbps,
            renderInfo: renderInfo,
            estimatedBytes: estimatedBytes(format),
            fileNameController: fileNameController,
            titleController: titleController,
            artistController: artistController,
            albumController: albumController,
            yearController: yearController,
            trackController: trackController,
            genreController: genreController,
            commentController: commentController,
          ),
        if (notice != null) ...[
          const SizedBox(height: _ExportSpacing.md),
          ExportInlineNotice(
            icon: noticeIsError ? Icons.error_outline : Icons.refresh,
            text: notice!,
            color: noticeIsError
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.tertiary,
          ),
        ],
        const SizedBox(height: _ExportSpacing.lg),
        const ExportPrivacyNote(),
      ],
    );
  }
}

class _GeneralConfiguration extends StatelessWidget {
  const _GeneralConfiguration({
    required this.format,
    required this.bitrateKbps,
    required this.renderInfo,
    required this.estimatedBytes,
    required this.fileNameController,
  });

  final ExportFormat format;
  final int bitrateKbps;
  final ExportRenderInfo? renderInfo;
  final int estimatedBytes;
  final TextEditingController fileNameController;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ExportSectionLabel('FILE'),
        const SizedBox(height: _ExportSpacing.sm),
        ExportFileNameField(controller: fileNameController, format: format),
        const SizedBox(height: _ExportSpacing.lg),
        ExportSummaryCard(
          format: format,
          bitrateKbps: bitrateKbps,
          renderInfo: renderInfo,
          estimatedBytes: estimatedBytes,
          fileName: exportFileName(fileNameController.text, format),
        ),
      ],
    );
  }
}

class _AdvancedConfiguration extends StatelessWidget {
  const _AdvancedConfiguration({
    required this.format,
    required this.bitrateKbps,
    required this.renderInfo,
    required this.estimatedBytes,
    required this.fileNameController,
    required this.titleController,
    required this.artistController,
    required this.albumController,
    required this.yearController,
    required this.trackController,
    required this.genreController,
    required this.commentController,
  });

  final ExportFormat format;
  final int bitrateKbps;
  final ExportRenderInfo? renderInfo;
  final int estimatedBytes;
  final TextEditingController fileNameController;
  final TextEditingController titleController;
  final TextEditingController artistController;
  final TextEditingController albumController;
  final TextEditingController yearController;
  final TextEditingController trackController;
  final TextEditingController genreController;
  final TextEditingController commentController;

  @override
  Widget build(BuildContext context) {
    final metadata = format == ExportFormat.mp3
        ? ExportMetadataSection(
            titleController: titleController,
            artistController: artistController,
            albumController: albumController,
            yearController: yearController,
            trackController: trackController,
            genreController: genreController,
            commentController: commentController,
          )
        : const _WavAdvancedNote();
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExportSummaryCard(
          format: format,
          bitrateKbps: bitrateKbps,
          renderInfo: renderInfo,
          estimatedBytes: estimatedBytes,
          fileName: exportFileName(fileNameController.text, format),
          compact: true,
        ),
        const SizedBox(height: _ExportSpacing.xl),
        const ExportSectionLabel('FILE'),
        const SizedBox(height: _ExportSpacing.sm),
        ExportFileNameField(controller: fileNameController, format: format),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              metadata,
              const SizedBox(height: _ExportSpacing.xl),
              side,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 13, child: metadata),
            const SizedBox(width: _ExportSpacing.lg),
            Expanded(flex: 7, child: side),
          ],
        );
      },
    );
  }
}

class ExportModeTabs extends StatelessWidget {
  const ExportModeTabs({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ExportStudioMode mode;
  final ValueChanged<ExportStudioMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final value in ExportStudioMode.values)
          _ModeTab(
            label: value == ExportStudioMode.general ? 'GENERAL' : 'ADVANCED',
            selected: mode == value,
            onTap: () => onChanged(value),
          ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: .09)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? colors.primary : colors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: .6,
          ),
        ),
      ),
    );
  }
}

class ExportFormatSelector extends StatelessWidget {
  const ExportFormatSelector({
    super.key,
    required this.selected,
    required this.wavEstimate,
    required this.mp3Estimate,
    required this.onChanged,
  });

  final ExportFormat selected;
  final int wavEstimate;
  final int mp3Estimate;
  final ValueChanged<ExportFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wav = _FormatCard(
          format: ExportFormat.wav,
          selected: selected == ExportFormat.wav,
          description: 'Best for editing and archiving',
          size: formatExportBytes(wavEstimate, approximate: true),
          onTap: () => onChanged(ExportFormat.wav),
        );
        final mp3 = _FormatCard(
          format: ExportFormat.mp3,
          selected: selected == ExportFormat.mp3,
          description: 'Smaller files, easy to share',
          size: formatExportBytes(mp3Estimate, approximate: true),
          onTap: () => onChanged(ExportFormat.mp3),
        );
        if (constraints.maxWidth < 470) {
          return Column(children: [wav, const SizedBox(height: 8), mp3]);
        }
        return Row(
          children: [
            Expanded(child: wav),
            const SizedBox(width: 10),
            Expanded(child: mp3),
          ],
        );
      },
    );
  }
}

class _FormatCard extends StatelessWidget {
  const _FormatCard({
    required this.format,
    required this.selected,
    required this.description,
    required this.size,
    required this.onTap,
  });

  final ExportFormat format;
  final bool selected;
  final String description;
  final String size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: .085)
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(7),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        key: ValueKey('export-format-${format.name}'),
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 11, 11),
          child: Row(
            children: [
              Icon(
                format == ExportFormat.wav
                    ? Icons.waves
                    : Icons.audio_file_outlined,
                size: 21,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          format.label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          format == ExportFormat.wav
                              ? 'LOSSLESS'
                              : 'COMPRESSED',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 9,
                                letterSpacing: .35,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(size, style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, size: 17, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class ExportQualitySelector extends StatelessWidget {
  const ExportQualitySelector({
    super.key,
    required this.bitrateKbps,
    required this.onChanged,
  });

  final int bitrateKbps;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final hint = Text(
              'Higher bitrate increases quality and file size.',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            );
            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ExportSectionLabel('MP3 QUALITY'),
                  const SizedBox(height: _ExportSpacing.xs),
                  hint,
                ],
              );
            }
            return Row(
              children: [
                const Expanded(child: ExportSectionLabel('MP3 QUALITY')),
                hint,
              ],
            );
          },
        ),
        const SizedBox(height: _ExportSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              for (final bitrate in supportedMp3BitratesKbps)
                Expanded(
                  child: _QualityOption(
                    bitrate: bitrate,
                    selected: bitrate == bitrateKbps,
                    onTap: () => onChanged(bitrate),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: _ExportSpacing.sm),
        Text(
          switch (bitrateKbps) {
            128 => 'SMALL FILE',
            192 => 'BALANCED',
            256 => 'HIGH QUALITY  \u00b7  RECOMMENDED',
            _ => 'MAXIMUM MP3 QUALITY',
          },
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: .45,
          ),
        ),
      ],
    );
  }
}

class _QualityOption extends StatelessWidget {
  const _QualityOption({
    required this.bitrate,
    required this.selected,
    required this.onTap,
  });

  final int bitrate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = switch (bitrate) {
      128 => 'SMALL',
      192 => 'BALANCED',
      256 => 'HIGH',
      _ => 'MAX',
    };
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? colors.primary.withValues(alpha: .11)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Column(
          children: [
            Text(
              '$bitrate',
              style: TextStyle(
                color: selected ? colors.primary : colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 8,
                letterSpacing: .25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExportMetadataSection extends StatefulWidget {
  const ExportMetadataSection({
    super.key,
    required this.titleController,
    required this.artistController,
    required this.albumController,
    required this.yearController,
    required this.trackController,
    required this.genreController,
    required this.commentController,
  });

  final TextEditingController titleController;
  final TextEditingController artistController;
  final TextEditingController albumController;
  final TextEditingController yearController;
  final TextEditingController trackController;
  final TextEditingController genreController;
  final TextEditingController commentController;

  @override
  State<ExportMetadataSection> createState() => _ExportMetadataSectionState();
}

class _ExportMetadataSectionState extends State<ExportMetadataSection> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(_ExportSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExportSectionLabel('METADATA'),
          const SizedBox(height: _ExportSpacing.xs),
          Text(
            'Optional  \u00b7  Embedded in the exported MP3',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: _ExportSpacing.md),
          _MetadataField(label: 'Title', controller: widget.titleController),
          const SizedBox(height: _ExportSpacing.md),
          _MetadataField(label: 'Artist', controller: widget.artistController),
          const SizedBox(height: _ExportSpacing.md),
          _MetadataField(label: 'Album', controller: widget.albumController),
          const SizedBox(height: _ExportSpacing.md),
          InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () => setState(() => _showMore = !_showMore),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _ExportSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    _showMore ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'MORE TAGS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Year  \u00b7  Track  \u00b7  Genre  \u00b7  Comment',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _showMore
                ? Padding(
                    padding: const EdgeInsets.only(top: _ExportSpacing.md),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 78,
                              child: _MetadataField(
                                label: 'Year',
                                controller: widget.yearController,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: _ExportSpacing.sm),
                            SizedBox(
                              width: 72,
                              child: _MetadataField(
                                label: 'Track',
                                controller: widget.trackController,
                                compact: true,
                              ),
                            ),
                            const SizedBox(width: _ExportSpacing.sm),
                            Expanded(
                              child: _MetadataField(
                                label: 'Genre',
                                controller: widget.genreController,
                                compact: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: _ExportSpacing.md),
                        _MetadataField(
                          label: 'Comment',
                          controller: widget.commentController,
                          minLines: 2,
                          maxLines: 2,
                          compact: true,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _MetadataField extends StatelessWidget {
  const _MetadataField({
    required this.label,
    required this.controller,
    this.compact = false,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final bool compact;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final input = TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: TextStyle(fontSize: compact ? 12 : 13),
      decoration: exportFieldDecoration(null, compact: compact),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: _ExportSpacing.fieldLabel),
        if (maxLines == 1) SizedBox(height: 38, child: input) else input,
      ],
    );
  }
}

class _WavAdvancedNote extends StatelessWidget {
  const _WavAdvancedNote();

  @override
  Widget build(BuildContext context) {
    return const ExportInlineNotice(
      icon: Icons.waves,
      text:
          'WAV exports full-quality stereo PCM. Metadata is not embedded in V1.',
    );
  }
}

class ExportSummaryCard extends StatelessWidget {
  const ExportSummaryCard({
    super.key,
    required this.format,
    required this.bitrateKbps,
    required this.renderInfo,
    required this.estimatedBytes,
    required this.fileName,
    this.compact = false,
  });

  final ExportFormat format;
  final int bitrateKbps;
  final ExportRenderInfo? renderInfo;
  final int estimatedBytes;
  final String fileName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = renderInfo == null
        ? '\u2014'
        : formatExportDuration(renderInfo!.durationSeconds);
    final sampleRate = renderInfo == null
        ? '\u2014'
        : '${(renderInfo!.sampleRate / 1000).toStringAsFixed(renderInfo!.sampleRate % 1000 == 0 ? 0 : 1)} kHz';
    final quality = format == ExportFormat.wav
        ? 'Lossless PCM'
        : '$bitrateKbps kbps';

    return Container(
      padding: const EdgeInsets.all(_ExportSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(7),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExportSectionLabel('EXPORT SUMMARY'),
                const SizedBox(height: _ExportSpacing.md),
                Text(
                  format.label,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(quality, style: TextStyle(color: colors.onSurfaceVariant)),
                const SizedBox(height: _ExportSpacing.md),
                Text(
                  duration,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Stereo  \u00b7  $sampleRate',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: _ExportSpacing.lg),
                Text(
                  'ESTIMATED SIZE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: .55,
                  ),
                ),
                const SizedBox(height: _ExportSpacing.xs),
                Text(
                  formatExportBytes(estimatedBytes, approximate: true),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: _ExportSpacing.fieldLabel),
                Text(
                  'Actual size shown after encoding.',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: _ExportSpacing.md),
                Text(
                  fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ExportSectionLabel('EXPORT SUMMARY'),
                const SizedBox(height: _ExportSpacing.md),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final metrics = Wrap(
                      spacing: 26,
                      runSpacing: 10,
                      children: [
                        _SummaryMetric('FORMAT', format.label),
                        _SummaryMetric('QUALITY', quality),
                        _SummaryMetric('DURATION', duration),
                        _SummaryMetric('OUTPUT', 'Stereo  \u00b7  $sampleRate'),
                      ],
                    );
                    final size = _EstimatedSize(value: estimatedBytes);
                    if (constraints.maxWidth < 520) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          metrics,
                          const SizedBox(height: _ExportSpacing.lg),
                          size,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: metrics),
                        Container(
                          width: 1,
                          height: 52,
                          margin: const EdgeInsets.symmetric(
                            horizontal: _ExportSpacing.lg,
                          ),
                          color: colors.outlineVariant,
                        ),
                        size,
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 94,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 9,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: _ExportSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _EstimatedSize extends StatelessWidget {
  const _EstimatedSize({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ESTIMATED SIZE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 9,
            letterSpacing: .5,
          ),
        ),
        const SizedBox(height: _ExportSpacing.xs),
        Text(
          formatExportBytes(value, approximate: true),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          'Actual after encoding',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class ExportProcessingView extends StatelessWidget {
  const ExportProcessingView({
    super.key,
    required this.stage,
    required this.format,
    required this.bitrateKbps,
  });

  final ExportGenerationStage stage;
  final ExportFormat format;
  final int bitrateKbps;

  int get _activeIndex => switch (stage) {
    ExportGenerationStage.rendering => 0,
    ExportGenerationStage.preparingWav ||
    ExportGenerationStage.encodingMp3 => 1,
    ExportGenerationStage.metadata => 2,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = switch (stage) {
      ExportGenerationStage.rendering => 'Rendering your mix',
      ExportGenerationStage.preparingWav => 'Preparing WAV',
      ExportGenerationStage.encodingMp3 => 'Encoding MP3',
      ExportGenerationStage.metadata => 'Finalizing export',
    };
    final detail = switch (stage) {
      ExportGenerationStage.rendering =>
        'Applying tracks, FX, mixer and master processing.',
      ExportGenerationStage.preparingWav =>
        'Creating the full-quality stereo PCM file.',
      ExportGenerationStage.encodingMp3 =>
        'Creating a $bitrateKbps kbps compressed audio file.',
      ExportGenerationStage.metadata => 'Adding your MP3 tags.',
    };
    final steps = format == ExportFormat.mp3
        ? const [
            ('RENDER', 'Mix audio'),
            ('ENCODE', 'MP3'),
            ('FINISH', 'Metadata'),
          ]
        : const [
            ('RENDER', 'Mix audio'),
            ('PREPARE', 'WAV file'),
            ('FINISH', 'Download'),
          ];

    return ConstrainedBox(
      key: const ValueKey('generating'),
      constraints: const BoxConstraints(minHeight: 430),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'PREPARING YOUR EXPORT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 19),
              const ProcessingWaveIndicator(),
              const SizedBox(height: 18),
              Text(
                'Generating export...',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              ExportProcessingStepper(steps: steps, activeIndex: _activeIndex),
              const SizedBox(height: 25),
              const ExportPrivacyNote(centered: true),
            ],
          ),
        ),
      ),
    );
  }
}

class ExportProcessingStepper extends StatelessWidget {
  const ExportProcessingStepper({
    super.key,
    required this.steps,
    required this.activeIndex,
  });

  final List<(String, String)> steps;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 72,
      child: Stack(
        children: [
          Positioned(
            left: 70,
            right: 70,
            top: 15,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: activeIndex >= 1
                        ? colors.primary
                        : colors.outlineVariant,
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: activeIndex >= 2
                        ? colors.primary
                        : colors.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              for (var index = 0; index < steps.length; index++)
                Expanded(
                  child: _ProcessingStep(
                    title: steps[index].$1,
                    subtitle: steps[index].$2,
                    state: index < activeIndex
                        ? _StepState.complete
                        : index == activeIndex
                        ? _StepState.active
                        : _StepState.pending,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _StepState { pending, active, complete }

class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep({
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String title;
  final String subtitle;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final emphasized = state != _StepState.pending;
    return Column(
      children: [
        Container(
          width: 31,
          height: 31,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == _StepState.complete
                ? colors.primary
                : colors.surfaceContainer,
            border: Border.all(
              color: emphasized ? colors.primary : colors.outlineVariant,
              width: state == _StepState.active ? 2 : 1,
            ),
            boxShadow: state == _StepState.active
                ? [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: .2),
                      blurRadius: 9,
                    ),
                  ]
                : null,
          ),
          child: state == _StepState.complete
              ? Icon(Icons.check, size: 17, color: colors.onPrimary)
              : state == _StepState.active
              ? Center(
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 7),
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: emphasized ? colors.onSurface : colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: .45,
          ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

class ProcessingWaveIndicator extends StatefulWidget {
  const ProcessingWaveIndicator({super.key});

  @override
  State<ProcessingWaveIndicator> createState() =>
      _ProcessingWaveIndicatorState();
}

class _ProcessingWaveIndicatorState extends State<ProcessingWaveIndicator> {
  Timer? _timer;
  double _phase = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (!MediaQuery.disableAnimationsOf(context)) {
      _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
        if (mounted) setState(() => _phase += .45);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 156,
      height: 36,
      child: CustomPaint(
        painter: _ProcessingWavePainter(
          phase: _phase,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ProcessingWavePainter extends CustomPainter {
  const _ProcessingWavePainter({required this.phase, required this.color});

  final double phase;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 13;
    const width = 4.0;
    final gap = (size.width - bars * width) / (bars - 1);
    final paint = Paint()
      ..color = color.withValues(alpha: .78)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    for (var index = 0; index < bars; index++) {
      final wave = (math.sin(phase + index * .72) + 1) / 2;
      final envelope = .45 + .55 * math.sin(math.pi * index / (bars - 1));
      final height = 5 + wave * 24 * envelope;
      final x = index * (width + gap) + width / 2;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ProcessingWavePainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.color != color;
}

class ExportReadyView extends StatelessWidget {
  const ExportReadyView({
    super.key,
    required this.result,
    required this.bitrateKbps,
    required this.estimatedBytes,
    required this.positionSeconds,
    required this.isPlaying,
    required this.previewError,
    required this.onPlayPause,
    required this.onSeek,
  });

  final GeneratedExport result;
  final int bitrateKbps;
  final int estimatedBytes;
  final double positionSeconds;
  final bool isPlaying;
  final String? previewError;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formatSummary = result.format == ExportFormat.mp3
        ? 'MP3  \u00b7  $bitrateKbps kbps  \u00b7  Stereo'
        : 'WAV  \u00b7  Lossless PCM  \u00b7  Stereo';
    return ConstrainedBox(
      key: const ValueKey('ready'),
      constraints: const BoxConstraints(minHeight: 430),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 590),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary.withValues(alpha: .13),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: .45),
                    ),
                  ),
                  child: Icon(Icons.check, color: colors.primary, size: 27),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ready to export',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: .2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                result.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                formatSummary,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatExportDuration(result.durationSeconds),
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  Text(
                    '  \u00b7  ${formatExportBytes(result.bytes.length)}',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (estimatedBytes > 0) ...[
                const SizedBox(height: 3),
                Text(
                  'Estimated ${formatExportBytes(estimatedBytes, approximate: true)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 14, 9),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  border: Border.all(color: colors.outlineVariant),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: isPlaying ? 'Pause preview' : 'Play preview',
                          onPressed: onPlayPause,
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(formatExportDuration(positionSeconds)),
                        Expanded(
                          child: Slider(
                            value: positionSeconds.clamp(
                              0.0,
                              result.durationSeconds,
                            ),
                            min: 0,
                            max: result.durationSeconds,
                            onChanged: onSeek,
                          ),
                        ),
                        Text(formatExportDuration(result.durationSeconds)),
                      ],
                    ),
                    if (previewError != null)
                      Text(
                        previewError!,
                        style: TextStyle(color: colors.error),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              const ExportPrivacyNote(centered: true),
            ],
          ),
        ),
      ),
    );
  }
}

class ExportFileNameField extends StatelessWidget {
  const ExportFileNameField({
    super.key,
    required this.controller,
    required this.format,
  });

  final TextEditingController controller;
  final ExportFormat format;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const ValueKey('export-file-name'),
      controller: controller,
      decoration: exportFieldDecoration(
        'Filename',
        suffix: Text('.${format.extension}'),
      ),
    );
  }
}

class ExportPrivacyNote extends StatelessWidget {
  const ExportPrivacyNote({super.key, this.centered = false});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.shield_outlined, size: 13, color: colors.onSurfaceVariant),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            'Rendered locally  \u00b7  Your audio is not uploaded',
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
    return centered ? Center(child: row) : row;
  }
}

class ExportInlineNotice extends StatelessWidget {
  const ExportInlineNotice({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .07),
        border: Border.all(color: tone.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: tone),
          const SizedBox(width: 7),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class ExportSectionLabel extends StatelessWidget {
  const ExportSectionLabel(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: .72,
      ),
    );
  }
}

InputDecoration exportFieldDecoration(
  String? label, {
  Widget? suffix,
  bool compact = false,
}) {
  return InputDecoration(
    labelText: label,
    suffix: suffix,
    isDense: true,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 10,
      vertical: compact ? 9 : 10,
    ),
    constraints: const BoxConstraints(minHeight: 38),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
  );
}

String formatExportBytes(int bytes, {bool approximate = false}) {
  if (bytes <= 0) return '\u2014';
  final prefix = approximate ? '~' : '';
  if (bytes >= 1024 * 1024) {
    return '$prefix${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  if (bytes >= 1024) {
    return '$prefix${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$prefix$bytes B';
}
