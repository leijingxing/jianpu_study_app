import 'package:flutter/material.dart';

import '../data/app_settings.dart';
import '../pro/jianpu_practice_page.dart';
import '../pro/metronome_page.dart';
import '../pro/scale_lab_page.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final palette = paletteOf(context);
        return Scaffold(
          backgroundColor: palette.paper,
          appBar: AppBar(title: const Text('设置')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _SettingsHeader(settings: settings),
              const SizedBox(height: 12),
              _SettingsSection(
                title: '外观',
                icon: AppIcons.paletteOutlined,
                children: [
                  const _SettingLabel('主题模式'),
                  const SizedBox(height: 8),
                  SegmentedButton<AppThemeMode>(
                    segments: [
                      for (final mode in AppThemeMode.values)
                        ButtonSegment(value: mode, label: Text(mode.label)),
                    ],
                    selected: {settings.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) =>
                        settings.setThemeMode(value.first),
                  ),
                  const SizedBox(height: 10),
                  _SettingSwitch(
                    value: settings.compactList,
                    title: '紧凑列表',
                    subtitle: '首页卡片更短，一屏能看到更多谱子',
                    onChanged: settings.setCompactList,
                  ),
                  _SettingSwitch(
                    value: settings.reduceMotion,
                    title: '减少动画',
                    subtitle: '弱化列表入场和按钮切换动画',
                    onChanged: settings.setReduceMotion,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: '练谱',
                icon: AppIcons.graphicEqRounded,
                children: [
                  _SettingSwitch(
                    value: settings.defaultSoundEnabled,
                    title: '动态谱默认发声',
                    subtitle: '打开动态谱时默认跟随节拍播放提示音',
                    onChanged: settings.setDefaultSoundEnabled,
                  ),
                  _SettingSwitch(
                    value: settings.videoMutedByDefault,
                    title: '图片谱视频默认静音',
                    subtitle: '视频可在播放器里随时打开声音',
                    onChanged: settings.setVideoMutedByDefault,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: '工具',
                icon: AppIcons.grid4x4Rounded,
                children: [
                  _SettingsNavTile(
                    icon: AppIcons.menuBookRounded,
                    title: '简谱练习',
                    subtitle: '符号教学、节奏拆解和乐句循环',
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(JianpuPracticePage.routeName),
                  ),
                  _SettingsNavTile(
                    icon: AppIcons.pianoOutlined,
                    title: '音阶实验室',
                    subtitle: '选择音色，点击低音、中音和高音',
                    onTap: () =>
                        Navigator.of(context).pushNamed(ScaleLabPage.routeName),
                  ),
                  _SettingsNavTile(
                    icon: AppIcons.avTimerRounded,
                    title: '专业节拍器',
                    subtitle: 'Tap Tempo、细分、重音和训练模式',
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(MetronomePage.routeName),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: settings.reset,
                icon: const Icon(AppIcons.restartAltRounded),
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
  const _SettingsHeader({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(radiusMedium),
            ),
            child: Icon(AppIcons.tuneRounded, color: palette.brand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '应用偏好',
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${settings.themeMode.label} · ${settings.compactList ? '紧凑列表' : '标准列表'}',
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: palette.paperTint,
        border: Border.all(color: palette.line),
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
                style: TextStyle(
                  color: palette.text,
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

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.onChanged,
  });

  final bool value;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: value,
      title: Text(title),
      subtitle: Text(subtitle),
      onChanged: onChanged,
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: palette.soft,
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        child: Icon(icon, color: palette.brand, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Icon(AppIcons.chevronRightRounded, color: palette.textMuted),
      onTap: onTap,
    );
  }
}

class _SettingLabel extends StatelessWidget {
  const _SettingLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = paletteOf(context);
    return Text(
      text,
      style: TextStyle(
        color: palette.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
