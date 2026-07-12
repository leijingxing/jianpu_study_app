import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'metronome_view_model.dart';

final class MetronomeScreen extends ConsumerWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metronomeViewModelProvider);
    final viewModel = ref.read(metronomeViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('节拍器')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Text(
              '${state.bpm}',
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const Text('BPM'),
            Slider(
              value: state.bpm.toDouble(),
              min: 30,
              max: 240,
              divisions: 210,
              onChanged: (value) => viewModel.setBpm(value.round()),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              children: [
                for (var beat = 1; beat <= state.beatsPerBar; beat++)
                  CircleAvatar(
                    backgroundColor: state.beat == beat
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text('$beat'),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2/4')),
                ButtonSegment(value: 3, label: Text('3/4')),
                ButtonSegment(value: 4, label: Text('4/4')),
                ButtonSegment(value: 6, label: Text('6/8')),
              ],
              selected: {state.beatsPerBar},
              onSelectionChanged: (value) =>
                  viewModel.setBeatsPerBar(value.single),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: viewModel.tapTempo,
                  child: const Text('Tap Tempo'),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: viewModel.toggle,
                  icon: Icon(state.isRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(state.isRunning ? '停止' : '开始'),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
