import 'package:flutter/material.dart';

import 'package:dance_evaluation/app.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source_factory.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector_factory.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker_factory.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor_factory.dart';
import 'package:dance_evaluation/features/upload/presentation/upload_controller.dart';

/// Application bootstrap: initialise services, then run the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sl = ServiceLocator.instance;

  // Create services via platform-conditional factories.
  final poseDetector = createPoseDetector();
  final cameraSource = createCameraSource();
  final evaluation = EvaluationService();
  final capture = CaptureController(poseDetector: poseDetector);

  final videoFilePicker = createVideoFilePicker();
  final videoPoseExtractor = createVideoPoseExtractor();
  final uploadController = UploadController(
    videoFilePicker: videoFilePicker,
    videoPoseExtractor: videoPoseExtractor,
    captureController: capture,
  );

  // Register in the service locator.
  sl.register<PoseDetector>(poseDetector);
  sl.register<CameraSource>(cameraSource);
  sl.register<EvaluationService>(evaluation);
  sl.register<CaptureController>(capture);
  sl.register<VideoFilePicker>(videoFilePicker);
  sl.register<VideoPoseExtractor>(videoPoseExtractor);
  sl.register<UploadController>(uploadController);

  runApp(const DanceEvalApp());
}
