import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';
import 'metronome_view_model.dart';

final class MetronomeScreen extends ConsumerWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(metronomeViewModelProvider);
    final viewModel = ref.read(metronomeViewModelProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('专业节拍器'),
        actions: [
          IconButton(
            tooltip: state.isMuted ? '打开节拍声' : '静音',
            onPressed: viewModel.toggleMuted,
            icon: Icon(state.isMuted ? Icons.volume_off : Icons.volume_up),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _TempoPanel(state: state, viewModel: viewModel),
            const SizedBox(height: 16),
            _BeatIndicator(state: state),
            const SizedBox(height: 20),
            _SettingCard(
              title: '拍号',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final meter in const {
                    2: '2/4',
                    3: '3/4',
                    4: '4/4',
                    6: '6/8',
                  }.entries)
                    ChoiceChip(
                      label: Text(meter.value),
                      selected: state.beatsPerBar == meter.key,
                      onSelected: (_) => viewModel.setBeatsPerBar(meter.key),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              title: '节拍细分',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final subdivision in MetronomeSubdivision.values)
                    ChoiceChip(
                      label: Text(subdivision.label),
                      selected: state.subdivision == subdivision,
                      onSelected: (_) => viewModel.setSubdivision(subdivision),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SettingCard(
              title: '常用速度',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final bpm in const [60, 80, 100, 120, 160])
                    ActionChip(
                      label: Text('$bpm'),
                      onPressed: () => viewModel.setBpm(bpm),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _TransportControls(state: state, viewModel: viewModel),
          ],
        ),
      ),
    );
  }
}

final class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.state, required this.viewModel});

  final MetronomeState state;
  final MetronomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final tapButton = OutlinedButton.icon(
      onPressed: viewModel.tapTempo,
      icon: const Icon(Icons.touch_app_outlined),
      label: const Text('点击测速'),
    );
    final playButton = FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      onPressed: viewModel.toggle,
      icon: Icon(state.isRunning ? Icons.stop_rounded : Icons.play_arrow),
      label: Text(state.isRunning ? '停止' : '开始练习'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [playButton, const SizedBox(height: 10), tapButton],
          );
        }
        return Row(
          children: [
            Expanded(child: tapButton),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: playButton),
          ],
        );
      },
    );
  }
}

final class _TempoPanel extends StatelessWidget {
  const _TempoPanel({required this.state, required this.viewModel});

  final MetronomeState state;
  final MetronomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Card(
      color: palette.soft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 18),
        child: Column(
          children: [
            Text(
              _tempoName(state.bpm),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: palette.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BpmButton(
                  tooltip: '降低 5 BPM',
                  icon: Icons.remove,
                  onPressed: () => viewModel.adjustBpm(-5),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    label: '当前速度 ${state.bpm} BPM',
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${state.bpm}',
                            style: Theme.of(context).textTheme.displayLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: palette.brandDark,
                                ),
                          ),
                        ),
                        Text(
                          'BPM',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: palette.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _BpmButton(
                  tooltip: '提高 5 BPM',
                  icon: Icons.add,
                  onPressed: () => viewModel.adjustBpm(5),
                ),
              ],
            ),
            Slider(
              value: state.bpm.toDouble(),
              min: 30,
              max: 240,
              divisions: 210,
              label: '${state.bpm} BPM',
              onChanged: (value) => viewModel.setBpm(value.round()),
            ),
          ],
        ),
      ),
    );
  }

  String _tempoName(int bpm) => switch (bpm) {
    < 60 => '慢速 · Largo',
    < 76 => '行板 · Adagio',
    < 108 => '中速 · Andante',
    < 120 => '小快板 · Moderato',
    < 168 => '快板 · Allegro',
    _ => '急板 · Presto',
  };
}

final class _BpmButton extends StatelessWidget {
  const _BpmButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.outlined(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon),
  );
}

final class _BeatIndicator extends StatelessWidget {
  const _BeatIndicator({required this.state});

  final MetronomeState state;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Semantics(
      label: state.isRunning ? '当前第 ${state.beat} 拍' : '节拍未开始',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var beat = 1; beat <= state.beatsPerBar; beat++) ...[
            AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: state.beat == beat ? 34 : 24,
              height: state.beat == beat ? 34 : 24,
              decoration: BoxDecoration(
                color: state.beat == beat ? palette.brand : palette.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: palette.line),
              ),
              alignment: Alignment.center,
              child: Text(
                '$beat',
                style: TextStyle(
                  color: state.beat == beat ? Colors.white : palette.textMuted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (beat != state.beatsPerBar) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

final class _SettingCard extends StatelessWidget {
  const _SettingCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}
