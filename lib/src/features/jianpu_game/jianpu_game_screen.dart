import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'jianpu_game_engine.dart';
import 'jianpu_game_view_model.dart';

final class JianpuGameScreen extends ConsumerWidget {
  const JianpuGameScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(jianpuGameViewModelProvider);
    final viewModel = ref.read(jianpuGameViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('简谱游戏')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('得分 ${state.score}'),
                Text('连击 ${state.combo}'),
                Text('${(state.timeLeftMs / 1000).ceil()} 秒'),
              ],
            ),
            const Spacer(),
            if (state.gameState == GameState.playing) ...[
              Text(
                state.currentNote,
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 40),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var degree = 1; degree <= 7; degree++)
                    FilledButton.tonal(
                      onPressed: () => viewModel.answer('$degree'),
                      child: Text('$degree'),
                    ),
                ],
              ),
            ] else
              FilledButton.icon(
                onPressed: viewModel.start,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  state.gameState == GameState.gameOver ? '再来一局' : '开始游戏',
                ),
              ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
