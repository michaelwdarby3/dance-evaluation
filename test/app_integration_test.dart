import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dance_evaluation/app.dart';
import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/reference_repository.dart';
import 'package:dance_evaluation/features/capture/domain/camera_source.dart';
import 'package:dance_evaluation/features/capture/domain/pose_detector.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';
import 'package:dance_evaluation/features/upload/domain/video_file_picker.dart';
import 'package:dance_evaluation/features/upload/domain/video_pose_extractor.dart';
import 'package:dance_evaluation/features/upload/presentation/upload_controller.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class FakePoseDetector extends PoseDetector {
  @override
  Future<PoseFrame?> detectPose(PoseInput input) async => null;
  @override
  void dispose() {}
}

class FakeCameraSource extends CameraSource {
  @override
  Future<void> initialize() async {}
  @override
  Widget buildPreview() => const SizedBox();
  @override
  Future<void> startFrameStream(void Function(PoseInput) onFrame) async {}
  @override
  Future<void> stopFrameStream() async {}
  @override
  Size get previewSize => const Size(640, 480);
  @override
  bool get isFrontCamera => true;
  @override
  void dispose() {}
}

class FakeVideoFilePicker extends VideoFilePicker {
  @override
  Future<String?> pickVideo() async => null;
  @override
  void dispose() {}
}

class FakeVideoPoseExtractor extends VideoPoseExtractor {
  @override
  Future<Duration> extractPoses({
    required String videoUrl,
    required void Function(double progress) onProgress,
    required void Function(PoseFrame frame) onFrame,
  }) async => Duration.zero;
  @override
  void dispose() {}
}

PoseFrame _makeFrame(Duration ts, {double x = 0.5, double y = 0.5}) {
  return PoseFrame(
    timestamp: ts,
    landmarks: List.generate(
      33,
      (_) => Landmark(x: x, y: y, z: 0, visibility: 0.9),
    ),
  );
}

ReferenceChoreography _makeReference({
  String id = 'test_ref',
  int frameCount = 10,
}) {
  final frames = List.generate(frameCount, (i) {
    return _makeFrame(Duration(milliseconds: i * 100));
  });

  return ReferenceChoreography(
    id: id,
    name: 'Test Reference',
    style: DanceStyle.hipHop,
    poses: PoseSequence(
      frames: frames,
      fps: 10.0,
      duration: Duration(milliseconds: (frameCount - 1) * 100),
    ),
    bpm: 120.0,
    description: 'Test',
    difficulty: 'beginner',
  );
}

void _registerAllServices() {
  final sl = ServiceLocator.instance;
  sl.reset();

  final detector = FakePoseDetector();
  final capture = CaptureController(poseDetector: detector);
  final picker = FakeVideoFilePicker();
  final extractor = FakeVideoPoseExtractor();

  sl.register<PoseDetector>(detector);
  sl.register<CaptureController>(capture);
  sl.register<CameraSource>(FakeCameraSource());
  sl.register<VideoFilePicker>(picker);
  sl.register<VideoPoseExtractor>(extractor);
  sl.register<UploadController>(UploadController(
    videoFilePicker: picker,
    videoPoseExtractor: extractor,
    captureController: capture,
  ));
  sl.register<EvaluationService>(EvaluationService());
  sl.register<ReferenceRepository>(ReferenceRepository());
}

void main() {
  setUp(() {
    _registerAllServices();
  });

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  group('DanceEvalApp renders', () {
    testWidgets('home screen at root with correct title and buttons',
        (tester) async {
      await tester.pumpWidget(const DanceEvalApp());

      expect(find.text('Dance Eval'), findsOneWidget);
      expect(find.text('Start Dancing'), findsOneWidget);
      expect(find.text('Upload Video'), findsOneWidget);
      expect(find.text('Manage References'), findsOneWidget);
    });

    testWidgets('uses dark theme with correct colors', (tester) async {
      await tester.pumpWidget(const DanceEvalApp());

      final context = tester.element(find.byType(Scaffold));
      final theme = Theme.of(context);
      expect(theme.brightness, Brightness.dark);
    });
  });

  group('Single-person evaluation integration', () {
    test('capture → evaluate produces valid result', () async {
      final sl = ServiceLocator.instance;
      final capture = sl.get<CaptureController>();
      final evaluationService = sl.get<EvaluationService>();
      final repo = sl.get<ReferenceRepository>();

      final ref = _makeReference(frameCount: 10);
      repo.save(ref);

      // Simulate recording: same frames as reference (self-evaluation).
      capture.startExternalRecording();
      for (final frame in ref.poses.frames) {
        capture.addExternalFrame(frame);
      }
      capture.stopRecording();

      expect(capture.state, CaptureState.done);
      expect(capture.isMultiPerson, isFalse);

      // Run evaluation (mirrors _EvaluationLoader logic).
      final loadedRef = await repo.load('test_ref.json');
      final userSequence = capture.getRecordedSequence();
      final result = await evaluationService.evaluate(userSequence, loadedRef);

      expect(result.overallScore, inInclusiveRange(0, 100));
      expect(result.dimensions.length, 4);
      expect(result.style, DanceStyle.hipHop);
      expect(result.id, isNotEmpty);
      expect(result.createdAt, isA<DateTime>());
    });

    test('self-evaluation scores higher than random evaluation', () async {
      final sl = ServiceLocator.instance;
      final capture = sl.get<CaptureController>();
      final evaluationService = sl.get<EvaluationService>();
      final repo = sl.get<ReferenceRepository>();

      // Build a reference with varied (non-uniform) landmark positions
      // so that cosine similarity can distinguish self vs random.
      final variedFrames = List.generate(20, (i) {
        return PoseFrame(
          timestamp: Duration(milliseconds: i * 100),
          landmarks: List.generate(
            33,
            (j) => Landmark(
              x: 0.3 + 0.01 * j + 0.005 * i,
              y: 0.2 + 0.015 * j - 0.003 * i,
              z: 0,
              visibility: 0.9,
            ),
          ),
        );
      });

      final ref = ReferenceChoreography(
        id: 'varied_ref',
        name: 'Varied Reference',
        style: DanceStyle.hipHop,
        poses: PoseSequence(
          frames: variedFrames,
          fps: 10.0,
          duration: Duration(milliseconds: 19 * 100),
        ),
        bpm: 120.0,
        description: 'Test',
        difficulty: 'beginner',
      );
      repo.save(ref);
      final loadedRef = await repo.load('varied_ref.json');

      // Self-evaluation: identical frames.
      capture.startExternalRecording();
      for (final frame in ref.poses.frames) {
        capture.addExternalFrame(frame);
      }
      capture.stopRecording();

      final selfResult = await evaluationService.evaluate(
        capture.getRecordedSequence(),
        loadedRef,
      );

      // Random evaluation: completely different positions.
      capture.reset();
      capture.startExternalRecording();
      for (var i = 0; i < 20; i++) {
        capture.addExternalFrame(
          _makeFrame(Duration(milliseconds: i * 100),
              x: 0.9 - 0.04 * (i % 5), y: 0.1 + 0.03 * (i % 7)),
        );
      }
      capture.stopRecording();

      final randomResult = await evaluationService.evaluate(
        capture.getRecordedSequence(),
        loadedRef,
      );

      expect(selfResult.overallScore, greaterThan(randomResult.overallScore));
    });
  });

  group('Multi-person evaluation integration', () {
    test('2-person capture → evaluateMulti produces per-person results',
        () async {
      final sl = ServiceLocator.instance;
      final capture = sl.get<CaptureController>();
      final evaluationService = sl.get<EvaluationService>();
      final repo = sl.get<ReferenceRepository>();

      // Create a 2-person reference.
      final person0Frames = List.generate(10, (i) {
        return _makeFrame(Duration(milliseconds: i * 100), x: 0.3);
      });
      final person1Frames = List.generate(10, (i) {
        return _makeFrame(Duration(milliseconds: i * 100), x: 0.7);
      });

      final ref = ReferenceChoreography(
        id: 'duo_ref',
        name: 'Duo Reference',
        style: DanceStyle.hipHop,
        poses: PoseSequence(
          frames: person0Frames,
          fps: 10.0,
          duration: const Duration(milliseconds: 900),
        ),
        bpm: 120.0,
        description: 'Duo test',
        difficulty: 'beginner',
        personPoses: [
          PoseSequence(
            frames: person0Frames,
            fps: 10.0,
            duration: const Duration(milliseconds: 900),
            label: 'person_0',
          ),
          PoseSequence(
            frames: person1Frames,
            fps: 10.0,
            duration: const Duration(milliseconds: 900),
            label: 'person_1',
          ),
        ],
      );
      repo.save(ref);

      // Record 2 persons.
      capture.startExternalRecording();
      for (var i = 0; i < 10; i++) {
        capture.addExternalMultiFrames([
          _makeFrame(Duration(milliseconds: i * 100), x: 0.3),
          _makeFrame(Duration(milliseconds: i * 100), x: 0.7),
        ]);
      }
      capture.stopRecording();

      expect(capture.isMultiPerson, isTrue);

      // Run multi-person evaluation (mirrors _EvaluationLoader logic).
      final loadedRef = await repo.load('duo_ref.json');
      final multiSequence = capture.getRecordedMultiSequence();
      final result =
          await evaluationService.evaluateMulti(multiSequence, loadedRef);

      expect(result.personCount, 2);
      expect(result.overallScore, inInclusiveRange(0, 100));
      for (final pr in result.personResults) {
        expect(pr.overallScore, inInclusiveRange(0, 100));
        expect(pr.dimensions.length, 4);
      }
    });

    test('single capture against multi-person ref falls back gracefully',
        () async {
      final sl = ServiceLocator.instance;
      final capture = sl.get<CaptureController>();
      final evaluationService = sl.get<EvaluationService>();
      final repo = sl.get<ReferenceRepository>();

      // 2-person reference.
      final frames = List.generate(10, (i) {
        return _makeFrame(Duration(milliseconds: i * 100));
      });

      final ref = ReferenceChoreography(
        id: 'duo_ref2',
        name: 'Duo Reference 2',
        style: DanceStyle.hipHop,
        poses: PoseSequence(
          frames: frames,
          fps: 10.0,
          duration: const Duration(milliseconds: 900),
        ),
        bpm: 120.0,
        description: 'Test',
        difficulty: 'beginner',
        personPoses: [
          PoseSequence(
            frames: frames,
            fps: 10.0,
            duration: const Duration(milliseconds: 900),
            label: 'person_0',
          ),
          PoseSequence(
            frames: frames,
            fps: 10.0,
            duration: const Duration(milliseconds: 900),
            label: 'person_1',
          ),
        ],
      );
      repo.save(ref);

      // Only 1 person recorded.
      capture.startExternalRecording();
      for (var i = 0; i < 10; i++) {
        capture.addExternalFrame(
          _makeFrame(Duration(milliseconds: i * 100)),
        );
      }
      capture.stopRecording();

      // isMultiPerson is false, but reference is multi-person.
      // The _EvaluationLoader checks: capture.isMultiPerson || reference.isMultiPerson
      final loadedRef = await repo.load('duo_ref2.json');
      expect(loadedRef.isMultiPerson, isTrue);

      // Should still produce a result via evaluateMulti path.
      final multiSequence = capture.getRecordedMultiSequence();
      final result =
          await evaluationService.evaluateMulti(multiSequence, loadedRef);

      expect(result.personCount, greaterThanOrEqualTo(1));
      expect(result.overallScore, inInclusiveRange(0, 100));
    });
  });

  group('Reference repository integration', () {
    test('save and load roundtrip preserves all fields', () async {
      final repo = ServiceLocator.instance.get<ReferenceRepository>();

      final ref = ReferenceChoreography(
        id: 'roundtrip_test',
        name: 'Roundtrip Test',
        style: DanceStyle.kPop,
        poses: PoseSequence(
          frames: [_makeFrame(Duration.zero)],
          fps: 30.0,
          duration: Duration.zero,
          label: 'test_label',
        ),
        bpm: 140.0,
        description: 'Testing roundtrip',
        difficulty: 'advanced',
        audioAsset: 'test_audio.mp3',
      );

      final key = repo.save(ref);
      final loaded = await repo.load(key);

      expect(loaded.id, 'roundtrip_test');
      expect(loaded.name, 'Roundtrip Test');
      expect(loaded.style, DanceStyle.kPop);
      expect(loaded.bpm, 140.0);
      expect(loaded.description, 'Testing roundtrip');
      expect(loaded.difficulty, 'advanced');
      expect(loaded.poses.fps, 30.0);
    });

    test('listAll returns all saved references', () async {
      final repo = ServiceLocator.instance.get<ReferenceRepository>();

      repo.save(_makeReference(id: 'ref_a'));
      repo.save(_makeReference(id: 'ref_b'));
      repo.save(_makeReference(id: 'ref_c'));

      final all = await repo.listAll();

      final ids = all.map((r) => r.id).toSet();
      expect(ids, containsAll(['ref_a', 'ref_b', 'ref_c']));
    });
  });
}
