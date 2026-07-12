import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'instrument_analyzer_view_model.dart';

final class InstrumentAnalyzerScreen extends ConsumerWidget {
  const InstrumentAnalyzerScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(instrumentAnalyzerViewModelProvider);
    final viewModel = ref.read(instrumentAnalyzerViewModelProvider.notifier);
    final result = state.result;
    return Scaffold(
      appBar: AppBar(title: const Text('乐器分析器')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Icon(
              state.status == AnalyzerStatus.listening
                  ? Icons.mic
                  : Icons.mic_none,
              size: 72,
            ),
            const SizedBox(height: 24),
            if (state.message != null) Text(state.message!),
            if (result != null && result.isVoiced) ...[
              Text(
                result.note?.noteName ?? '--',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              Text('简谱 ${result.note?.jianpu ?? '--'}'),
              Text(
                '${result.pitch?.frequencyHz.toStringAsFixed(1) ?? '--'} Hz',
              ),
              Text('稳定度 ${(result.stability * 100).round()}%'),
            ] else
              const Text('等待稳定声音输入'),
            const Spacer(),
            FilledButton.icon(
              onPressed: state.status == AnalyzerStatus.listening
                  ? viewModel.stop
                  : viewModel.start,
              icon: Icon(
                state.status == AnalyzerStatus.listening
                    ? Icons.stop
                    : Icons.mic,
              ),
              label: Text(
                state.status == AnalyzerStatus.listening ? '停止' : '开始分析',
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
