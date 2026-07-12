import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_settings.dart';
import '../routing/app_router.dart';
import '../theme/app_theme.dart';
import 'app_dependencies.dart';

class JianpuStudyApp extends ConsumerWidget {
  const JianpuStudyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => MaterialApp.router(
        title: '轻谱',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(brightness: Brightness.light),
        darkTheme: buildAppTheme(brightness: Brightness.dark),
        themeMode: switch (settings.themeMode) {
          AppThemeMode.system => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        routerConfig: router,
      ),
    );
  }
}
