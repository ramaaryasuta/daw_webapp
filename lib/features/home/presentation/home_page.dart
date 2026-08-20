import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Flutter DAW',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Simple Digital Audio Workstation'),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                context.goNamed(RouteNames.editor);
              },
              icon: const Icon(Icons.music_note),
              label: const Text('Open Editor'),
            ),
          ],
        ),
      ),
    );
  }
}
