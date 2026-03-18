# Dance Evaluation App

## Project Structure

- `lib/` — Flutter client (Dart)
- `server/` — Python FastAPI backend (Cloud Run)
- `infra/` — Terraform IaC for GCP

## Flutter Architecture

Feature-based organization under `lib/features/`. Each feature has `domain/`, `presentation/` (pages, widgets, controllers).

Core shared code in `lib/core/`: models, constants, utils, services.

## Key Patterns

- **Service Locator** for DI (`lib/core/services/service_locator.dart`) — registered in `bootstrap.dart`
- **GoRouter** for navigation (`lib/app.dart`)
- **ChangeNotifier** for state management (e.g., `CaptureController`)
- **Plain Dart classes** for models (no code generation in Milestone 1)

## Running

Flutter CLI required. No backend needed for Milestone 1 (all on-device evaluation).

```bash
flutter pub get
flutter run
```

## Current Status: Milestone 1 (Walking Skeleton)

On-device capture + MediaPipe pose detection + skeleton overlay + DTW evaluation against one hardcoded hip-hop reference + score display.
