import 'dart:math' as math;

import 'package:flutter/material.dart';

abstract final class LandingPalette {
  static const background = Color(0xFF090A0E);
  static const surface = Color(0xFF111218);
  static const surfaceRaised = Color(0xFF171820);
  static const border = Color(0xFF2B2C36);
  static const accent = Color(0xFF9B7BFF);
  static const accentBright = Color(0xFFB49CFF);
  static const text = Color(0xFFF3F1F8);
  static const muted = Color(0xFFA7A4B1);
}

const _logoAsset = 'assets/icons/flaudio.webp';
const _arrangementAsset = 'assets/showcase/flawdio_clip_properties.png';
const _effectsAsset = 'assets/showcase/flaudio_effect.png';
const _maxContentWidth = 1180.0;

class LandingBackground extends StatelessWidget {
  const LandingBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _LandingBackgroundPainter()),
    );
  }
}

class _LandingBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0x2C6E42DC), Color(0x006E42DC)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.68, 280),
              radius: math.min(size.width * 0.5, 620),
            ),
          );
    canvas.drawRect(Offset.zero & size, glowPaint);

    final gridPaint = Paint()
      ..color = const Color(0x0CFFFFFF)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 150; y < size.height; y += 56) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ContentWidth extends StatelessWidget {
  const _ContentWidth({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: child,
        ),
      ),
    );
  }
}

class LandingNav extends StatelessWidget {
  const LandingNav({
    required this.onOpenEditor,
    required this.onFeatures,
    required this.onPrivacy,
    required this.onAbout,
    super.key,
  });

  final VoidCallback onOpenEditor;
  final VoidCallback onFeatures;
  final VoidCallback onPrivacy;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    return _ContentWidth(
      child: SizedBox(
        height: 74,
        child: Row(
          children: [
            Semantics(
              label: 'Flaudio home',
              header: true,
              child: Row(
                children: [
                  Image.asset(
                    _logoAsset,
                    width: 34,
                    height: 34,
                    semanticLabel: 'Flaudio logo',
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Flaudio',
                    style: TextStyle(
                      color: LandingPalette.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            if (MediaQuery.sizeOf(context).width >= 720) ...[
              _NavButton(label: 'Features', onPressed: onFeatures),
              _NavButton(label: 'Privacy', onPressed: onPrivacy),
              _NavButton(label: 'About', onPressed: onAbout),
              const SizedBox(width: 12),
            ],
            _PrimaryButton(
              label: 'Open Editor',
              onPressed: onOpenEditor,
              compact: true,
              key: const ValueKey('nav-open-editor'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: LandingPalette.muted,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}

class HeroSection extends StatelessWidget {
  const HeroSection({
    required this.entrance,
    required this.onOpenEditor,
    required this.onSeeInside,
    super.key,
  });

  final Animation<double> entrance;
  final VoidCallback onOpenEditor;
  final VoidCallback onSeeInside;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final copy = _Entrance(
      animation: CurvedAnimation(
        parent: entrance,
        curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
      ),
      offset: 18,
      child: _HeroCopy(
        onOpenEditor: onOpenEditor,
        onSeeInside: onSeeInside,
        wide: wide,
      ),
    );
    final showcase = _Entrance(
      animation: CurvedAnimation(
        parent: entrance,
        curve: const Interval(0.25, 1, curve: Curves.easeOutCubic),
      ),
      offset: 22,
      scaleFrom: 0.985,
      child: HeroShowcase(wide: wide),
    );

    return _ContentWidth(
      child: Padding(
        padding: EdgeInsets.only(top: wide ? 70 : 42, bottom: wide ? 116 : 82),
        child: Column(
          children: [
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 9, child: copy),
                  const SizedBox(width: 48),
                  Expanded(flex: 13, child: showcase),
                ],
              )
            else ...[
              copy,
              const SizedBox(height: 50),
              showcase,
            ],
            const SizedBox(height: 48),
            const _TrustStrip(),
          ],
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({
    required this.onOpenEditor,
    required this.onSeeInside,
    required this.wide,
  });

  final VoidCallback onOpenEditor;
  final VoidCallback onSeeInside;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        const _Eyebrow(label: 'BROWSER-BASED AUDIO WORKSTATION'),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(
            'A full DAW.\nRight in your browser.',
            textAlign: wide ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              color: LandingPalette.text,
              fontSize: wide ? 58 : 44,
              height: 1.02,
              letterSpacing: wide ? -2.5 : -1.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Arrange, edit, mix and export audio without installing anything. '
          'Flaudio is free, ad-free, account-free, and built around your privacy.',
          textAlign: wide ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            color: LandingPalette.muted,
            fontSize: 17,
            height: 1.62,
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            _PrimaryButton(
              key: const ValueKey('hero-open-editor'),
              label: 'Open Flaudio',
              onPressed: onOpenEditor,
              icon: Icons.arrow_outward_rounded,
            ),
            OutlinedButton(
              onPressed: onSeeInside,
              style: OutlinedButton.styleFrom(
                foregroundColor: LandingPalette.text,
                side: const BorderSide(color: LandingPalette.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text("See what's inside"),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 7,
          children: [
            const Icon(
              Icons.desktop_windows_outlined,
              size: 14,
              color: Color(0xFF777581),
            ),
            Text(
              'Best experienced on desktop',
              style: TextStyle(
                color: LandingPalette.muted.withValues(alpha: 0.68),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.animation,
    required this.child,
    this.offset = 0,
    this.scaleFrom = 1,
  });

  final Animation<double> animation;
  final Widget child;
  final double offset;
  final double scaleFrom;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - value)),
            child: Transform.scale(
              scale: scaleFrom + ((1 - scaleFrom) * value),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class HeroShowcase extends StatelessWidget {
  const HeroShowcase({required this.wide, super.key});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        children: [
          const _ScreenshotFrame(
            asset: _arrangementAsset,
            semanticLabel: 'Flaudio multitrack arrangement editor',
            title: 'ARRANGEMENT',
          ),
          const SizedBox(height: 18),
          FractionallySizedBox(
            widthFactor: 0.84,
            child: const _ScreenshotFrame(
              asset: _effectsAsset,
              semanticLabel: 'Flaudio Track FX rack and 3-Band EQ',
              title: 'TRACK FX',
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: width * 0.65,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                right: 0,
                width: width * 0.56,
                child: Transform.rotate(
                  angle: 0.015,
                  child: const _ScreenshotFrame(
                    asset: _effectsAsset,
                    semanticLabel: 'Flaudio Track FX rack and 3-Band EQ',
                    title: 'TRACK FX',
                  ),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 0,
                width: width * 0.91,
                child: Transform.rotate(
                  angle: -0.008,
                  child: const _ScreenshotFrame(
                    asset: _arrangementAsset,
                    semanticLabel: 'Flaudio multitrack arrangement editor',
                    title: 'ARRANGEMENT',
                  ),
                ),
              ),
              const Positioned(
                left: -12,
                top: 82,
                child: _Callout(label: 'Multi-track editing'),
              ),
              const Positioned(
                right: -8,
                bottom: 24,
                child: _Callout(label: 'Non-destructive workflow'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScreenshotFrame extends StatelessWidget {
  const _ScreenshotFrame({
    required this.asset,
    required this.semanticLabel,
    required this.title,
  });

  final String asset;
  final String semanticLabel;
  final String title;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF101116),
        border: Border.all(color: const Color(0xFF41404B)),
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(
            color: Color(0x5C000000),
            blurRadius: 34,
            offset: Offset(0, 18),
          ),
          BoxShadow(color: Color(0x207D55EF), blurRadius: 38),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 28,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    for (final color in const [
                      Color(0xFF5D5B65),
                      Color(0xFF6D5E83),
                      Color(0xFF8B6FD7),
                    ]) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    const Spacer(),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF777581),
                        fontSize: 8,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AspectRatio(
              aspectRatio: 1919 / 914,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                semanticLabel: semanticLabel,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xF216171D),
        border: Border.all(color: const Color(0xFF484450)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: LandingPalette.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFC9C5D2),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  static const labels = [
    'Free access',
    'No ads',
    'No login',
    'No install',
    'Local-first',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: LandingPalette.border),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runAlignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 12,
        children: [
          for (final label in labels)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: LandingPalette.accent,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFC1BDC9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class BenefitsSection extends StatelessWidget {
  const BenefitsSection({super.key});

  static const benefits = [
    (
      Icons.all_inclusive_rounded,
      'Free, full access',
      'No paid tier blocking core editing tools. Open Flaudio and start creating.',
    ),
    (
      Icons.block_rounded,
      'No ads',
      'No banners, popups, sponsored interruptions, or ad-driven workflow.',
    ),
    (
      Icons.person_off_outlined,
      'No account required',
      'No registration or login before you can work with audio.',
    ),
    (
      Icons.install_desktop_outlined,
      'Nothing to install',
      'Flaudio runs directly in a modern browser. No updater or setup.',
    ),
    (
      Icons.shield_outlined,
      'Private by design',
      'Imported audio and project data stay on your device—not a Flaudio server.',
    ),
    (
      Icons.folder_copy_outlined,
      'Your project is yours',
      'Save portable .flaudioproject files and keep ownership of your work.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow(label: 'WHY FLAUDIO'),
          const SizedBox(height: 14),
          const _SectionTitle(
            title: "Everything you need.\nNothing you don't.",
            subtitle:
                'A focused audio workspace with no gatekeeping between you and the timeline.',
          ),
          const SizedBox(height: 40),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 980
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              const gap = 12.0;
              final itemWidth =
                  (constraints.maxWidth - (gap * (columns - 1))) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final benefit in benefits)
                    SizedBox(
                      width: itemWidth,
                      child: _BenefitCard(
                        icon: benefit.$1,
                        title: benefit.$2,
                        copy: benefit.$3,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.copy,
  });

  final IconData icon;
  final String title;
  final String copy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title. $copy',
      child: Container(
        constraints: const BoxConstraints(minHeight: 170),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: LandingPalette.surface.withValues(alpha: 0.84),
          border: Border.all(color: LandingPalette.border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: LandingPalette.accentBright, size: 22),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: LandingPalette.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              copy,
              style: const TextStyle(
                color: LandingPalette.muted,
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Container(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width >= 700 ? 48 : 26,
        ),
        decoration: BoxDecoration(
          color: const Color(0xE6121118),
          border: Border.all(color: const Color(0xFF393343)),
          borderRadius: BorderRadius.circular(9),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Eyebrow(label: 'LOCAL-FIRST BY DESIGN'),
                const SizedBox(height: 16),
                const _SectionTitle(
                  title: 'Your audio stays yours.',
                  subtitle:
                      'Your imported audio and Flaudio project files are processed inside your browser and are not stored on a Flaudio server.',
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your audio. Your project. Your files.',
                  style: TextStyle(
                    color: LandingPalette.accentBright,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
            const diagram = _LocalFlowDiagram();
            if (wide) {
              return Row(
                children: [
                  Expanded(flex: 6, child: copy),
                  const SizedBox(width: 60),
                  const Expanded(flex: 5, child: diagram),
                ],
              );
            }
            return Column(
              children: [copy, const SizedBox(height: 42), diagram],
            );
          },
        ),
      ),
    );
  }
}

class _LocalFlowDiagram extends StatelessWidget {
  const _LocalFlowDiagram();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Your device processes audio in Flaudio and saves your project locally',
      child: Column(
        children: [
          const _FlowNode(icon: Icons.laptop_rounded, label: 'YOUR DEVICE'),
          const _FlowConnector(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF211A31),
              border: Border.all(color: const Color(0xFF7258B7)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  _logoAsset,
                  width: 24,
                  height: 24,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 10),
                const Text(
                  'FLAUDIO',
                  style: TextStyle(
                    color: LandingPalette.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
          const _FlowConnector(),
          const _FlowNode(
            icon: Icons.audio_file_outlined,
            label: 'YOUR PROJECT',
          ),
        ],
      ),
    );
  }
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: LandingPalette.surface,
        border: Border.all(color: LandingPalette.border),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFFAAA5B3), size: 17),
          const SizedBox(width: 9),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC3BFCA),
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowConnector extends StatelessWidget {
  const _FlowConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Column(
        children: [
          Expanded(child: Container(width: 1, color: const Color(0xFF51465F))),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 15,
            color: LandingPalette.accent,
          ),
        ],
      ),
    );
  }
}

class FeatureShowcaseSection extends StatelessWidget {
  const FeatureShowcaseSection({super.key});

  static const compactFeatures = [
    'Multi-track editing',
    'Dedicated Mixer',
    'Track FX chain',
    'WAV & MP3 export',
    'Local-first privacy',
    'Portable projects',
    'Undo / Redo',
    'Local autosave & recovery',
  ];

  @override
  Widget build(BuildContext context) {
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow(label: 'BUILT FOR THE SESSION'),
          const SizedBox(height: 14),
          const _SectionTitle(
            title: 'Arrange. Shape. Mix.',
            subtitle:
                'From the first clip to the final mix, the workflow stays in one focused workspace.',
          ),
          const SizedBox(height: 42),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 820;
              const screenshot = _ScreenshotFrame(
                asset: _effectsAsset,
                semanticLabel: 'Flaudio Track FX rack and 3-Band EQ',
                title: 'MIX & PROCESS',
              );
              const details = _FeatureDetails();
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(flex: 7, child: screenshot),
                    const SizedBox(width: 44),
                    const Expanded(flex: 4, child: details),
                  ],
                );
              }
              return const Column(
                children: [screenshot, SizedBox(height: 32), details],
              );
            },
          ),
          const SizedBox(height: 38),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              for (final feature in compactFeatures)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121319),
                    border: Border.all(color: LandingPalette.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    feature,
                    style: const TextStyle(
                      color: Color(0xFFB8B4C0),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureDetails extends StatelessWidget {
  const _FeatureDetails();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FeatureLine(
          number: '01',
          title: 'Multi-track arrangement',
          copy:
              'Trim, split, move, duplicate and reverse clips directly on the timeline.',
        ),
        SizedBox(height: 27),
        _FeatureLine(
          number: '02',
          title: 'Dedicated Mixer',
          copy:
              'Mix with channel faders, stereo pan, real-time meters, Track FX and Master processing in one workspace.',
        ),
        SizedBox(height: 27),
        _FeatureLine(
          number: '03',
          title: 'A real signal chain',
          copy:
              'Filter, 3-Band EQ, Compressor, Delay and Reverb in a reorderable Track FX rack.',
        ),
        SizedBox(height: 27),
        _FeatureLine(
          number: '04',
          title: 'WAV & MP3 Export',
          copy:
              'Export lossless WAV or compact MP3 files with quality controls and optional metadata — processed locally in your browser. No audio upload required.',
        ),
      ],
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.number,
    required this.title,
    required this.copy,
  });

  final String number;
  final String title;
  final String copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: LandingPalette.accent,
            fontSize: 10,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: LandingPalette.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                copy,
                style: const TextStyle(
                  color: LandingPalette.muted,
                  height: 1.52,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class BrowserStrip extends StatelessWidget {
  const BrowserStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return _ContentWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 52),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
          decoration: const BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: LandingPalette.border),
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 30,
            runSpacing: 14,
            children: const [
              Text(
                'Browser in. Music out.',
                style: TextStyle(
                  color: LandingPalette.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.7,
                ),
              ),
              Text(
                'No installer. No updater. No account setup.',
                style: TextStyle(color: LandingPalette.muted, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FinalSection extends StatelessWidget {
  const FinalSection({required this.onOpenEditor, super.key});

  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ContentWidth(
          child: Padding(
            padding: const EdgeInsets.only(top: 70, bottom: 92),
            child: Column(
              children: [
                Image.asset(
                  _logoAsset,
                  width: 62,
                  height: 62,
                  semanticLabel: 'Flaudio logo',
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your next session is\none click away.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: LandingPalette.text,
                    fontSize: 42,
                    height: 1.08,
                    letterSpacing: -1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No account. No installer. Just open Flaudio.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: LandingPalette.muted, fontSize: 15),
                ),
                const SizedBox(height: 28),
                _PrimaryButton(
                  key: const ValueKey('final-open-editor'),
                  label: 'Open Flaudio',
                  onPressed: onOpenEditor,
                  icon: Icons.arrow_outward_rounded,
                ),
              ],
            ),
          ),
        ),
        const _TechnicalNote(),
        const _Footer(),
      ],
    );
  }
}

class _TechnicalNote extends StatelessWidget {
  const _TechnicalNote();

  @override
  Widget build(BuildContext context) {
    return _ContentWidth(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LandingPalette.border)),
        ),
        child: const Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Icon(Icons.flutter_dash, size: 17, color: Color(0xFF777581)),
            Text(
              'Built with Flutter',
              style: TextStyle(
                color: Color(0xFFAAA6B1),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text('·', style: TextStyle(color: Color(0xFF5D5B65))),
            Text(
              'Experimental — exploring real-time audio production with Flutter Web.',
              style: TextStyle(color: Color(0xFF777581), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07080B),
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: _ContentWidth(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 28,
          runSpacing: 12,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  _logoAsset,
                  width: 25,
                  height: 25,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: 9),
                const Text(
                  'Flaudio',
                  style: TextStyle(
                    color: LandingPalette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Text(
              'Free browser-based digital audio workstation.',
              style: TextStyle(color: Color(0xFF777581), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _ContentWidth(
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: MediaQuery.sizeOf(context).width >= 700 ? 88 : 62,
        ),
        child: child,
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: LandingPalette.accent,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: LandingPalette.text,
              fontSize: 37,
              height: 1.12,
              letterSpacing: -1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 15),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 610),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: LandingPalette.muted,
              fontSize: 15,
              height: 1.62,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final style = FilledButton.styleFrom(
      foregroundColor: const Color(0xFF0B0711),
      backgroundColor: LandingPalette.accentBright,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 21,
        vertical: compact ? 13 : 17,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      textStyle: TextStyle(
        fontSize: compact ? 12 : 14,
        fontWeight: FontWeight.w800,
      ),
    );
    if (icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      iconAlignment: IconAlignment.end,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
