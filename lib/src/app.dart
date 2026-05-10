import 'package:flutter/material.dart';

import 'data/app_settings.dart';
import 'home/home_page.dart';
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
          theme: buildAppTheme(style: _settings.uiStyle),
          home: HomePage(settings: _settings),
        );
      },
    );
  }
}
