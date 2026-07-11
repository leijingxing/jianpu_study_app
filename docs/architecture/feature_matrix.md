# 功能对照矩阵

| 功能/入口 | 当前实现 | 数据或平台边界 | V2 目标阶段 | 状态 |
|---|---|---|---|---|
| 首页、来源切换、分页、收藏 | `home/home_page.dart` | Guji、Forum、Yuepu、SharedPreferences | 3 | Legacy baseline |
| 综合搜索 | `search/comprehensive_search_page.dart` | 三个远端来源 | 3 | Legacy baseline |
| 动态谱详情、播放、高亮、滚动、移调、练唱 | `details/dynamic_detail_page.dart` | HTTP、音频 | 5 | Legacy baseline |
| 图片谱详情、图片与视频 | `details/image_detail_page.dart` | HTTP、Gal、VideoPlayer、缓存 | 4 | Legacy baseline |
| 悦谱资源详情与伴奏 | `details/yuepu_resource_detail_page.dart` | HTTP、音频、视频、Gal | 4 | Legacy baseline |
| 简谱制作器与草稿 | `pro/jianpu_maker_page.dart` | SharedPreferences、Gal、音频 | 6 | Legacy baseline |
| 本地简谱 CRUD | `pro/jianpu_local_score_store.dart` | SharedPreferences | 6 | Characterized |
| 专业节拍器 | `pro/metronome_page.dart` | 音频、Timer、Wakelock | 7 | Legacy baseline |
| 音阶实验室 | `pro/scale_lab_page.dart` | MIDI/音频 | 7 | Legacy baseline |
| 简谱游戏 | `pro/jianpu_game_page.dart` | 游戏引擎、音频、Timer | 7 | Partially characterized |
| 乐器分析器 | `pro/instrument_analyzer_page.dart` | Record、麦克风、纯 Dart 算法 | 8 | Algorithms characterized |
| 设置、主题与声音默认值 | `settings/settings_page.dart` | SharedPreferences | 1/2/9 | Characterized |
| IO 视频缓存 / Web 网络回退 | `media/cached_video_controller_*` | CacheManager、VideoPlayer | 4 | Legacy baseline |
| 图片保存 | `media/gallery_image_saver.dart` | HTTP、Gal | 4 | Legacy baseline |

`Legacy baseline` 表示行为已盘点但测试保护仍需在对应迁移阶段前补齐；`Characterized` 表示已有存储或行为测试；`Partially characterized` 表示只覆盖核心路径。
