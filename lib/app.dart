import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'ui/app_controller.dart';
import 'ui/chart/chart_screen.dart';

/// Root widget. Rebuilds on [AppController] changes so the theme mode applies
/// app-wide.
class RiseApp extends StatelessWidget {
  final AppController controller;

  const RiseApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => MaterialApp(
        title: 'Rise',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: controller.themeMode,
        home: ChartScreen(controller: controller),
      ),
    );
  }
}
