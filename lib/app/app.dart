import 'package:daw_webapp/app/router/app_router.dart';
import 'package:daw_webapp/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class DawApp extends StatelessWidget {
  const DawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter DAW',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
