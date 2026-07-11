# Agent Guide

This repository is a Flutter app for learning and practicing numbered musical notation (jianpu).

Most of this codebase is maintained by AI coding agents. Agents must optimize for
long-term readability, explicit boundaries, and verifiable behavior instead of
producing the largest possible patch. Before doing architecture or migration
work, read `docs/REFACTORING_PLAN.md` completely and follow its current phase.

## Source of Truth

- `AGENTS.md` contains mandatory repository-wide engineering rules.
- `docs/REFACTORING_PLAN.md` contains the V2 target architecture, migration
  phases, phase status, automated gates, and device acceptance checks.
- Existing behavior and tests remain the compatibility baseline until a phase
  explicitly replaces them.
- If an implementation choice conflicts with either document, stop and explain
  the conflict before changing the architecture.

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

## Mandatory Architecture Rules

- The V2 architecture is MVVM with repositories, services, and use cases only
  where business logic is complex or reused.
- Dependencies must point in this direction:
  `View -> ViewModel -> UseCase (optional) -> Repository interface -> Repository implementation -> Service`.
- Views and widgets may contain layout, animation, focus, and other ephemeral UI
  state. They must not call HTTP, `SharedPreferences`, file APIs, audio/video
  plugins, microphone plugins, or concrete repository implementations directly.
- ViewModels expose immutable view state and commands. They must not receive or
  retain `BuildContext`.
- Repository interfaces are the application-facing source of truth. Repository
  implementations coordinate services, mapping, caching, and error conversion.
- Services wrap exactly one external boundary, such as one remote upstream, one
  local store, or one platform plugin.
- API DTOs stay in the data layer. `Map<String, dynamic>` and DTO types must not
  cross into feature UI code. Convert DTOs to domain models with explicit
  mappers.
- Domain code must not import Flutter UI libraries. Platform-independent music
  logic should remain pure Dart whenever possible.
- Create dependencies in the app composition root and inject them. Do not add
  hidden global singletons or construct infrastructure objects inside pages.
- `core/` is only for code reused by multiple features. Feature-only code stays
  under that feature. Do not use `core`, `utils`, or `common` as dumping grounds.
- Do not introduce a second state-management, routing, networking, or dependency
  injection approach without an approved architecture-document change.

## Directory and File Rules

- Use `lowercase_with_underscores` for directories and Dart files.
- Organize feature UI under `lib/src/features/<feature>/` and shared data/domain
  code under the directories defined in `docs/REFACTORING_PLAN.md`.
- Mirror production structure under `test/` so tests are easy to locate.
- Keep one primary public responsibility per file. Small private support types
  may remain with their owner when separating them would reduce readability.
- A Dart file above 400 lines requires an explicit justification in the handoff.
  Screens should normally stay below 250 lines by extracting responsibilities,
  not by mechanically moving arbitrary methods into unrelated files.
- Use package imports consistently for cross-directory production code. Avoid
  fragile multi-level relative imports.

## Naming Rules

- Follow Effective Dart naming and formatting conventions.
- Use consistent architecture suffixes: `HomeScreen`, `HomeViewModel`,
  `HomeState`, `ScoreRepository`, `ScoreRepositoryImpl`, `YuepuApiService`,
  `YuepuScoreDto`, and `YuepuScoreMapper`.
- Name commands with clear verbs such as `load`, `refresh`, `saveDraft`, and
  `togglePlayback`. Name state and returned data with nouns.
- Avoid vague names such as `Manager`, `Helper`, `Util`, `Data`, `Item`, or
  `Handler` unless the type truly represents that concept.
- Use the same domain term everywhere. Do not alternate between `song`, `music`,
  and `score` for the same concept.
- Code identifiers are English. User-facing strings are Chinese unless the
  product requirement says otherwise.

## Comment and Documentation Rules

- Comments explain intent, constraints, lifecycle, algorithms, or why a decision
  is non-obvious. Do not narrate syntax or restate the following line of code.
- Use `///` documentation comments for public repository/service contracts,
  public domain types, use cases, shared platform abstractions, and non-obvious
  public APIs.
- The first doc-comment sentence must be a concise summary. Document important
  parameters, return semantics, side effects, ownership, thrown failures, and
  lifecycle obligations when they are not obvious from the signature.
- Complex jianpu parsing, transposition, pitch detection, playback scheduling,
  caching, and platform fallbacks must document assumptions and edge cases near
  the relevant implementation.
- Use `//` for short implementation explanations. Do not use block comments as
  API documentation and do not leave commented-out code.
- Write comments as complete sentences with punctuation. Prefer concise Chinese
  explanations while keeping code identifiers and standard technical terms in
  English.
- Do not add file banners, author names, creation dates, change logs, decorative
  separators, or boilerplate comments generated only to increase comment count.
- A TODO must be actionable and traceable, for example:
  `// TODO(issue-123): Remove the HTTP fallback after the HTTPS proxy ships.`
  Do not add ownerless `TODO`, `FIXME`, or placeholder implementations.
- Update or delete comments whenever behavior changes. A stale comment is a
  defect.

## API, Error, and Lifecycle Rules

- Use typed request/query objects and typed results across architecture layers.
- Use a shared page-result type for pagination. Do not expose transport-specific
  status codes to ViewModels or views.
- Centralize base URLs, headers, timeouts, status validation, decoding, and
  redacted logging. Never log secrets or unnecessary personal data.
- Convert transport, parsing, storage, and platform exceptions into explicit
  application failure types at the repository boundary.
- Make ownership explicit for `http.Client`, stream subscriptions, timers,
  controllers, audio players, video players, recorders, and wakelocks. The owner
  must dispose or release them.
- Guard asynchronous UI updates against disposal and stale requests. Switching
  a tab, source, route, or query must not allow an older response to overwrite a
  newer state.

## AI Change Protocol

- Work on one phase or one bounded vertical slice from
  `docs/REFACTORING_PLAN.md` at a time. Do not perform an unreviewable repository-
  wide rewrite in one patch.
- Before editing, inspect the affected code, tests, current phase, and
  `git status`. Preserve unrelated user changes in a dirty worktree.
- Write or update characterization tests before replacing behavior that is not
  already protected.
- Keep the app buildable during migration. Add adapters when necessary; delete
  legacy code only after the replacement has automated coverage and device
  acceptance.
- Do not change product behavior, visual design, API meaning, or stored-data
  format merely to simplify the architecture unless the phase explicitly
  authorizes it.
- Do not weaken lints, delete assertions, skip tests, replace real logic with
  placeholders, or catch and ignore errors to make a gate pass.
- Reuse existing abstractions when they satisfy the V2 boundary. Do not create
  duplicate engines, repositories, media controllers, models, or design tokens.
- Run the phase's automated gates. Report exact commands and results. Never claim
  that device behavior was verified unless it was actually tested on a device.
- After automated gates pass, mark the phase as `Awaiting device verification`
  in the plan and provide the matching manual checklist to the user. Mark it
  `Complete` only after the user reports device acceptance.
- Every handoff must summarize changed files, architectural decisions, tests
  run, unverified risks, and the next plan item.

## Definition of Done

A refactoring phase is complete only when:

- Its deliverables and migration checklist are satisfied.
- New and changed behavior has appropriate unit or widget coverage.
- Formatting, analysis, tests, and the required build gate pass.
- No new analyzer warning, ignored failure, placeholder, or unexplained
  architecture exception remains.
- Documentation and migration status match the implementation.
- The user has completed and accepted the phase's device checklist.

## Current User-Facing Features

- Dynamic jianpu list, search, detail reader, playback, note highlighting, auto-scroll, key display, sound toggle, and metronome toggle.
- Image-score list, detail page, images, videos, favorites, and cached video playback on supported platforms.
- Professional metronome with BPM, tap tempo, beat accents, subdivisions, swing, count-in, timer, step-up training, silent-bar training, and presets.
- Jianpu practice with symbol teaching, listen/solfege/lyric modes, phrase loops, BPM control, generated note tones, and score-specific practice entry from dynamic score details.
