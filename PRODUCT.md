# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Project teams who manage projects and tasks together.

## Product Purpose

Provide mobile access to projects and tasks as a companion to the existing React project management application, using the same backend.

## Operating Context

The Flutter mobile application connects to an existing Go REST API backed by PostgreSQL. The React application is a separate frontend.

## Capabilities and Constraints

- Login, registration, session storage, and logout are implemented in the Flutter source.
- The dashboard is a placeholder. Project and task management are not yet implemented in the Flutter application.
- The API address currently targets a backend on the Android emulator host; other environments need a reachable address.

## Product Principles

- Support project teams working together from mobile devices.
- Reuse the existing backend rather than maintaining a separate mobile data source.
- Distinguish implemented functionality from planned functionality.
