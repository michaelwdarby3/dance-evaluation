# Dance Evaluation App

## Project Structure

```
lib/                 Flutter client (Dart)
  core/              Shared models, constants, utils, services, storage
  data/              Repositories (references, evaluation history)
  features/          Feature modules (capture, evaluation, history, home, playback, references, upload)
server/              Python FastAPI backend (Cloud Run) — stubs for Milestone 2
infra/               Terraform IaC for GCP (Cloud Run)
tools/               Python utilities for reference extraction & video generation
scripts/             Shell scripts (Android emulator management, setup, dev)
web/                 Web assets (index.html, pose_bridge.js for MediaPipe interop)
android/             Android native config (package: com.danceval.dance_evaluation)
assets/references/        8 built-in reference choreographies (JSON, including 2 extended 16s routines)
assets/reference_videos/  Generated dance videos per reference (gitignored, created by tools/)
assets/test_videos/       Test videos for reference generation
```

## Flutter Architecture

Feature-based organization under `lib/features/`. Each feature has `domain/` (services, interfaces) and `presentation/` (pages, widgets, controllers).

### Features

| Feature | Purpose |
|---------|---------|
| `capture` | Live camera pose detection with skeleton overlay, countdown, recording, inline settings panel, auto-stop after reference ends |
| `evaluation` | DTW scoring pipeline, feedback generation, drill recommendations, AI coaching, result display |
| `history` | Score trend chart, session list with swipe-to-delete, detail view per result |
| `home` | Landing screen with navigation to all flows |
| `onboarding` | First-launch walkthrough, redirects until completed |
| `playback` | Video playback with synchronized skeleton overlay |
| `references` | Browse/select/create/delete reference choreographies; animated skeleton previews on cards |
| `settings` | Persistent settings: skeleton overlay, ghost opacity, multi-person, haptics, mirror, AI coaching, confidence threshold |
| `upload` | Pick video file, extract poses frame-by-frame, process for evaluation |

### Key Patterns

- **Service Locator** for DI — `lib/core/services/service_locator.dart`, registered in `bootstrap.dart`
- **GoRouter** for navigation — `lib/app.dart`
- **ChangeNotifier** for state — `CaptureController`, `UploadController`, `AudioService`
- **Platform-conditional factories** — each platform service (camera, pose detector, storage, file picker, video extractor) has mobile/web/stub variants selected at compile time via conditional exports

### Routes

| Path | Screen |
|------|--------|
| `/` | Home |
| `/onboarding` | First-launch walkthrough (auto-redirect if not seen) |
| `/references/:mode` | Reference list (mode: `capture`, `upload`, or `manage`) |
| `/create-reference` | Create custom reference from video |
| `/capture?ref=` | Live capture with camera |
| `/upload?ref=` | Upload video for evaluation |
| `/evaluation/:id?ref=` | Run evaluation pipeline, show results |
| `/playback` | Video playback with skeleton overlay |
| `/history` | Score history and trends |
| `/history/:id` | Detail view for a single evaluation result |
| `/settings` | App settings |

### Service Locator Registration (bootstrap.dart)

`PoseDetector`, `CameraSource`, `EvaluationService`, `ReferenceRepository`, `CaptureController`, `VideoFilePicker`, `VideoPoseExtractor`, `UploadController`, `AudioService`, `AiCoachingService`, `EvaluationHistoryRepository`, `SettingsService`, `SharingService`

### Evaluation Pipeline

1. Capture/upload produces a `PoseSequence` (list of 33-landmark `PoseFrame`s)
2. `EvaluationService.evaluate()` normalizes sequences, runs DTW alignment (reports progress via callback)
3. Scores 4 dimensions: timing, technique, expression, spatial awareness
4. Style-specific weights produce overall score (0-100)
5. `FeedbackGenerator` analyzes DTW warping path for time-localized timing insights and direction-aware joint corrections
6. `DrillCatalog` recommends targeted practice drills based on joint, dimension, and score range
7. Optional `AiCoachingService` enhances feedback via Claude API (gated by `SettingsService.aiCoaching`)
8. Results persisted via `EvaluationHistoryRepository`

### Multi-Person Support

The app supports evaluating multiple dancers simultaneously:
- `PersonTracker` matches persons across frames by hip-centroid proximity
- `MultiPoseSequence` holds per-person `PoseSequence`s
- `EvaluationService.evaluateMulti()` matches user persons to reference persons, runs DTW per pair
- UI shows tabbed per-person results with aggregate group score

### Platform Implementations

Each platform service uses a factory pattern with conditional exports:

| Service | Mobile | Web | Stub |
|---------|--------|-----|------|
| PoseDetector | MLKit | MediaPipe JS (pose_bridge.js) | throws |
| CameraSource | camera plugin | getUserMedia + MediaRecorder | throws |
| VideoFilePicker | image_picker | HTML file input | throws |
| VideoPoseExtractor | video_thumbnail + MLKit | MediaPipe detectPoseAtTime | throws |
| ReferenceStorage | File I/O (app docs dir) | localStorage | no-op |
| EvaluationStorage | File I/O (app docs dir) | localStorage | no-op |

### Storage

- **References**: `assets/references/` for built-in (6 choreos), `ReferenceStorage` for user-created
- **Evaluation history**: `EvaluationStorage` with platform-specific persistence
- **Video path**: held in `CaptureController.videoPath` during session (not persisted)

### Sharing & Export

`SharingService` (platform-conditional factory like other services) formats evaluation results via `ResultFormatter` and shares as text. Mobile uses `share_plus`, web uses Web Share API with clipboard fallback.

### Settings Persistence

`SettingsService` wraps `SharedPreferences` with `ChangeNotifier`. All settings have defaults and persist across sessions. Includes: audio, skeleton overlay, ghost opacity, countdown duration, recording duration, multi-person detection, AI coaching + API key, mirror video (default off), mirror skeleton (default off), haptics, video recording, confidence threshold, onboarding-seen flag. All settings are also accessible via an inline expandable panel on the capture screen (grouped into Display, Recording, Detection, Feedback).

## Running

```bash
make setup          # Install all deps (Flutter + server + tools)
make run-web        # Run in Chrome
make run-android    # Build, install, launch on emulator
make test           # Run all Flutter unit & widget tests
make test-integration-web      # Run web integration tests (single file)
make test-integration-web-all  # Run ALL web integration tests
make test-integration-android  # Run integration tests on Android emulator
make build-apk      # Build Android debug APK
make lint           # flutter analyze
make format         # dart format
```

Flutter CLI required. No backend needed — all evaluation runs on-device.

### Android Emulator (WSL2)

```bash
make emulator-start   # Start the emulator
make run-android      # Build + install + launch
make emulator-screenshot
```

The emulator script uses the Windows-side Android SDK at `C:\Users\Mikew\android-sdk`.

### Android Smoke Test

```bash
bash tools/android_smoke_test.sh
```

Automated 11-test suite: screen navigation, orientation changes, process kill/restart, crash detection. Screenshots saved to `test_results/`.

### AI Coaching (Optional)

Pass a Claude API key at build time to enable AI-enhanced feedback:
```bash
flutter run --dart-define=CLAUDE_API_KEY=sk-ant-...
```
Without a key, the app falls back to locally-generated feedback.

## Server (Milestone 2 — Not Yet Implemented)

FastAPI backend in `server/`. Currently only `GET /health` works; all evaluation endpoints return 501.

```bash
make setup-server
make run-server       # localhost:8000
make test-server
make build-server     # Docker image
```

## Infrastructure

Terraform in `infra/` targets GCP Cloud Run.

```bash
make deploy-infra GCP_PROJECT=your-project-id
```

## Tools

```bash
# Extract reference choreography from a video
make extract-ref VIDEO=path/to/video.mp4 OUTPUT=assets/references/my_ref.json

# Generate longer reference choreographies (requires scipy, numpy)
cd tools && . .venv/bin/activate && python generate_long_reference.py

# Generate test dance videos (requires GPU + ModelScope)
cd tools && python generate_dance_video.py

# Generate AI dance videos from reference choreographies (ControlNet + AnimateDiff, GPU required)
make generate-videos              # All references (~20-30 min each on RTX 3070)
make generate-videos-skeleton     # Skeleton-only fallback (no GPU needed)
make generate-video REF=assets/references/hip_hop_basic.json  # Single reference
```

### Reference Video Generation

`tools/generate_reference_videos.py` generates realistic dance videos conditioned on skeleton pose sequences using ControlNet (OpenPose) + AnimateDiff. `tools/openpose_renderer.py` handles BlazePose→OpenPose 25-keypoint conversion and canonical colored skeleton rendering.

- **AI mode**: Requires RTX 3070+ (8GB VRAM). Generates in 16-frame chunks with 4-frame overlap for long references.
- **Skeleton-only mode** (`--skeleton-only`): Renders colored OpenPose skeletons to MP4 without GPU.
- Output: `assets/reference_videos/{reference_id}.mp4` (gitignored). The Flutter app auto-discovers these and shows a play button on reference cards.
- **VRAM optimizations** (for 8GB GPUs): xformers attention, tiled VAE, VAE slicing, model CPU offload, 8-bit ControlNet quantization via bitsandbytes. All optimizations are marked with `VRAM NOTE` comments — search the code to see what to remove/relax when upgrading to 24GB+ GPU or cloud A100/H100.

## Testing

- **Unit/widget tests**: `make test` — in `test/` mirroring `lib/` structure
- **Integration tests**: `make test-integration-web-all` — in `integration_test/` (app flow, evaluation flow, history, onboarding, settings)
- **Shared test fakes**: `integration_test/shared/test_fakes.dart` and `lib/bootstrap_test_helpers.dart` for wiring fakes into the service locator
- **Android smoke test**: `bash tools/android_smoke_test.sh` — 11 automated tests with screenshots

### Integration Test Environment (WSL2)

Web integration tests require `CHROME_EXECUTABLE` set to `~/bin/google-chrome-nosandbox` (the test runner script does this automatically). This wrapper enables SwiftShader WebGL (needed for MediaPipe WASM) and strips `--disable-gpu` that Flutter's headless Chrome launcher adds. The evaluation flow test uses **real MediaPipe pose extraction** (not faked) — only the file dialog is bypassed via `AssetVideoFilePicker`.

## Current Status

**Milestone 1 is complete.** All on-device features are implemented and tested:
- Live camera capture with real-time skeleton overlay and reference ghost
- Video upload with frame-by-frame pose extraction
- DTW-based evaluation with 4-dimension scoring
- Rich verbal feedback (timing insights, joint corrections, coaching summary)
- 8 built-in reference choreographies (hip-hop, K-pop, R&B at various difficulties, including 2 extended 16s routines)
- Auto-stop recording 1.5s after reference choreography ends, with automatic navigation to results
- Animated skeleton previews on reference selection cards
- Custom reference creation from camera recording or video upload
- Score history with trend charts
- Video playback with skeleton overlay
- Audio playback during capture
- Multi-person evaluation support
- Android and web platforms fully functional
