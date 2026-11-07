# Repository Guidelines

## Project Overview

Flutter app for authentication, projects, Kanban tasks, members, assignees, and workload analytics, with System/Light/Dark themes. QA is the only environment users can reach. The Go backend is external.

## Architecture & Data Flow

- `lib/main.dart` initializes the saved theme, starts `MyApp`, and protects `/` and `/projects/:id` with the current environment session.
- Login saves response `data`; logout clears the session. Registration returns to login.
- `EnvironmentConfig` always selects QA (`http://43.173.10.180:3030`) at startup, rewrites a stored DEV preference to QA, and discards sessions tagged for another environment. DEV (`http://10.0.2.2:3030`) and `select()` remain for tests; `LoginPage(showEnvironmentSelector: true)` shows the hidden selector. Switching clears the session; untagged legacy sessions are invalidated.
- `HomePage` loads projects and exposes global workload analytics. `DashboardService` parses authenticated `GET /api/v1/dashboard/workload` as a raw array.
- `ProjectDetailPage` hosts `KanbanBoard`; `TaskService` owns board columns, tasks, members, and assignees. The board summary derives from task details.
- `ThemeNotifier` persists `APP_THEME_MODE` (`system`, `light`, or `dark`; default System, legacy `light`/`dark` preserved) independently of backend environment. `AppTheme` in `lib/ui/Theme/app_theme.dart` defines the Material 3 light and dark themes; `ThemeToggle` opens the chooser.
- `Network` sends authenticated GET/POST/PUT/DELETE requests to the selected backend. Responses must contain JSON, including errors. Configured endpoints use plain HTTP.
- Backend limitations: global workload has no project/user filter and groups by assignee name; member `GET` returns raw user records including password hashes; board-level authorization and reorder routes are absent.

## Key Directories

- `lib/Dashboard/`: global workload API model and view.
- `lib/Task/`: Kanban columns, task forms/details, members, assignees, and board summary.
- `lib/System Login/`: login and registration screens (the navigation bar is `lib/Home/navbar_page.dart`).
- `lib/Project/`: protected project details and board workspace.
- `lib/`: app entry point, network client, environment, session, and theme persistence.
- `test/`: Flutter widget and service regression tests.
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: platform runners.

## Development Commands

```sh
flutter pub get
flutter run
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

## Code Conventions & Common Patterns

- Follow Dart formatting (`dart format`) and the Flutter lint rules in `analysis_options.yaml`. Existing Dart files use `snake_case.dart` names and `UpperCamelCase` classes.
- Forms use `StatefulWidget`, local state, and text controllers. Dispose controllers; check `mounted` before UI updates after asynchronous work.
- Submit handlers use `async`/`await`, catch failures, and show snackbars. `Network.post` throws for non-2xx responses after decoding JSON.
- Networking and session access use static methods; there is no dependency injection or shared app-level state framework. Reuse these patterns unless the task requires a change.

## Important Files

- `lib/main.dart`: entry point, theme initialization, and protected routes.
- `lib/network.dart`: HTTP client, auth, projects, and authenticated API calls.
- `lib/environment_config.dart`: QA/DEV selection, session isolation, and generation guard.
- `lib/session_manager.dart`: session storage and `access_token` validation.
- `lib/Dashboard/dashboard_service.dart`: raw global workload endpoint parser.
- `lib/Task/task_service.dart`: board/task/member/assignee API integration.
- `lib/ui/Theme/theme_notifier.dart`: persisted System/Light/Dark preference; `lib/ui/Theme/app_theme.dart`: shared design tokens.

## Runtime/Tooling Preferences

Use Flutter and Dart Pub (`flutter pub`), not Node or Bun. `pubspec.yaml` requires Dart `^3.13.5`; the lockfile requires Flutter `>=3.44.0`. Keep `pubspec.lock` aligned with dependency changes. Android builds use Flutter-provided SDK levels and Java/Kotlin 17; `android/local.properties` must identify the Flutter SDK. Native builds need their platform toolchains.

## Testing & QA

Tests use `flutter_test` and `flutter_lints`. `test/widget_test.dart` covers protected navigation, session restoration, logout, and storage failures. `test/environment_test.dart` covers QA default, DEV-preference reset, switching, isolation, and stale login responses. `test/global_dashboard_test.dart` also covers theme persistence and System mode. Project, Kanban, task-session, and dashboard behavior has focused regression coverage in `test/`. See `MANUAL_TESTING.md` for the ten-scenario live-backend checklist and `docs/` for architecture, portfolio, and demo guides. Keep `qa-screenshots/` and APK files out of commits.
