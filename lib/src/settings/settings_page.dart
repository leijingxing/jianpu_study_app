import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../pro/jianpu_practice_page.dart';
import '../pro/metronome_page.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: palette.paper,
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _SettingsHeader(style: settings.uiStyle),
              const SizedBox(height: 14),
              _SettingsSection(
                title: '界面',
                icon: Icons.palette_outlined,
                children: [
                  const _SettingLabel('UI 风格'),
                  const SizedBox(height: 8),
                  SegmentedButton<AppUiStyle>(
                    segments: [
                      for (final style in AppUiStyle.values)
                        ButtonSegment(value: style, label: Text(style.label)),
                    ],
                    selected: {settings.uiStyle},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        settings.setUiStyle(value.first),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: settings.compactList,
                    title: const Text('紧凑列表'),
                    subtitle: const Text('首页卡片更短，一屏能看到更多谱子'),
                    onChanged: settings.setCompactList,
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: settings.reduceMotion,
                    title: const Text('减少动画'),
                    subtitle: const Text('弱化列表入场和按钮切换动画'),
                    onChanged: settings.setReduceMotion,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: '练谱',
                icon: Icons.graphic_eq_rounded,
                children: [
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: settings.defaultSoundEnabled,
                    title: const Text('动态谱默认发声'),
                    subtitle: const Text('打开动态谱时默认跟随节拍播放提示音'),
                    onChanged: settings.setDefaultSoundEnabled,
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: settings.videoMutedByDefault,
                    title: const Text('图片谱视频默认静音'),
                    subtitle: const Text('视频可在播放器里随时打开声音'),
                    onChanged: settings.setVideoMutedByDefault,
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_rounded),
                    title: const Text('简谱练习'),
                    subtitle: const Text('符号教学、节奏拆解和逐小节循环'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(JianpuPracticePage.routeName),
                  ),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.av_timer_rounded),
                    title: const Text('专业节拍器'),
                    subtitle: const Text('Tap Tempo、细分、重音、训练模式和预设'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(MetronomePage.routeName),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: settings.reset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('恢复默认设置'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.style});

  final AppUiStyle style;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
            child: Icon(Icons.tune_rounded, color: palette.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '轻谱偏好',
                  style: TextStyle(
                    color: inkColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '当前风格：${style.label}',
                  style: const TextStyle(color: mutedTextColor, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: lineColor),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.brand, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: inkColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: mutedTextColor,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
