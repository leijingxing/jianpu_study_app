# 轻谱

轻谱是一个 Flutter 简谱学习应用，目标是把“找谱、读谱、听节拍、唱谱练习”放在同一个工具里。

## 功能

- 动态简谱：列表、搜索、收藏、详情阅读、播放、高亮、自动滚动、调式显示。
- 图片谱：图片谱详情、图片查看、视频播放、视频缓存、收藏。
- 简谱练习：符号教学、听音、唱谱、带词、乐句循环、BPM 慢练。
- 动态谱唱谱练习：从动态谱详情进入，自动按乐句生成练习计划。
- 专业节拍器：BPM、Tap Tempo、拍号、细分、重音、Swing、预备拍、计时、自动提速、静音训练、预设。
- 设置：UI 风格、紧凑列表、减少动画、动态谱默认发声、图片谱视频默认静音。

## 运行

先安装依赖：

```powershell
flutter pub get
```

运行到默认设备：

```powershell
flutter run
```

本地 Web 预览：

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8765 --no-pub
```

## 验证

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

## 目录结构

```text
lib/
  main.dart
  src/
    app.dart
    audio/                 # 音符提示音和节拍器点击音
    data/                  # API、模型、设置、收藏、转调
    details/               # 动态谱详情、图片谱详情
    home/                  # 首页
    media/                 # 视频缓存播放辅助
    pro/                   # 简谱练习、专业节拍器
    theme/                 # 主题和颜色
    widgets/               # 公共控件和简谱绘制
test/
```

## 视频缓存

视频缓存使用 `flutter_cache_manager`：

- Android/iOS/桌面：优先下载并复用本地缓存文件播放。
- Web：保持网络播放，避免使用 `dart:io`。
- 缓存失败时自动回退到网络播放。

## 说明

当前项目仍在迭代中，工作区可能包含未提交的功能改动。继续开发前建议先运行 `git status --short` 确认当前变更范围。
