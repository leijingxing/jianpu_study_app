import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/music/key_transpose.dart';
import 'scale_lab_view_model.dart';

final class ScaleLabScreen extends ConsumerWidget {
  const ScaleLabScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scaleLabViewModelProvider);
    final viewModel = ref.read(scaleLabViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('音阶实验室')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: state.keyName,
              decoration: const InputDecoration(labelText: '调号'),
              items: [
                for (final key in jianpuKeys)
                  DropdownMenuItem(value: key, child: Text('1=$key')),
              ],
              onChanged: (value) {
                if (value != null) viewModel.setKey(value);
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: -1, label: Text('低八度')),
                ButtonSegment(value: 0, label: Text('标准')),
                ButtonSegment(value: 1, label: Text('高八度')),
              ],
              selected: {state.octave},
              onSelectionChanged: (value) => viewModel.setOctave(value.single),
            ),
            const Spacer(),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (var degree = 1; degree <= 7; degree++)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 72),
                    ),
                    onPressed: () => viewModel.play(degree),
                    child: Text(
                      '$degree',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              state.activeDegree == null
                  ? '点击数字试听音阶'
                  : '正在试听 ${state.activeDegree}',
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
