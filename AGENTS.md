# Agent Guide

This repository is a Flutter app for learning and practicing numbered musical notation (jianpu).

## Project Map

- `lib/main.dart` and `lib/src/app.dart`: app entry and route registration.
- `lib/src/home/home_page.dart`: home screen, search, dynamic/image score lists, favorites, and practice tool shortcuts.
- `lib/src/details/dynamic_detail_page.dart`: dynamic jianpu reader, playback, scrolling, note highlighting, metronome toggle, and entry into score-specific singing practice.
- `lib/src/details/image_detail_page.dart`: image-score detail page, image rendering, and video playback with cache support.
- `lib/src/pro/jianpu_practice_page.dart`: jianpu symbol teaching and singing practice. It supports both the built-in teaching example and auto-generated practice phrases from dynamic scores.
- `lib/src/pro/metronome_page.dart`: professional metronome page.
- `lib/src/audio/tone_synth.dart`: generated note tones and metronome click sounds.
- `lib/src/media/`: platform-aware cached video controller helpers.
- `lib/src/data/`: API client, models, key transposition, settings, and favorites persistence.
- `lib/src/widgets/`: reusable common widgets and jianpu score renderer.
- `test/`: widget and data parsing tests.

## Common Commands

Run these from the repository root:

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

For local web preview:

```powershell
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8765 --no-pub
```

## Implementation Notes

- Keep UI changes consistent with the existing Material 3 theme in `lib/src/theme/app_theme.dart`.
- Prefer narrow, task-focused changes. Avoid unrelated refactors while fixing a feature.
- The dynamic score practice page should use phrase-level grouping for singing practice, not raw one-measure splitting.
- Video caching is platform-aware:
  - IO platforms use `flutter_cache_manager` and local file playback.
  - Web falls back to normal network playback to avoid `dart:io`.
- `flutter analyze --no-pub` and `flutter test --no-pub` are the baseline verification commands after code changes.

## Current User-Facing Features

- Dynamic jianpu list, search, detail reader, playback, note highlighting, auto-scroll, key display, sound toggle, and metronome toggle.
- Image-score list, detail page, images, videos, favorites, and cached video playback on supported platforms.
- Professional metronome with BPM, tap tempo, beat accents, subdivisions, swing, count-in, timer, step-up training, silent-bar training, and presets.
- Jianpu practice with symbol teaching, listen/solfege/lyric modes, phrase loops, BPM control, generated note tones, and score-specific practice entry from dynamic score details.
