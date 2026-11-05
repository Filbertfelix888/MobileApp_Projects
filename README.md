# Project Management Mobile App

## Project Overview

This Flutter application is the mobile frontend for a project management system. It complements an existing React frontend and uses an external Go REST API backed by PostgreSQL. The backend and React application are maintained separately.

## Tech Stack

- Flutter and Dart for the application and Material UI.
- `http` for API requests and `shared_preferences` for local session storage.
- `flutter_test` for widget tests and `flutter_lints` for static analysis.

## Implemented Features

- Login and registration forms with input validation and request feedback.
- Local session persistence after login when the response contains session data; logout clears the session.
- Named routes for login, registration, and a placeholder dashboard.

Form state is local to each `StatefulWidget`. Network and session operations use static methods.

## Project Structure

```text
lib/
  main.dart                  App entry point, theme, and routes
  network.dart               HTTP client and authentication endpoints
  environment_config.dart     QA/DEV selection and persistence
  session_manager.dart       Local session storage
  System Login/              Login, registration, and dashboard screens
test/                        Flutter widget tests
android/ ios/ web/           Mobile and web platform runners
linux/ macos/ windows/       Desktop platform runners
```

## Prerequisites

- Flutter SDK compatible with the lockfile's Flutter `>=3.44.0` requirement and Dart `^3.13.5`.
- An Android emulator, device, or other supported Flutter target with its required platform toolchain.
- Access to the existing Go API for authentication. The API and PostgreSQL database are not included in this repository.

## Installation and Setup

From the repository root, resolve dependencies:

```sh
flutter pub get
```

Choose QA or DEV from the login screen before signing in. The selected environment persists between launches; switching environments clears the current session and requires a new login. Login waits while switching is in progress. If session storage fails, the app reports the error and blocks protected access for the current process.

## Running the Application

Start an emulator or connect a device, then run:

```sh
flutter run
```

Select a target if Flutter prompts for one. See the [Flutter documentation](https://docs.flutter.dev/) for platform setup.

## Backend API Integration

The login screen lets users select a persisted backend environment:

- **QA** (fresh-install default): `http://43.173.10.180:3030`
- **DEV**: `http://10.0.2.2:3030` (Android emulator address for the host machine)

GET, POST, DELETE, login, and registration use the selected base URL while retaining their existing `/v1/...` paths. Changing environment clears only `SESSION_KEY`; users must log in again. Existing sessions without an environment tag are invalidated on first initialization. The configured endpoints use plain HTTP, not TLS; credentials and bearer tokens can be intercepted on untrusted networks. Use only for QA/development, and do not send production credentials.

The app sends JSON POST requests to:

- `/v1/auth/login`
- `/v1/auth/register`

The client decodes responses as JSON, including error responses. If a stored session contains `access_token`, requests include it as a bearer token. Do not put credentials or tokens in the repository.

## Testing

Run static analysis and widget tests from the repository root:

```sh
flutter analyze
flutter test
```

`test/environment_test.dart` covers environment persistence, switching, session isolation, request URLs, and stale login responses. `test/widget_test.dart` covers session restoration, protected navigation, logout, and storage failures.

## Development Status

Authentication screens and session handling are implemented in the source. The dashboard is a static placeholder; project and task management remain planned. Runtime behavior depends on a reachable backend and has not been verified by this documentation.

## Known Limitations

- The environment URLs use plain HTTP; production use requires a secure HTTPS endpoint.
- Android release builds currently use debug signing and require proper release signing before distribution.
- Tests do not replace end-to-end backend testing.
