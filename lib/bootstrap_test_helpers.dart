import 'package:flutter/foundation.dart';

import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/core/services/settings_service.dart';
import 'package:dance_evaluation/core/storage/evaluation_storage.dart';
import 'package:dance_evaluation/core/storage/evaluation_storage_factory.dart';
import 'package:dance_evaluation/core/storage/reference_storage.dart';
import 'package:dance_evaluation/core/storage/reference_storage_factory.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source_factory.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector_factory.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/data/reference_repository.dart';
import 'package:dance_evaluation/core/services/audio_service.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';
import 'package:dance_evaluation/features/evaluation/domain/ai_coaching_service.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker_factory.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor_factory.dart';
import 'package:dance_evaluation/features/upload/presentation/upload_controller.dart';
import 'package:dance_evaluation/core/services/sharing_service.dart';
import 'package:dance_evaluation/core/services/sharing_service_factory.dart';

/// Mirrors [bootstrap] from `lib/bootstrap.dart` but does NOT call [runApp].
///
/// Registers all services in [ServiceLocator], allowing optional overrides.
/// Use [skipOnboarding] (default true) to bypass the onboarding redirect.
///
/// When [referenceRepository] is provided, platform reference storage creation
/// is skipped. Same for [historyRepository] and evaluation storage.
@visibleForTesting
Future<void> bootstrapForTest({
  bool skipOnboarding = true,
  PoseDetector? poseDetector,
  CameraSource? cameraSource,
  EvaluationService? evaluationService,
  ReferenceRepository? referenceRepository,
  ReferenceStorage? referenceStorage,
  VideoFilePicker? videoFilePicker,
  VideoPoseExtractor? videoPoseExtractor,
  AudioService? audioService,
  AiCoachingService? aiCoachingService,
  EvaluationHistoryRepository? historyRepository,
  EvaluationStorage? evaluationStorage,
  SharingService? sharingService,
  SettingsService? settingsService,
}) async {
  final sl = ServiceLocator.instance;
  sl.reset();

  // Settings (load first so other services can read them).
  final settings = settingsService ?? SettingsService();
  await settings.initialize();
  if (skipOnboarding) {
    settings.hasSeenOnboarding = true;
  }
  sl.register<SettingsService>(settings);

  // Create services via platform-conditional factories (or use overrides).
  final pd = poseDetector ?? createPoseDetector();
  final cs = cameraSource ?? createCameraSource();
  final eval = evaluationService ?? EvaluationService();

  // Reference storage + repo — skip platform storage if repo is overridden.
  ReferenceRepository refRepo;
  if (referenceRepository != null) {
    refRepo = referenceRepository;
  } else {
    final refStorage = referenceStorage ?? createReferenceStorage();
    await refStorage.initialize();
    refRepo = ReferenceRepository(storage: refStorage);
  }

  final capture = CaptureController(
    poseDetector: pd,
    countdownDuration: settings.countdownSeconds,
    maxRecordingDuration: settings.maxRecordingSeconds,
  );

  final vfp = videoFilePicker ?? createVideoFilePicker();
  final vpe = videoPoseExtractor ?? createVideoPoseExtractor();
  final uploadCtrl = UploadController(
    videoFilePicker: vfp,
    videoPoseExtractor: vpe,
    captureController: capture,
  );

  final audio = audioService ?? AudioService();
  final aiCoaching = aiCoachingService ?? AiCoachingService();

  // Evaluation storage + repo — skip platform storage if repo is overridden.
  EvaluationHistoryRepository historyRepo;
  if (historyRepository != null) {
    historyRepo = historyRepository;
  } else {
    final evalStorage = evaluationStorage ?? createEvaluationStorage();
    await evalStorage.initialize();
    historyRepo = EvaluationHistoryRepository(storage: evalStorage);
  }

  final sharing = sharingService ?? createSharingService();

  // Register in the service locator.
  sl.register<AudioService>(audio);
  sl.register<AiCoachingService>(aiCoaching);
  sl.register<EvaluationHistoryRepository>(historyRepo);
  sl.register<PoseDetector>(pd);
  sl.register<CameraSource>(cs);
  sl.register<EvaluationService>(eval);
  sl.register<ReferenceRepository>(refRepo);
  sl.register<CaptureController>(capture);
  sl.register<VideoFilePicker>(vfp);
  sl.register<VideoPoseExtractor>(vpe);
  sl.register<UploadController>(uploadCtrl);
  sl.register<SharingService>(sharing);
}
