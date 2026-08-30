import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import 'widgets/landing_sections.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  final _featuresKey = GlobalKey();
  final _privacyKey = GlobalKey();
  final _aboutKey = GlobalKey();
  late final AnimationController _entranceController;
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _entranceController.value = 1;
    } else {
      _entranceController.forward();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openEditor() => context.goNamed(RouteNames.editor);

  Future<void> _scrollTo(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LandingPalette.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(child: LandingBackground()),
          ),
          SafeArea(
            bottom: false,
            child: Scrollbar(
              controller: _scrollController,
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: LandingNav(
                      onOpenEditor: _openEditor,
                      onFeatures: () => _scrollTo(_featuresKey),
                      onPrivacy: () => _scrollTo(_privacyKey),
                      onAbout: () => _scrollTo(_aboutKey),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: HeroSection(
                      entrance: _entranceController,
                      onOpenEditor: _openEditor,
                      onSeeInside: () => _scrollTo(_featuresKey),
                    ),
                  ),
                  SliverToBoxAdapter(child: BenefitsSection(key: _featuresKey)),
                  SliverToBoxAdapter(child: PrivacySection(key: _privacyKey)),
                  const SliverToBoxAdapter(child: FeatureShowcaseSection()),
                  const SliverToBoxAdapter(child: BrowserStrip()),
                  SliverToBoxAdapter(
                    child: FinalSection(
                      key: _aboutKey,
                      onOpenEditor: _openEditor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
