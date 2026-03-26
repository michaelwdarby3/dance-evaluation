import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dance_evaluation/bootstrap_test_helpers.dart';
import 'package:dance_evaluation/core/services/audio_service.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/core/services/settings_service.dart';
import 'package:dance_evaluation/core/services/sharing_service.dart';
import 'package:dance_evaluation/core/storage/evaluation_storage.dart';
import 'package:dance_evaluation/core/storage/reference_storage.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';
import 'package:dance_evaluation/data/reference_repository.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/evaluation/domain/ai_coaching_service.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';
import 'package:dance_evaluation/features/upload/presentation/upload_controller.dart';

import 'package:dance_evaluation/core/models/pose_frame.dart';

// Minimal fakes to avoid platform-conditional factory issues in unit tests.

class _FakePoseDetector extends PoseDetector {
  @override
  Future<PoseFrame?> detectPose(PoseInput input) async => null;
  @override
  void dispose() {}
}

class _FakeCameraSource extends CameraSource {
  @override
  Future<void> initialize() async {}
  @override
  Widget buildPreview() => const SizedBox();
  @override
  Future<void> startFrameStream(void Function(PoseInput) onFrame) async {}
  @override
  Future<void> stopFrameStream() async {}
  @override
  Size get previewSize => const Size(320, 240);
  @override
  bool get isFrontCamera => true;
  @override
  void dispose() {}
}

class _FakeVideoFilePicker extends VideoFilePicker {
  @override
  Future<String?> pickVideo() async => null;
  @override
  void dispose() {}
}

class _FakeVideoPoseExtractor extends VideoPoseExtractor {
  @override
  Future<Duration> extractPoses({
    required String videoUrl,
    required void Function(double) onProgress,
    required void Function(PoseFrame) onFrame,
  }) async => Duration.zero;
  @override
  void dispose() {}
}

class _FakeSharingService extends SharingService {
  @override
  Future<void> shareText(String text) async {}
  @override
  Future<void> saveJsonFile(String jsonString, String fileName) async {}
  @override
  Future<String?> pickJsonFile() async => null;
}

class _InMemoryReferenceStorage extends ReferenceStorage {
  final _store = <String, String>{};
  @override
  void save(String key, String json) => _store[key] = json;
  @override
  Map<String, String> loadAll() => Map.of(_store);
  @override
  void delete(String key) => _store.remove(key);
}

class _InMemoryEvaluationStorage extends EvaluationStorage {
  final _store = <String, String>{};
  @override
  void save(String key, String json) => _store[key] = json;
  @override
  Map<String, String> loadAll() => Map.of(_store);
  @override
  void delete(String key) => _store.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bootstrapForTest parity', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      ServiceLocator.instance.reset();
    });

    test('registers every service type from bootstrap()', () async {
      await bootstrapForTest(
        poseDetector: _FakePoseDetector(),
        cameraSource: _FakeCameraSource(),
        videoFilePicker: _FakeVideoFilePicker(),
        videoPoseExtractor: _FakeVideoPoseExtractor(),
        sharingService: _FakeSharingService(),
        referenceStorage: _InMemoryReferenceStorage(),
        evaluationStorage: _InMemoryEvaluationStorage(),
      );

      final sl = ServiceLocator.instance;

      // Every service registered in bootstrap.dart must be present.
      expect(sl.has<SettingsService>(), isTrue, reason: 'SettingsService');
      expect(sl.has<PoseDetector>(), isTrue, reason: 'PoseDetector');
      expect(sl.has<CameraSource>(), isTrue, reason: 'CameraSource');
      expect(sl.has<EvaluationService>(), isTrue, reason: 'EvaluationService');
      expect(sl.has<ReferenceRepository>(), isTrue,
          reason: 'ReferenceRepository');
      expect(sl.has<CaptureController>(), isTrue,
          reason: 'CaptureController');
      expect(sl.has<VideoFilePicker>(), isTrue, reason: 'VideoFilePicker');
      expect(sl.has<VideoPoseExtractor>(), isTrue,
          reason: 'VideoPoseExtractor');
      expect(sl.has<UploadController>(), isTrue, reason: 'UploadController');
      expect(sl.has<AudioService>(), isTrue, reason: 'AudioService');
      expect(sl.has<AiCoachingService>(), isTrue,
          reason: 'AiCoachingService');
      expect(sl.has<EvaluationHistoryRepository>(), isTrue,
          reason: 'EvaluationHistoryRepository');
      expect(sl.has<SharingService>(), isTrue, reason: 'SharingService');
    });

    test('skipOnboarding defaults to true', () async {
      await bootstrapForTest(
        poseDetector: _FakePoseDetector(),
        cameraSource: _FakeCameraSource(),
        videoFilePicker: _FakeVideoFilePicker(),
        videoPoseExtractor: _FakeVideoPoseExtractor(),
        sharingService: _FakeSharingService(),
        referenceStorage: _InMemoryReferenceStorage(),
        evaluationStorage: _InMemoryEvaluationStorage(),
      );

      final settings = ServiceLocator.instance.get<SettingsService>();
      expect(settings.hasSeenOnboarding, isTrue);
    });

    test('skipOnboarding: false leaves onboarding unset', () async {
      await bootstrapForTest(
        skipOnboarding: false,
        poseDetector: _FakePoseDetector(),
        cameraSource: _FakeCameraSource(),
        videoFilePicker: _FakeVideoFilePicker(),
        videoPoseExtractor: _FakeVideoPoseExtractor(),
        sharingService: _FakeSharingService(),
        referenceStorage: _InMemoryReferenceStorage(),
        evaluationStorage: _InMemoryEvaluationStorage(),
      );

      final settings = ServiceLocator.instance.get<SettingsService>();
      expect(settings.hasSeenOnboarding, isFalse);
    });
  });
}
