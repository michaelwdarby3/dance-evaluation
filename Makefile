.PHONY: setup setup-server setup-tools run run-web run-server run-android test test-unit test-integration lint build-web build-apk build-server deploy-server clean

FLUTTER := flutter
PIP := pip
DOCKER := docker

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

## Install all dependencies (Flutter + Python server + Python tools)
setup: setup-flutter setup-server setup-tools

setup-flutter:
	$(FLUTTER) pub get

setup-server:
	cd server && python3 -m venv .venv && \
		. .venv/bin/activate && \
		$(PIP) install -r requirements.txt -r requirements-dev.txt

setup-tools:
	cd tools && python3 -m venv .venv && \
		. .venv/bin/activate && \
		$(PIP) install mediapipe opencv-python-headless numpy

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

## Run Flutter app on default device
run:
	$(FLUTTER) run

## Run Flutter app in Chrome
run-web:
	$(FLUTTER) run -d chrome

## Run on Android emulator (builds, installs, and launches)
run-android:
	./scripts/android-emulator.sh install
	./scripts/android-emulator.sh launch

## Start the Android emulator
emulator-start:
	./scripts/android-emulator.sh start

## Stop the Android emulator
emulator-stop:
	./scripts/android-emulator.sh stop

## Take an emulator screenshot
emulator-screenshot:
	./scripts/android-emulator.sh screenshot

## Run FastAPI backend locally (port 8000, auto-reload)
run-server:
	cd server && . .venv/bin/activate && \
		uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload

# ---------------------------------------------------------------------------
# Test
# ---------------------------------------------------------------------------

## Run all unit & widget tests
test:
	$(FLUTTER) test

## Run a specific test file (usage: make test-file FILE=test/data/reference_repository_test.dart)
test-file:
	$(FLUTTER) test $(FILE)

## Run web integration tests (starts chromedriver automatically)
test-integration-web:
	chromedriver --port=4444 & \
	sleep 2; \
	$(FLUTTER) drive \
		--driver=test_driver/integration_test.dart \
		--target=integration_test/app_flow_test.dart \
		-d chrome \
		--chrome-binary=$$(which google-chrome-nosandbox 2>/dev/null || echo google-chrome); \
	STATUS=$$?; kill %1 2>/dev/null; exit $$STATUS

## Run ALL web integration tests
test-integration-web-all:
	chromedriver --port=4444 & \
	sleep 2; \
	CHROME=$$(which google-chrome-nosandbox 2>/dev/null || echo google-chrome); \
	for f in integration_test/*_test.dart; do \
		pkill -f "chrome" 2>/dev/null; sleep 2; \
		$(FLUTTER) drive \
			--driver=test_driver/integration_test.dart \
			--target=$$f \
			-d chrome \
			--chrome-binary=$$CHROME || { kill %1 2>/dev/null; exit 1; }; \
	done; kill %1 2>/dev/null

## Run integration tests on Android emulator (must be running)
test-integration-android:
	$(FLUTTER) drive \
		--driver=test_driver/integration_test.dart \
		--target=integration_test/app_flow_test.dart \
		-d emulator-5554

## Run ALL Android integration tests
test-integration-android-all:
	for f in integration_test/*_test.dart; do \
		$(FLUTTER) drive \
			--driver=test_driver/integration_test.dart \
			--target=$$f \
			-d emulator-5554 || exit 1; \
	done

## Default: web
test-integration: test-integration-web

## Run Python server tests
test-server:
	cd server && . .venv/bin/activate && python -m pytest tests/ -v

# ---------------------------------------------------------------------------
# Lint & Format
# ---------------------------------------------------------------------------

## Analyze Dart code
lint:
	$(FLUTTER) analyze

## Format Dart code
format:
	dart format lib/ test/

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

## Build Flutter web release
build-web:
	$(FLUTTER) build web

## Build Android debug APK
build-apk:
	$(FLUTTER) build apk --debug

## Build Android release APK
build-apk-release:
	$(FLUTTER) build apk --release

## Build server Docker image
build-server:
	$(DOCKER) build -t dance-eval-api server/

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------

## Deploy server via Docker (local)
deploy-server-local:
	$(DOCKER) run -p 8080:8080 dance-eval-api

## Deploy infrastructure (requires GCP project ID)
deploy-infra:
	@test -n "$(GCP_PROJECT)" || (echo "Usage: make deploy-infra GCP_PROJECT=your-project-id" && exit 1)
	cd infra && terraform init && terraform apply -var="project_id=$(GCP_PROJECT)"

# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------

## Extract reference from a video (usage: make extract-ref VIDEO=path/to/video.mp4 OUTPUT=assets/references/my_ref.json)
extract-ref:
	@test -n "$(VIDEO)" || (echo "Usage: make extract-ref VIDEO=path/to/video.mp4 OUTPUT=output.json" && exit 1)
	cd tools && . .venv/bin/activate && \
		python extract_reference.py "$(VIDEO)" -o "$(or $(OUTPUT),../assets/references/extracted_ref.json)"

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------

## Remove build artifacts
clean:
	$(FLUTTER) clean
	rm -rf build/ .dart_tool/

## Full clean including venvs
clean-all: clean
	rm -rf server/.venv tools/.venv
