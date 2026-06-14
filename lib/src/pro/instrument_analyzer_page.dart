import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/analyzer/analysis_models.dart';
import '../audio/analyzer/instrument_analyzer.dart';
import '../audio/analyzer/instrument_audio_input.dart';
import '../data/key_transpose.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class InstrumentAnalyzerPage extends StatefulWidget {
  const InstrumentAnalyzerPage({super.key});

  static const routeName = '/instrument-analyzer';

  @override
  State<InstrumentAnalyzerPage> createState() => _InstrumentAnalyzerPageState();
}

class _InstrumentAnalyzerPageState extends State<InstrumentAnalyzerPage> {
  final _analyzer = InstrumentAnalyzer();
  final _input = createInstrumentAudioInput();
  StreamSubscription<List<double>>? _frameSubscription;
  Timer? _testTimer;
  InstrumentAnalysisResult? _result;
  var _mode = _AnalyzerMode.idle;
  var _status = '等待输入';
  var _keyName = 'C';
  var _a4Hz = 440.0;
  var _testFrequency = 440.0;
  var _phase = 0.0;

  bool get _isRunning => _mode != _AnalyzerMode.idle;

  @override
  void dispose() {
    _testTimer?.cancel();
    _frameSubscription?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _startMic() async {
    await _stop();
    if (!_input.isSupported) {
      setState(() => _status = '当前平台需要录音插件');
      return;
    }
    try {
      _frameSubscription = _input.frames.listen(_analyzeFrame);
      await _input.start(frameSize: 2048);
      setState(() {
        _mode = _AnalyzerMode.microphone;
        _status = '麦克风分析中';
      });
    } catch (error) {
      await _frameSubscription?.cancel();
      _frameSubscription = null;
      setState(() {
        _mode = _AnalyzerMode.idle;
        _status = '$error';
      });
    }
  }

  Future<void> _startTestTone() async {
    await _stop();
    _analyzer.reset();
    _phase = 0;
    _testTimer = Timer.periodic(const Duration(milliseconds: 46), (_) {
      _analyzeFrame(_testFrame());
    });
    setState(() {
      _mode = _AnalyzerMode.testTone;
      _status = '校验音源分析中';
    });
  }

  Future<void> _stop() async {
    _testTimer?.cancel();
    _testTimer = null;
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    await _input.stop();
    _analyzer.reset();
    if (mounted) {
      setState(() {
        _mode = _AnalyzerMode.idle;
        _status = '等待输入';
      });
    }
  }

  void _analyzeFrame(List<double> frame) {
    final sampleRate = _mode == _AnalyzerMode.microphone
        ? _input.sampleRate
        : _testSampleRate;
    final result = _analyzer.analyze(
      frame,
      sampleRate,
      keyName: _keyName,
      a4Hz: _a4Hz,
    );
    if (!mounted) return;
    setState(() => _result = result);
  }

  List<double> _testFrame() {
    const length = 2048;
    final samples = List<double>.filled(length, 0);
    final step = 2 * math.pi * _testFrequency / _testSampleRate;
    for (var i = 0; i < length; i++) {
      final phase = _phase + i * step;
      samples[i] =
          0.42 * math.sin(phase) +
          0.28 * math.sin(phase * 2) +
          0.14 * math.sin(phase * 3) +
          0.08 * math.sin(phase * 4);
    }
    _phase = (_phase + length * step) % (2 * math.pi);
    return samples;
  }

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final result = _result;
    return Scaffold(
      backgroundColor: palette.paper,
      appBar: AppBar(title: const Text('乐器分析')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          _AnalyzerHeader(result: result, status: _status, mode: _mode),
          const SizedBox(height: 12),
          _ControlPanel(
            isRunning: _isRunning,
            micSupported: _input.isSupported,
            keyName: _keyName,
            a4Hz: _a4Hz,
            testFrequency: _testFrequency,
            onStartMic: _startMic,
            onStartTestTone: _startTestTone,
            onStop: _stop,
            onKeyChanged: (value) => setState(() => _keyName = value),
            onA4Changed: (value) => setState(() => _a4Hz = value),
            onTestFrequencyChanged: (value) =>
                setState(() => _testFrequency = value),
          ),
          const SizedBox(height: 12),
          _TunerPanel(result: result),
          const SizedBox(height: 12),
          _TimbrePanel(result: result),
        ],
      ),
    );
  }
}

class _AnalyzerHeader extends StatelessWidget {
  const _AnalyzerHeader({
    required this.result,
    required this.status,
    required this.mode,
  });

  final InstrumentAnalysisResult? result;
  final String status;
  final _AnalyzerMode mode;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final note = result?.note;
    final pitch = result?.pitch;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(radiusMedium),
              border: Border.all(color: palette.line),
            ),
            child: Icon(
              AppIcons.recordVoiceOverRounded,
              color: palette.brand,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note == null ? '--' : '${note.jianpu} · ${note.displayName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  _subtitle(pitch, note, status, mode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(
    PitchDetection? pitch,
    NoteMatch? note,
    String status,
    _AnalyzerMode mode,
  ) {
    if (pitch == null || note == null) return status;
    final source = switch (mode) {
      _AnalyzerMode.microphone => '麦克风',
      _AnalyzerMode.testTone => '校验音源',
      _AnalyzerMode.idle => '待机',
    };
    return '$source · ${pitch.frequencyHz.toStringAsFixed(1)}Hz · ${note.centsLabel} cents';
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.isRunning,
    required this.micSupported,
    required this.keyName,
    required this.a4Hz,
    required this.testFrequency,
    required this.onStartMic,
    required this.onStartTestTone,
    required this.onStop,
    required this.onKeyChanged,
    required this.onA4Changed,
    required this.onTestFrequencyChanged,
  });

  final bool isRunning;
  final bool micSupported;
  final String keyName;
  final double a4Hz;
  final double testFrequency;
  final VoidCallback onStartMic;
  final VoidCallback onStartTestTone;
  final VoidCallback onStop;
  final ValueChanged<String> onKeyChanged;
  final ValueChanged<double> onA4Changed;
  final ValueChanged<double> onTestFrequencyChanged;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(icon: AppIcons.tuneRounded, title: '分析设置'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isRunning || !micSupported ? null : onStartMic,
                  icon: const Icon(AppIcons.recordVoiceOverRounded),
                  label: const Text('麦克风'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isRunning ? null : onStartTestTone,
                  icon: const Icon(AppIcons.graphicEqRounded),
                  label: const Text('校验音源'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: '停止',
                onPressed: isRunning ? onStop : null,
                icon: const Icon(AppIcons.pauseRounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: keyName,
            decoration: const InputDecoration(
              labelText: '调号',
              prefixIcon: Icon(AppIcons.musicNoteRounded),
            ),
            items: [
              for (final key in jianpuKeys)
                DropdownMenuItem(value: key, child: Text('1=$key')),
            ],
            onChanged: (value) {
              if (value != null) onKeyChanged(value);
            },
          ),
          const SizedBox(height: 10),
          _SliderRow(
            icon: AppIcons.hearingRounded,
            label: 'A4',
            valueLabel: '${a4Hz.round()}Hz',
            value: a4Hz,
            min: 432,
            max: 446,
            divisions: 14,
            onChanged: onA4Changed,
          ),
          _SliderRow(
            icon: AppIcons.graphicEqRounded,
            label: '校验音',
            valueLabel: '${testFrequency.round()}Hz',
            value: testFrequency,
            min: 196,
            max: 880,
            divisions: 24,
            onChanged: onTestFrequencyChanged,
          ),
        ],
      ),
    );
  }
}

class _TunerPanel extends StatelessWidget {
  const _TunerPanel({required this.result});

  final InstrumentAnalysisResult? result;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final note = result?.note;
    final cents = note?.cents ?? 0;
    final confidence = result?.pitch?.confidence ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PanelTitle(icon: AppIcons.speedRounded, title: '音准'),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: CustomPaint(
              painter: _TunerPainter(
                cents: cents,
                active: result?.isVoiced ?? false,
                palette: palette,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note == null ? '--' : note.centsLabel,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '置信度 ${(confidence * 100).round()}%',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _MetricBar(
            label: '稳定度',
            value: result?.stability ?? 0,
            valueLabel: '${((result?.stability ?? 0) * 100).round()}',
          ),
        ],
      ),
    );
  }
}

class _TimbrePanel extends StatelessWidget {
  const _TimbrePanel({required this.result});

  final InstrumentAnalysisResult? result;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final timbre = result?.timbre;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelTitle(
            icon: AppIcons.graphicEqRounded,
            title: timbre == null ? '音色' : '音色 · ${timbre.label}',
          ),
          const SizedBox(height: 12),
          _SpectrumView(values: timbre?.spectrumBands ?? const []),
          const SizedBox(height: 12),
          _MetricBar(
            label: '明亮度',
            value: timbre?.brightness ?? 0,
            valueLabel: _percent(timbre?.brightness),
          ),
          _MetricBar(
            label: '泛音',
            value: timbre?.richness ?? 0,
            valueLabel: _percent(timbre?.richness),
          ),
          _MetricBar(
            label: '噪声感',
            value: timbre?.noise ?? 0,
            valueLabel: _percent(timbre?.noise),
          ),
          _MetricBar(
            label: '音量',
            value: ((timbre?.rms ?? 0) * 4).clamp(0.0, 1.0),
            valueLabel: _percent(((timbre?.rms ?? 0) * 4).clamp(0.0, 1.0)),
          ),
        ],
      ),
    );
  }

  String _percent(double? value) => '${((value ?? 0) * 100).round()}';
}

class _SpectrumView extends StatelessWidget {
  const _SpectrumView({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final bars = values.isEmpty ? List<double>.filled(24, 0) : values;
    return SizedBox(
      height: 86,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final value in bars) ...[
            Expanded(
              child: FractionallySizedBox(
                heightFactor: value.clamp(0.04, 1.0),
                alignment: Alignment.bottomCenter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(palette.brand, palette.accent, value),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    required this.valueLabel,
  });

  final String label;
  final double value;
  final String valueLabel;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    final clamped = value.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              label,
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 9,
                value: clamped,
                backgroundColor: palette.line,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.lerp(palette.brand, palette.accent, clamped)!,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              valueLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: palette.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.brand),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            color: palette.text,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.textMuted),
        const SizedBox(width: 8),
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: TextStyle(color: palette.text, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 58,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: palette.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _TunerPainter extends CustomPainter {
  _TunerPainter({
    required this.cents,
    required this.active,
    required this.palette,
  });

  final double cents;
  final bool active;
  final QingpuPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.98);
    final radius = math.min(size.width * 0.44, size.height * 0.92);
    final arcRect = Rect.fromCircle(center: center, radius: radius);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = palette.line;
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = active ? palette.brand : palette.textMuted;
    canvas.drawArc(arcRect, math.pi, math.pi, false, basePaint);

    final normalized = (cents.clamp(-50, 50) + 50) / 100;
    canvas.drawArc(arcRect, math.pi, math.pi * normalized, false, activePaint);

    for (final tick in [-50, -25, 0, 25, 50]) {
      final t = (tick + 50) / 100;
      final angle = math.pi + math.pi * t;
      final outer = Offset(
        center.dx + math.cos(angle) * (radius + 1),
        center.dy + math.sin(angle) * (radius + 1),
      );
      final inner = Offset(
        center.dx + math.cos(angle) * (radius - (tick == 0 ? 20 : 13)),
        center.dy + math.sin(angle) * (radius - (tick == 0 ? 20 : 13)),
      );
      final paint = Paint()
        ..strokeWidth = tick == 0 ? 3 : 2
        ..strokeCap = StrokeCap.round
        ..color = tick == 0 ? palette.accent : palette.textMuted;
      canvas.drawLine(inner, outer, paint);
    }

    final needleAngle = math.pi + math.pi * normalized;
    final needleEnd = Offset(
      center.dx + math.cos(needleAngle) * (radius - 27),
      center.dy + math.sin(needleAngle) * (radius - 27),
    );
    final needlePaint = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = active ? palette.accent : palette.textMuted;
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 7, needlePaint);
  }

  @override
  bool shouldRepaint(covariant _TunerPainter oldDelegate) {
    return oldDelegate.cents != cents ||
        oldDelegate.active != active ||
        oldDelegate.palette != palette;
  }
}

enum _AnalyzerMode { idle, microphone, testTone }

const _testSampleRate = 44100;
