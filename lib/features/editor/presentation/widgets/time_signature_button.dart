import 'package:flutter/material.dart';

import '../../domain/musical_timing.dart';

class TimeSignatureButton extends StatefulWidget {
  const TimeSignatureButton({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final TimeSignature selected;
  final ValueChanged<TimeSignature> onSelected;

  @override
  State<TimeSignatureButton> createState() => _TimeSignatureButtonState();
}

class _TimeSignatureButtonState extends State<TimeSignatureButton> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: 'Time Signature ${widget.selected.label}',
      child: PopupMenuButton<TimeSignature>(
        key: const ValueKey('time-signature-control'),
        tooltip: 'Time Signature',
        initialValue: widget.selected,
        onOpened: () => setState(() => _isOpen = true),
        onCanceled: () => setState(() => _isOpen = false),
        onSelected: (signature) {
          setState(() => _isOpen = false);
          widget.onSelected(signature);
        },
        color: colors.surfaceContainerHigh,
        elevation: 8,
        offset: const Offset(0, 4),
        constraints: const BoxConstraints(minWidth: 224, maxWidth: 236),
        position: PopupMenuPosition.under,
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(color: colors.outlineVariant),
        ),
        itemBuilder: (context) => [
          PopupMenuItem<TimeSignature>(
            enabled: false,
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'TIME SIGNATURE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
          for (final signature in TimeSignature.supported)
            PopupMenuItem<TimeSignature>(
              key: ValueKey('time-signature-${signature.label}'),
              value: signature,
              height: 38,
              padding: EdgeInsets.zero,
              child: Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                color: signature == widget.selected
                    ? colors.primaryContainer.withValues(alpha: 0.72)
                    : Colors.transparent,
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: signature == widget.selected
                          ? Icon(Icons.check, size: 16, color: colors.primary)
                          : null,
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 34,
                      child: Text(
                        signature.label,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: signature == widget.selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _meterName(signature),
                        maxLines: 1,
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
        ],
        child: AnimatedContainer(
          key: const ValueKey('time-signature-trigger-surface'),
          duration: const Duration(milliseconds: 120),
          height: 36,
          padding: const EdgeInsets.fromLTRB(10, 0, 7, 0),
          decoration: BoxDecoration(
            color: _isOpen
                ? colors.primaryContainer.withValues(alpha: 0.48)
                : colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isOpen
                  ? colors.primary.withValues(alpha: 0.8)
                  : colors.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.selected.label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _isOpen ? colors.onPrimaryContainer : null,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 3),
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 120),
                child: Icon(
                  Icons.arrow_drop_down,
                  size: 17,
                  color: _isOpen
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _meterName(TimeSignature signature) => switch (signature) {
  TimeSignature.commonTime => 'Common time',
  TimeSignature.threeFour => 'Triple meter',
  TimeSignature.sixEight => 'Compound meter',
  _ => 'Meter',
};
