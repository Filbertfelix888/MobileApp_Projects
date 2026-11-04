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

Start the external backend using its own setup instructions. Configure the API address as described below before using a target that cannot reach the default address.

## Running the Application

Start an emulator or connect a device, then run:

```sh
flutter run
```

Select a target if Flutter prompts for one. See the [Flutter documentation](https://docs.flutter.dev/) for platform setup.

## Backend API Integration

`lib/network.dart` sets `Network.baseUrl` to `http://10.0.2.2:3030`. On an Android emulator, `10.0.2.2` addresses the host machine. For a physical device or another target, change the constant to an address reachable from that target. Platform network and HTTP transport policies may also require configuration.

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

`test/widget_test.dart` is the generated counter test. Its expectations do not match the current login screen, and it does not cover authentication or sessions.

## Development Status

Authentication screens and session handling are implemented in the source. The dashboard is a static placeholder; project and task management remain planned. Runtime behavior depends on a reachable backend and has not been verified by this documentation.

## Known Limitations

- The dashboard route does not check whether a session exists.
- The API address is hard-coded and uses plain HTTP; deployment requires an appropriate address and transport configuration.
- Android release builds currently use debug signing and require proper release signing before distribution.
- The existing widget test is stale; authentication and session flows lack test coverage.
