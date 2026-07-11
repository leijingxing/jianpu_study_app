# V2 架构总览

轻谱 V2 使用 MVVM，并以 Repository 隔离数据来源，以 Service 隔离网络、存储和平台插件。依赖方向固定为：

```text
View -> ViewModel -> UseCase（可选） -> Repository interface
  -> Repository implementation -> Service
```

View 只持有布局、动画、焦点和其他短生命周期 UI 状态。ViewModel 暴露不可变状态和命令，不保存 `BuildContext`。Repository interface 是应用层数据来源；实现负责映射、缓存和把外部异常转换为 Failure。每个 Service 只包装一个外部边界。

依赖在 `app/` composition root 创建并注入。领域模型保持纯 Dart；API DTO 不进入 feature UI。跨 feature 复用代码才进入 `core/`。

## 迁移策略

迁移以 `docs/REFACTORING_PLAN.md` 的阶段为唯一进度来源。旧实现是行为兼容基线；替代实现通过自动化测试并完成真机验收后才删除。临时适配器必须注明删除阶段。

## 当前已知架构债务

- 页面直接创建 API、SharedPreferences、音视频、相册、录音和 wakelock 依赖。
- `lib/src/data/models.dart` 混合多个上游 DTO、领域语义和解析。
- 路由散落在 `MaterialApp.routes` 与页面内导航中。
- 多个页面超过 400 行；迁移时按职责拆分，而非机械搬移方法。
- 三个上游仍使用 HTTP，移动平台依赖 cleartext 配置。
