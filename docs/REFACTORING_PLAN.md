# 轻谱 Flutter V2 全量重构计划

## 1. 文档用途

本文档是 AI 智能体执行全量重构的阶段性工作清单。任何智能体开始重构前，必须完整阅读本文件和仓库根目录的 `AGENTS.md`。

本次重构的最终目标是替换旧架构，而不是长期维护两套实现。允许跨阶段连续迁移和集中删除旧实现，但过程中必须保持项目可编译、可测试、可运行。对应 V2 功能具备自动化覆盖并通过门禁后即可删除旧实现；真机验证作为后续风险检查，不阻塞删除或阶段完成。

## 2. 状态规则

阶段只能使用以下状态：

- `Not started`：尚未开始。
- `In progress`：正在编码或自动化验证。
- `Awaiting device verification`：可选状态；自动化门禁已经通过，但本轮选择等待真机反馈。
- `Blocked`：存在明确阻塞，必须记录原因和解除条件。
- `Complete`：交付内容和自动化门禁均已通过；真机结果单独记录。

智能体只能在完成实际工作后更新状态，不得预先批量勾选。

## 3. 当前阶段总览

| 阶段 | 内容 | 状态 |
|---|---|---|
| 0 | 基线、特征测试与文档 | Complete |
| 1 | V2 工程骨架和依赖注入 | Complete |
| 2 | Domain 与 Data Layer | In progress |
| 3 | 首页与综合搜索 | In progress |
| 4 | 图片谱、资源详情与媒体播放 | In progress |
| 5 | 动态简谱阅读与播放 | In progress |
| 6 | 简谱制作器与本地乐谱 | In progress |
| 7 | 节拍器、音阶与简谱游戏 | In progress |
| 8 | 乐器分析器与平台能力 | In progress |
| 9 | UI、一致性、无障碍与性能 | In progress |
| 10 | 最终切换、删除旧代码与发布验证 | Not started |

### 3.1 本轮执行授权

用户已明确批准全面替换旧架构。后续实现不再以兼容旧页面、旧 API
类型或旧目录结构为迁移目标；旧实现仅用于核对产品行为和存储格式。
V2 垂直切片具备自动化覆盖并通过门禁后，直接删除对应旧实现。

该授权不改变状态真实性要求，也不授权删除产品功能、弱化测试或跳过
自动化门禁。各阶段仍须在实际交付和门禁完成后才能标记为 `Complete`。

2026-07-11 用户进一步确认：旧交互和旧实现不再作为兼容基线。重构可以
按 V2 规范调整页面结构、命令语义和数据流，不为不合理的历史行为增加
兼容分支；仍需用自动化测试证明新行为，并且不得用占位页面代替计划中的
业务能力。

### 3.2 2026-07-11 实施记录

- 阶段 1 已完成：App Bootstrap、Composition Root、Riverpod、go_router、
  环境配置、Failure、NetworkClient、统一状态 UI 与未知路由均已接入。
- 首页和综合搜索已切换到 V2 State/ViewModel，覆盖分页重复请求、搜索部分
  失败以及过期请求保护；旧 `home_page.dart` 和旧综合搜索页面已删除。
- 领域乐谱模型已移出 Data Layer，JSON/收藏映射已集中，旧
  `data/models.dart` 已删除。
- 动态简谱详情已切换到 V2 Repository/ViewModel，播放时间线为纯 Dart，
  音符合成通过 `NotePlaybackService` 注入；旧动态谱详情页已删除。
- 图片谱详情、收藏和相册保存已切换到 V2，普通图片谱与悦谱图片资源共用
  新页面；缓存视频初始化、播放、静音、进度和全屏已合并为单一组件，旧
  图片谱详情页已删除。
- 纯 Dart 转调逻辑已从 Data Layer 移入 Domain music 模块。
- 悦谱旧资源详情和重复音视频播放器已删除；悦谱动态资源改用统一
  `CachedVideoPlayer` 与 `NetworkAudioPlayer`。
- 制作器已改为不可变 Draft、MakerViewModel 与 LocalScoreRepository；
  SharedPreferences 仅由 LocalScoreService 访问，旧制作器/Store/Model 已删除。
- 节拍器、音阶、简谱游戏和乐器分析器路由已全部切到 Feature Screen 与
  ViewModel；页面不再直接持有 Timer、ToneSynth 或麦克风插件。
- `lib/src/pro`、`lib/src/details`、`lib/src/settings` 已无遗留源文件，路由
  不再引用这些目录。
- 本轮门禁：格式化检查、`flutter analyze --no-pub`、40 个测试和
  `flutter build apk --debug --no-pub` 全部通过。

## 4. 不可破坏的产品基线

除非用户明确批准产品变更，重构期间必须保留：

- 动态简谱列表、搜索、分页、详情阅读、播放、高亮、自动滚动、移调、音色、速度和节拍器。
- 图片谱列表、详情、图片显示、视频播放、全屏、收藏和受支持平台的视频缓存。
- 悦谱动态谱、图片谱、伴奏和资源详情能力。
- 简谱制作、试听、自动保存、本地乐谱增删改查。
- 专业节拍器的 BPM、Tap Tempo、重音、细分、Swing、预备拍、定时、加速训练、静音小节和预设。
- 音阶实验室、简谱游戏和乐器分析器。
- 设置、深色模式、默认声音、视频静音和音色选择。
- 动态谱练唱使用乐句级分组，不退化为按单小节机械切分。
- IO 平台使用本地缓存视频，Web 保持网络播放并避免引入 `dart:io`。

## 5. V2 目标架构

采用 MVVM、Repository、Service，并仅在复杂或复用业务中加入 UseCase。

```text
View / Widget
    -> ViewModel
        -> UseCase（可选）
            -> Repository interface
                -> Repository implementation
                    -> Remote / Local / Platform Service
```

数据只能通过单向数据流更新：用户事件进入 ViewModel，ViewModel 调用 UseCase 或 Repository，Repository 更新或返回领域数据，ViewModel 生成新的不可变 ViewState，View 根据状态重新渲染。

### 5.1 目标目录

```text
lib/
  main.dart
  src/
    app/
      app.dart
      app_bootstrap.dart
      app_dependencies.dart
    config/
      app_config.dart
      environment.dart
    routing/
      app_router.dart
      app_routes.dart
    core/
      error/
      network/
      storage/
      audio/
      media/
      theme/
      ui/
    domain/
      models/
      repositories/
      use_cases/
    data/
      dto/
        guji/
        forum/
        yuepu/
      mappers/
      services/
        remote/
        local/
        platform/
      repositories/
    features/
      home/
      search/
      dynamic_score/
      image_score/
      resource_detail/
      jianpu_maker/
      metronome/
      scale_lab/
      jianpu_game/
      instrument_analyzer/
      settings/
test/
  # Mirror the lib/src structure.
integration_test/
docs/
  architecture/
  testing/
```

### 5.2 计划采用的基础方案

- 状态管理与依赖注入：`flutter_riverpod`，优先使用不依赖代码生成的 Provider、Notifier 和 AsyncNotifier。
- 路由：`go_router`，路由定义集中管理。
- 网络：保留 `package:http`，通过可注入 Client 和统一 NetworkClient 封装。
- 模型：首先使用 Dart 不可变类型、sealed class 和明确的 `copyWith`；只有模型样板代码确实失控时，才通过 ADR 决定是否统一引入 Freezed。
- 测试：`flutter_test`、MockClient/fake 实现和 Flutter SDK 的 `integration_test`。

引入或替换基础库前，必须新增 ADR，说明选择、替代方案、迁移成本和退出策略。

## 6. 全局自动化门禁

所有阶段至少执行：

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze --no-pub
flutter test --no-pub
```

涉及 Android、平台插件、依赖或资源时额外执行：

```powershell
flutter build apk --debug --no-pub
```

最终阶段执行：

```powershell
flutter test --coverage --no-pub
flutter test integration_test -d <device-id>
flutter build apk --release --no-pub
```

如果环境暂时无法执行某一命令，智能体必须明确标记为未验证，不能将该阶段标为 `Complete`。

## 7. 阶段 0：基线、特征测试与文档

### 交付内容

- 处理或保存开始重构前的 dirty worktree，不能覆盖用户修改。
- 建立 V2 重构分支和可回滚基线提交。
- 记录 Flutter/Dart 版本、依赖版本、Android/iOS 配置和资产清单。
- 建立 `docs/architecture/`，记录架构总览和 ADR 模板。
- 建立功能对照矩阵，列出每个页面、入口、数据源、存储键和平台插件。
- 给缺少保护的既有行为增加特征测试，重点覆盖模型解析、接口响应、存储兼容和播放时间线。
- 清除现有 analyzer warning，禁止以 warning 状态进入 V2。
- 建立 `docs/testing/device_test_log.md` 模板。

### 自动化门禁

- 全局格式化检查通过。
- `flutter analyze --no-pub` 为零 warning/error。
- 现有测试全部通过。
- Debug APK 构建通过。

### 真机验收

- 安装基线 APK，完成一次核心功能冒烟测试。
- 保存首页、动态谱、图片谱、视频、制作器、节拍器和分析器的基线截图或录屏。

## 8. 阶段 1：V2 工程骨架和依赖注入

### 交付内容

- 创建目标目录，不迁移无关功能。
- 增加 App Bootstrap、Composition Root、环境配置和集中路由。
- 接入 Riverpod 与 go_router。
- 创建统一的 Failure、网络、存储和异步状态基础类型。
- 建立统一 loading、empty、error UI。
- 加强 lint，但不得用全局 ignore 隐藏遗留问题。
- 旧入口仍可访问，新架构提供可运行的 V2 壳层。

### 自动化门禁

- 使用 fake 依赖启动 App 的 Widget 测试通过。
- 路由、未知路径和依赖覆盖测试通过。
- 全局门禁通过。

### 真机验收

- 冷启动、返回键、路由跳转、明暗主题和设置加载正常。

## 9. 阶段 2：Domain 与 Data Layer

### 交付内容

- 将旧 `models.dart` 拆为领域模型，不再混合所有来源的 JSON 解析。
- 为 Guji、Forum、Yuepu 分别建立 DTO、Mapper 和 ApiService。
- 建立 Score、Favorites、Settings、LocalScore Repository 接口与实现。
- 统一分页结果、超时、HTTP 状态、解码、错误映射和脱敏日志。
- 明确 `http.Client`、存储和平台服务的生命周期。
- 为旧页面提供临时适配器；适配器必须带删除条件。
- 记录 SharedPreferences 旧 key 和本地乐谱兼容策略。

### 自动化门禁

- 每个 Service 覆盖成功、空数据、非 200、超时和畸形响应。
- 每个 Mapper 覆盖缺失字段和异常类型。
- 每个 Repository 覆盖分页、错误转换、缓存/存储和 fake 替换。
- 本地旧数据读取测试通过。

### 真机验收

- 三个上游数据源均能加载。
- 弱网、断网和服务器失败有明确错误状态，不崩溃。
- 收藏、设置和本地乐谱在重启后保持。

## 10. 阶段 3：首页与综合搜索

### 交付内容

- 建立 `HomeState`、`HomeViewModel`、`HomeScreen`。
- 将加载、刷新、分页、来源切换和收藏逻辑移出 Widget。
- 建立 Search State/ViewModel，处理防抖、并发、取消/过期请求和部分数据源失败。
- 拆分页面组件，禁止组件直接依赖 Repository 实现。
- 使用集中路由替换首页和搜索页的散落导航。

### 自动化门禁

- 首次加载、空列表、失败、刷新、分页和重复触底测试通过。
- 快速切换来源或关键词时，旧请求不能覆盖新状态。
- 首页和搜索关键 Widget 测试通过。

### 真机验收

- 连续切换动态谱、图片谱、工具页和来源不串数据。
- 快速搜索、返回、再次进入时状态合理。
- 长列表滚动和分页无明显卡顿或重复项。

## 11. 阶段 4：图片谱、资源详情与媒体播放

### 交付内容

- 建立统一视频播放状态与控制器。
- 合并普通/全屏视频的初始化、进度、静音、错误和释放逻辑。
- 保留 IO 缓存与 Web 网络播放差异，并放入平台服务边界。
- 图片保存和权限处理通过 GalleryService 暴露。
- 迁移图片谱详情和悦谱资源详情，删除已替代的重复播放器。

### 自动化门禁

- 播放器状态机、初始化失败、恢复进度和 dispose 测试通过。
- GalleryService 使用 fake 测试成功、部分失败和权限失败。
- 详情页关键 Widget 测试通过。

### 真机验收

- 视频播放、暂停、拖动、静音、全屏和返回后进度恢复。
- 页面退出、App 后台/前台切换后无残留播放。
- 缓存命中、断网行为和图片保存正常。
- 权限拒绝时有可理解提示且不崩溃。

## 12. 阶段 5：动态简谱阅读与播放

### 交付内容

- 拆分谱面解析、布局、转调、播放时间线、声音调度和高亮状态。
- `JianpuScoreView` 只负责渲染和命中测试。
- 建立 DynamicScore ViewModel 与 PlaybackController。
- 自动滚动、缩放、速度、音量、音色、显示调和重写简谱分别建模。
- 乐句级练习生成放入独立 UseCase，并保留现有产品语义。

### 自动化门禁

- token、重复记号、倚音、歌词和异常输入解析测试通过。
- 转调和调号边界测试通过。
- 播放、暂停、恢复、停止、变速与时间线测试通过。
- 练习乐句分组回归测试通过。

### 真机验收

- 高亮、声音和自动滚动保持同步。
- 长谱面滚动流畅。
- 切换速度、调号、音色和节拍器行为正确。
- 锁屏、后台和音频中断后状态可恢复或安全停止。

## 13. 阶段 6：简谱制作器与本地乐谱

### 交付内容

- 建立不可变 EditorState 和 JianpuMakerViewModel。
- 将添加、删除、撤销、重做、试听、自动保存做成明确命令。
- 本地乐谱只通过 LocalScoreRepository 访问。
- 明确自动保存防抖、页面退出和写入失败策略。
- 预览复用 V2 谱面模型和渲染器。

### 自动化门禁

- 编辑命令、撤销重做、非法输入和预览转换测试通过。
- 自动保存时序、写入失败和重启恢复测试通过。
- 旧本地乐谱迁移兼容测试通过。

### 真机验收

- 新建、编辑、试听、保存、重开、重命名和删除完整通过。
- 强制结束 App 后重新打开，最近数据不损坏。
- 快速编辑和连续试听无残留声音或竞态。

## 14. 阶段 7：节拍器、音阶与简谱游戏

### 交付内容

- 将节拍器调度抽为纯 Dart Engine。
- ViewModel 负责预设、训练配置和页面状态，Engine 负责时间与节拍规则。
- 迁移 BPM、Tap Tempo、重音、细分、Swing、预备拍、定时、加速和静音小节。
- 迁移音阶实验室和简谱游戏，复用统一音色/音频抽象。
- 禁止页面直接持有未封装的平台播放器。

### 自动化门禁

- 使用可控 fake clock/scheduler 测试节拍序列和训练模式。
- Tap Tempo、边界 BPM、预设和游戏计分测试通过。
- Timer、播放器和 wakelock 生命周期测试通过。

### 真机验收

- 节拍连续运行至少 15 分钟，无明显漂移、重复或停止。
- 耳机、扬声器、前后台和锁屏行为符合预期。
- 所有训练模式、音阶试听和游戏流程通过。

## 15. 阶段 8：乐器分析器与平台能力

### 交付内容

- 保持 YIN、NoteMapper、TimbreAnalyzer 等算法为纯 Dart。
- 建立录音输入、权限、采样格式和生命周期抽象。
- ViewModel 处理 idle、permissionDenied、listening、result 和 failure 状态。
- 统一 microphone、gallery、video、audio、wakelock 平台错误模型。

### 自动化门禁

- 保留并扩展正弦波、泛音、静音和噪声算法测试。
- 使用 fake frame stream 测试开始、停止、失败和资源释放。
- 采样率和声道转换测试通过。

### 真机验收

- 首次授权、拒绝授权和重新授权流程正确。
- 44.1kHz/48kHz 常见输入正常。
- 安静环境、人声和至少一种乐器输入可稳定工作。
- 离开页面后麦克风指示消失，录音流已释放。

## 16. 阶段 9：UI、一致性、无障碍与性能

### 交付内容

- 统一颜色、间距、圆角、文字、按钮、面板和状态反馈。
- 清除页面中的非必要硬编码设计值。
- 建立明确响应式断点，不以单一设备尺寸写布局。
- 完善深色模式、减少动画、Semantics 和最小点击区域。
- 对谱面绘制、长列表、动画和音频更新进行性能检查。
- 仅给稳定且关键的组件增加 Golden Test。

### 自动化门禁

- 关键页面在小屏、常规手机和平板尺寸无 overflow。
- 字体倍率 1.0、1.3、1.5、2.0 Widget 测试通过。
- 明暗主题和减少动画测试通过。

### 真机验收

- 手机和平板至少各验证一次；没有平板时记录未验证风险。
- 横竖屏、深色模式、字体放大和 TalkBack/VoiceOver 基础导航正常。
- 首页、长谱面和实时分析无明显掉帧。

## 17. 阶段 10：最终切换、删除旧代码与发布验证

### 交付内容

- 功能对照矩阵全部关闭。
- 所有路由指向 V2 页面。
- 删除旧页面、旧 API、临时适配器、重复模型和废弃 Widget。
- 删除未使用依赖、资源、存储 key 兼容代码或记录保留期限。
- 全库搜索禁止的跨层 import、直接插件调用和遗留 TODO。
- 更新 README、架构图、ADR、开发命令和测试说明。
- 完成 Release 构建和关键集成测试。

### 自动化门禁

- 格式化、analyze、全部测试、coverage、integration_test 和 Release APK 全部通过。
- `rg` 检查不到已禁止的旧目录引用。
- 不存在 analyzer ignore、空 catch、占位实现或无追踪 TODO。
- 对未达到的覆盖范围必须记录原因，不能只追求覆盖率数字。

### 真机验收

- 按第 18 节完整回归。
- 使用 Release 包验证，不以 Debug 包代替最终验收。
- 真机验收结果单独记录；发现的问题进入后续修复，不阻塞自动化门禁已通过的阶段完成或合并。

## 18. 最终真机回归清单

- 冷启动、热启动、后台恢复和系统返回键。
- 首页加载、刷新、分页、来源切换和空/失败状态。
- 综合搜索快速输入、部分接口失败和结果导航。
- 动态谱打开、播放、暂停、恢复、停止、变速、移调、高亮和滚动。
- 图片谱加载、缩放、保存和权限拒绝。
- 视频初始化、播放、拖动、静音、全屏、缓存和断网。
- 收藏添加、取消和重启保持。
- 本地谱新建、编辑、试听、自动保存、重开、删除和崩溃恢复。
- 节拍器全部模式、长时间运行、后台和音频输出切换。
- 音阶、游戏、MIDI 音色和声音停止。
- 麦克风首次授权、拒绝、恢复、分析和页面退出释放。
- 明暗主题、字体放大、减少动画、横竖屏和无障碍基础操作。
- 所有资源型页面退出后无残留音频、视频、Timer、录音流或 wakelock。

真机结果记录到 `docs/testing/device_test_log.md`，至少包含设备型号、系统版本、构建模式、Git commit、测试项、结果、问题编号和截图/录屏位置。

## 19. AI 每轮交付模板

每个智能体完成一轮工作后，必须按以下格式交付：

```text
当前阶段：
阶段状态：

本轮完成：
- ...

主要文件：
- ...

架构决定：
- ...

自动验证：
- 命令：...
  结果：通过/失败/未执行，原因：...

尚未验证与风险：
- ...

用户真机检查：
1. ...

下一步：
- ...
```

不得使用“应该没问题”“理论上通过”代替真实验证结果。
