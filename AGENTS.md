# Repository Guidelines

## Project Overview

Flutter application for login, registration, and a placeholder dashboard. The backend is external to this repository.

## Architecture & Data Flow

- `lib/main.dart` starts `MyApp` at `/login`; named routes map `/signup` to registration and `/` to the dashboard.
- Form pages call `AuthService` in `lib/network.dart`. `Network.post` sends JSON to `/v1/auth/login` or `/v1/auth/register`, adding a saved bearer token when available.
- Login saves the response's `data` through `SessionManager`; logout clears it. Registration returns to login. The dashboard currently does not guard access by session.
- `Network.baseUrl` is `http://10.0.2.2:3030`, intended for an Android emulator accessing the host. Other targets need a reachable backend address. Responses must contain JSON, including errors.

## Key Directories

- `lib/System Login/`: login, registration, and dashboard widgets. Quote paths containing the space in shell commands.
- `lib/`: app entry point, network client, and session persistence.
- `test/`: Flutter widget tests.
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: platform runners and build configuration.

## Development Commands

```sh
flutter pub get          # Resolve dependencies
flutter run              # Run on a selected device
flutter analyze          # Static analysis
flutter test             # Run tests
flutter test test/widget_test.dart
flutter build apk        # Android build; use web, windows, macos, linux, or ios for other targets
```

## Code Conventions & Common Patterns

- Follow Dart formatting (`dart format`) and the Flutter lint rules in `analysis_options.yaml`. Existing Dart files use `snake_case.dart` names and `UpperCamelCase` classes.
- Forms use `StatefulWidget`, local state, and text controllers. Dispose controllers; check `mounted` before UI updates after asynchronous work.
- Submit handlers use `async`/`await`, catch failures, and show snackbars. `Network.post` throws for non-2xx responses after decoding JSON.
- Networking and session access use static methods; there is no dependency injection or shared app-level state framework. Reuse these patterns unless the task requires a change.

## Important Files

- `lib/main.dart`: entry point, theme, and routes.
- `lib/network.dart`: base URL, JSON requests, bearer header, and authentication endpoints.
- `lib/session_manager.dart`: JSON session storage and `access_token` lookup via `shared_preferences`.
- `pubspec.yaml` / `pubspec.lock`: dependencies, SDK constraint, and locked versions.
- `analysis_options.yaml`: lint configuration and platform/build exclusions.
- `android/app/build.gradle.kts`: Android build settings; release currently uses debug signing and needs proper signing before distribution.

## Runtime/Tooling Preferences

Use Flutter and Dart Pub (`flutter pub`), not Node or Bun. `pubspec.yaml` requires Dart `^3.13.5`; the lockfile requires Flutter `>=3.44.0`. Keep `pubspec.lock` aligned with dependency changes. Android builds use Flutter-provided SDK levels and Java/Kotlin 17; `android/local.properties` must identify the Flutter SDK. Native builds need their platform toolchains.

## Testing & QA

Tests use `flutter_test`; lints use `flutter_lints`. The existing `test/widget_test.dart` is the generated counter test, but `MyApp` now starts on the login page, so its expectations are stale. It does not cover authentication or sessions. No coverage threshold or CI workflow is configured. Add focused tests for changed behavior and run `flutter analyze` plus relevant tests when practical.
