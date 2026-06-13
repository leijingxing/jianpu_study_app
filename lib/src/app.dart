import 'package:flutter/material.dart';

import 'data/app_settings.dart';
import 'home/home_page.dart';
import 'pro/jianpu_maker_page.dart';
import 'pro/jianpu_practice_page.dart';
import 'pro/metronome_page.dart';
import 'pro/scale_lab_page.dart';
import 'theme/app_theme.dart';

class JianpuStudyApp extends StatefulWidget {
  const JianpuStudyApp({super.key});

  @override
  State<JianpuStudyApp> createState() => _JianpuStudyAppState();
}

class _JianpuStudyAppState extends State<JianpuStudyApp> {
  final _settings = AppSettings();

  @override
  void initState() {
    super.initState();
    _settings.load();
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settings,
      builder: (context, _) {
        return MaterialApp(
          title: '轻谱',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(brightness: Brightness.light),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: _themeModeOf(_settings.themeMode),
          home: HomePage(settings: _settings),
          routes: {
            JianpuMakerPage.routeName: (_) =>
                JianpuMakerPage(settings: _settings),
            JianpuPracticePage.routeName: (_) =>
                JianpuPracticePage(settings: _settings),
            MetronomePage.routeName: (_) => const MetronomePage(),
            ScaleLabPage.routeName: (_) => ScaleLabPage(settings: _settings),
          },
        );
      },
    );
  }

  ThemeMode _themeModeOf(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
  }
}
