# 阶段 0 基线清单

记录日期：2026-07-11。

## 工具链与应用

- Flutter 3.44.6 stable，Dart 3.12.2，DevTools 2.57.0。
- 应用版本：`1.0.0+1`；Dart SDK 约束：`^3.11.3`。
- Android 使用 Kotlin Gradle 配置，启用 INTERNET、RECORD_AUDIO、旧版外部存储权限和 cleartext traffic。
- iOS 支持 iPhone/iPad 横竖屏，声明麦克风与照片权限，并允许任意网络加载。

## 直接依赖

`http`、`shared_preferences`、`audioplayers`、`record`、`video_player`、`flutter_cache_manager`、`phosphoricons_flutter`、`flutter_midi_pro`、`gal`、`wakelock_plus`。

## 资产

- `assets/soundfonts/generaluser-gs-v2.0.3.sf2`：MIDI 音色库。
- `assets/app_icon/qingpu_icon_1024.png`：启动图标源文件。
- Android/iOS 各密度应用图标与启动资源。

## 外部数据源

- Guji：`http://guji666.com`，动态谱列表、详情和谱面文本。
- Forum：`http://www.jita666.com`，图片谱列表、文章详情、图片与视频 URL。
- Yuepu：`http://xp.yuepuvip.com:8100/one`，动态谱、图片谱、伴奏和资源数据。

## SharedPreferences 兼容键

- `favorite_scores_v1`：JSON 列表，收藏项。
- `local_jianpu_scores_v1`：JSON 列表，本地简谱及创建/更新时间。
- `jianpu_maker_draft_v1`：制作器自动保存草稿。
- `settings_ui_style_v1`、`settings_theme_mode_v1`。
- `settings_compact_list_v1`、`settings_reduce_motion_v1`。
- `settings_default_sound_v1`、`settings_video_muted_v1`。
- `settings_melody_instrument_v1`。

这些键在对应 Repository 迁移与兼容测试完成前不得改名或删除。

## 基线与回滚说明

重构分支为 `codex/v2-refactor-phase-0`。开始时工作区已有未提交修改，涉及 `AGENTS.md`、Android Gradle 配置、图标、依赖清单和 `docs/`；这些修改属于用户且已完整保留。阶段 0 将该完整状态连同基线文档和特征测试纳入一个明确提交，作为后续阶段的可回滚起点。
