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
- Project list, search, pagination, creation, deletion, and protected detail navigation.
- Project workspace (Proyek tab): server-ordered Kanban columns with create, rename, and delete; tasks with create, detail, edit (title, description, deadline), delete, and cross-column moves via a Move control or long-press drag. Moves append to the destination column.
- Board members: paginated user search, add, and remove. Task assignees: multi-select add from board members and per-user remove, confirmed against the refetched task.
- Board summary (Ringkasan tab): task counts per column, assignee workload, overdue/today and due-in-1–3-days lists. It is computed from per-task detail requests and is shown as incomplete when any request fails.
- Global analytics tab: authenticated `/api/v1/dashboard/workload` shows assignment counts returned across the backend. It is not scoped by project or user; duplicate and blank assignee names can merge.
- Theme choice persists across launches and environment switches. Home and dialogs adapt to compact screens and larger text; project-list fetch errors offer retry.

Form state is local to each `StatefulWidget`. Network, theme, and session operations use static methods.

## Project Structure

```text
lib/
  main.dart                  App entry point, theme, and routes
  network.dart               HTTP client and API endpoints
  environment_config.dart    QA/DEV selection and persistence
  session_manager.dart       Local session storage
  Dashboard/                 Global workload API and view
  Task/                      Board, task, members, and summary UI
  System Login/              Login, registration, and home screens
test/                         Flutter widget and service tests
android/ ios/ web/            Mobile and web platform runners
linux/ macos/ windows/        Desktop platform runners
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

Requests use the selected base URL. Switching environments invalidates the current session; users must log in again. Existing sessions without an environment tag are invalidated on first initialization. The configured endpoints use plain HTTP, not TLS; credentials and bearer tokens can be intercepted on untrusted networks. Use only for QA/development, and do not send production credentials.

The app sends JSON POST requests to:

- `/v1/auth/login`
- `/v1/auth/register`

Authenticated project requests use `/api/v1/boards`. An HTTP 401 invalidates only the session used by that request and returns the app to login; an older response cannot invalidate a newer session. Project list and detail dates are displayed in the device's local time zone. Do not put credentials or tokens in the repository.

- `/api/v1/dashboard/workload` returns a raw array of `{assignee, taskCount}`. It aggregates assignments without project or user filters and groups by assignee name.
- `/api/v1/dashboard/task-percentage` returns counts (`value == count`), not percentages; the app does not present it as a percentage.

## Testing

Run final gates from the repository root:

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

`test/auth_project_kanban_test.dart` covers login through protected project detail into Kanban. `test/global_dashboard_board_flow_test.dart` covers an in-board assignee mutation followed by refreshed global workload after returning Home. `test/kanban_board_test.dart` covers task-create cancel/success and refresh. Other suites cover analytics, auth validation, sessions, project workflows, board/task APIs, members, and compact layouts.

Latest Phase 3–5 regression verification: `flutter analyze --no-pub` reported no issues; `flutter test --no-pub` passed all 168 tests; `flutter build apk --debug --no-pub` produced `build\\app\\outputs\\flutter-apk\\app-debug.apk`. Gradle printed a restricted `System.load` warning, but the build succeeded.

## Development Status

Authentication, environment isolation, project workflows, Kanban/task management, members, assignees, board summary, and global workload display are implemented. Runtime behavior depends on the external backend.

## Known Limitations

- Both configured endpoints use plain HTTP; production use requires HTTPS.
- The backend does not scope global workload analytics by project or user. It groups by assignee name, so duplicate names merge. The `task-percentage` endpoint does not return percentages.
- The backend lacks object-level board authorization. Its board-member `GET` returns raw user objects including password hashes; Flutter parses only `public_id`, `name`, and `email` and never stores the rest. These backend risks block production use.
- The backend exposes no column or task reorder routes; moves append to destination columns. Comments, labels, attachments, and checklists are not managed.
- If session invalidation cannot write its marker or remove saved credentials, the app warns that the old session may return after restart.
- If reading `APP_THEME_MODE` fails, startup uses light theme. If saving a theme change fails, the app keeps the new theme until restart and shows a warning.
- Android release builds use debug signing and need proper release signing before distribution.
- Live QA testing is partial; use [MANUAL_TESTING.md](MANUAL_TESTING.md) for remaining end-to-end checks.
