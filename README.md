# Dance Eval

AI-powered dance movement evaluation. Record yourself dancing, get scored against reference choreographies, and receive detailed feedback on timing, technique, expression, and spatial awareness.

## What It Does

1. **Choose a reference** — Pick from 6 built-in choreographies (hip-hop, K-pop, R&B) or create your own from any video
2. **Dance** — Use your camera for live capture or upload a recorded video
3. **Get scored** — The app detects your pose frame-by-frame, aligns it against the reference using Dynamic Time Warping, and scores you across 4 dimensions
4. **Improve** — Read detailed feedback on which body parts need work, where your timing drifted, and what to focus on next

Works in the browser (Chrome) and on Android. All evaluation runs on-device — no server required, no data leaves your phone.

## Quick Start

```bash
# Install dependencies
make setup

# Run in Chrome
make run-web

# Or run on Android
make emulator-start       # If using emulator
make run-android
```

Requires Flutter SDK (>=3.24.0).

## Features

- **Real-time skeleton overlay** during capture with reference ghost
- **4-dimension scoring**: timing, technique, expression, spatial awareness (0-100 each, style-weighted)
- **Joint-level feedback** with direction-aware corrections ("left elbow too extended", "hips raised too high")
- **Time-localized timing analysis** — detects rushing and falling behind per routine segment
- **Multi-person evaluation** — score group choreography with per-person breakdowns
- **Video playback** with synchronized skeleton overlay
- **Score history** with trend charts across sessions
- **Custom references** — create your own from any dance video
- **Audio playback** during capture (reference audio or metronome)
- **AI coaching** (optional) — enhanced natural-language feedback via Claude API

## How Scoring Works

The app uses MediaPipe BlazePose (33 landmarks) for pose detection and Dynamic Time Warping for temporal alignment.

**Dimensions:**
- **Timing** — How well your movement tempo matches the reference (warping path deviation from ideal diagonal)
- **Technique** — Pose accuracy measured by cosine similarity of joint angle vectors
- **Expression** — Movement dynamics and velocity variance compared to reference
- **Spatial Awareness** — Overall positional accuracy (normalized DTW distance)

Each dimension scores 0-100. The overall score is a weighted average based on dance style (e.g., hip-hop weights technique and expression higher).

**Joint feedback** identifies the 5 weakest joints per evaluation, with signed angle analysis to give directional corrections rather than generic "needs improvement" messages.

## Built-in References

| Reference | Style | Difficulty |
|-----------|-------|------------|
| Hip Hop Basic | Hip Hop | Beginner |
| K-Pop Basic 1 | K-Pop | Beginner |
| K-Pop Intermediate | K-Pop | Intermediate |
| R&B Basic 1 | R&B | Beginner |
| R&B Basic 2 | R&B | Beginner |
| R&B Intermediate | R&B | Intermediate |

Create your own: Home > Manage References > + button, then select any dance video.

## Project Structure

```
lib/                 Flutter app (Dart)
  core/              Models, constants, utils, services, storage
  data/              Repositories
  features/          capture | evaluation | history | home | playback | references | upload
server/              FastAPI backend (Milestone 2, stubs only)
infra/               Terraform for GCP Cloud Run
tools/               Python scripts for reference extraction
scripts/             Android emulator management
assets/references/   Built-in reference choreographies (JSON)
```

## Architecture

- **Service Locator** for dependency injection (`bootstrap.dart`)
- **GoRouter** for navigation
- **ChangeNotifier** for state management
- **Platform-conditional factories** for mobile/web/stub implementations of camera, pose detection, storage, and file I/O

Pose detection uses Google MLKit on Android and MediaPipe JS on web. Both produce the same 33-landmark format.

## Commands

| Command | Description |
|---------|-------------|
| `make setup` | Install all dependencies |
| `make run-web` | Run in Chrome |
| `make run-android` | Build + install + launch on emulator |
| `make test` | Run all unit & widget tests |
| `make lint` | Analyze Dart code |
| `make build-apk` | Build Android debug APK |
| `make build-web` | Build web release |
| `make extract-ref VIDEO=... OUTPUT=...` | Extract reference from video |
| `bash tools/android_smoke_test.sh` | Run Android emulator smoke tests |

## Optional: AI Coaching

Pass a Claude API key at build time for AI-enhanced coaching summaries:

```bash
flutter run --dart-define=CLAUDE_API_KEY=sk-ant-...
```

Without a key, the app generates all feedback locally at no cost.

## Tech Stack

- **Flutter** 3.24+ / Dart 3.5+
- **MediaPipe BlazePose** (web) / **Google MLKit Pose Detection** (mobile)
- **Dynamic Time Warping** for sequence alignment
- **fl_chart** for score trend visualization
- **video_player** + **just_audio** for media playback
- **FastAPI** + **Terraform** + **GCP Cloud Run** (backend, Milestone 2)

## License

Private.
