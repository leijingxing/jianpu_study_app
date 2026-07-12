import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models/score.dart';
import '../features/home/home_screen.dart';
import '../features/dynamic_score/dynamic_score_screen.dart';
import '../features/dynamic_score/dynamic_score_view_model.dart';
import '../features/search/search_screen.dart';
import '../features/image_score/image_score_screen.dart';
import '../features/image_score/image_score_view_model.dart';
import '../features/resource_detail/yuepu_resource_screen.dart';
import '../features/resource_detail/yuepu_resource_view_model.dart';
import '../features/instrument_analyzer/instrument_analyzer_screen.dart';
import '../features/jianpu_game/jianpu_game_screen.dart';
import '../features/jianpu_maker/jianpu_maker_screen.dart';
import '../features/metronome/metronome_screen.dart';
import '../features/scale_lab/scale_lab_screen.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.search,
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.dynamicScore,
        builder: (context, state) {
          final score = state.extra! as MusicSummary;
          if (score.isYuepu) {
            return ProviderScope(
              overrides: [currentYuepuScoreProvider.overrideWithValue(score)],
              child: const YuepuResourceScreen(),
            );
          }
          return ProviderScope(
            overrides: [currentDynamicScoreProvider.overrideWithValue(score)],
            child: const DynamicScoreScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.imageScore,
        builder: (context, state) {
          final score = state.extra! as ImageScoreItem;
          return ProviderScope(
            overrides: [currentImageScoreProvider.overrideWithValue(score)],
            child: const ImageScoreScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.maker,
        builder: (context, state) => const JianpuMakerScreen(),
      ),
      GoRoute(
        path: AppRoutes.game,
        builder: (context, state) => const JianpuGameScreen(),
      ),
      GoRoute(
        path: AppRoutes.metronome,
        builder: (context, state) => const MetronomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.scaleLab,
        builder: (context, state) => const ScaleLabScreen(),
      ),
      GoRoute(
        path: AppRoutes.analyzer,
        builder: (context, state) => const InstrumentAnalyzerScreen(),
      ),
    ],
    errorBuilder: (context, state) => const _RouteNotFoundScreen(),
  );
});

class _RouteNotFoundScreen extends StatelessWidget {
  const _RouteNotFoundScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('页面不存在')),
    body: Center(
      child: FilledButton(
        onPressed: () => context.go(AppRoutes.home),
        child: const Text('返回首页'),
      ),
    ),
  );
}
