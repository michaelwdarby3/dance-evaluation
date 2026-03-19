import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/reference_repository.dart';
import 'package:dance_evaluation/features/references/presentation/pages/reference_list_screen.dart';

/// An asset bundle that throws on all loads (no bundled assets).
class EmptyAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    throw FlutterError('Asset $key not found');
  }
}

ReferenceChoreography _makeRef({
  required String id,
  required String name,
  DanceStyle style = DanceStyle.hipHop,
  String difficulty = 'beginner',
}) {
  final frames = List.generate(10, (i) {
    return PoseFrame(
      timestamp: Duration(milliseconds: i * 100),
      landmarks: List.generate(
        33,
        (_) => const Landmark(x: 0.5, y: 0.5, z: 0, visibility: 0.9),
      ),
    );
  });

  return ReferenceChoreography(
    id: id,
    name: name,
    style: style,
    poses: PoseSequence(
      frames: frames,
      fps: 10.0,
      duration: const Duration(milliseconds: 900),
    ),
    bpm: 120.0,
    description: 'Test',
    difficulty: difficulty,
  );
}

void main() {
  late ReferenceRepository repo;
  String? navigatedTo;

  setUp(() {
    // Use EmptyAssetBundle so listAvailable() doesn't hang.
    repo = ReferenceRepository(bundle: EmptyAssetBundle());
    navigatedTo = null;

    final sl = ServiceLocator.instance;
    sl.reset();
    sl.register<ReferenceRepository>(repo);
  });

  tearDown(() {
    ServiceLocator.instance.reset();
  });

  Widget buildSubject({String mode = 'capture'}) {
    final router = GoRouter(
      initialLocation: '/references/$mode',
      routes: [
        GoRoute(
          path: '/references/:mode',
          builder: (_, state) => ReferenceListScreen(
            mode: state.pathParameters['mode'] ?? 'capture',
          ),
        ),
        GoRoute(
          path: '/capture',
          builder: (_, state) {
            navigatedTo = '/capture?ref=${state.uri.queryParameters['ref']}';
            return Scaffold(
              body: Text('Capture ${state.uri.queryParameters['ref']}'),
            );
          },
        ),
        GoRoute(
          path: '/upload',
          builder: (_, state) {
            navigatedTo = '/upload?ref=${state.uri.queryParameters['ref']}';
            return Scaffold(
              body: Text('Upload ${state.uri.queryParameters['ref']}'),
            );
          },
        ),
        GoRoute(
          path: '/create-reference',
          builder: (_, __) {
            navigatedTo = '/create-reference';
            return const Scaffold(body: Text('Create Reference'));
          },
        ),
      ],
    );
    return MaterialApp.router(routerConfig: router);
  }

  group('ReferenceListScreen', () {
    testWidgets('shows empty state when no references exist', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('No references yet'), findsOneWidget);
      expect(
        find.text('Create one from a video to get started.'),
        findsOneWidget,
      );
    });

    testWidgets('shows reference tiles when references exist', (tester) async {
      repo.save(_makeRef(id: 'ref_1', name: 'K-Pop Routine'));
      repo.save(_makeRef(id: 'ref_2', name: 'Hip Hop Flow'));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('K-Pop Routine'), findsOneWidget);
      expect(find.text('Hip Hop Flow'), findsOneWidget);
    });

    testWidgets('reference tile shows metadata', (tester) async {
      repo.save(_makeRef(
        id: 'ref_1',
        name: 'Test Dance',
        style: DanceStyle.kPop,
        difficulty: 'intermediate',
      ));

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Test Dance'), findsOneWidget);
      expect(find.textContaining('kPop'), findsOneWidget);
      expect(find.textContaining('intermediate'), findsOneWidget);
    });

    testWidgets('tapping reference in capture mode navigates to /capture',
        (tester) async {
      repo.save(_makeRef(id: 'my_ref', name: 'My Dance'));

      await tester.pumpWidget(buildSubject(mode: 'capture'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Dance'));
      await tester.pumpAndSettle();

      expect(navigatedTo, '/capture?ref=my_ref');
    });

    testWidgets('tapping reference in upload mode navigates to /upload',
        (tester) async {
      repo.save(_makeRef(id: 'upload_ref', name: 'Upload Dance'));

      await tester.pumpWidget(buildSubject(mode: 'upload'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload Dance'));
      await tester.pumpAndSettle();

      expect(navigatedTo, '/upload?ref=upload_ref');
    });

    testWidgets('has Create from Video FAB', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Create from Video'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('FAB navigates to create-reference screen', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create from Video'));
      await tester.pumpAndSettle();

      expect(navigatedTo, '/create-reference');
    });

    testWidgets('app bar shows Choose Reference title in capture mode',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Choose Reference'), findsOneWidget);
    });

    testWidgets('app bar shows My References title in manage mode',
        (tester) async {
      await tester.pumpWidget(buildSubject(mode: 'manage'));
      await tester.pump();

      expect(find.text('My References'), findsOneWidget);
    });

    testWidgets('manage mode does not navigate on tile tap', (tester) async {
      repo.save(_makeRef(id: 'managed_ref', name: 'Managed Dance'));

      await tester.pumpWidget(buildSubject(mode: 'manage'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Managed Dance'));
      await tester.pumpAndSettle();

      // Should stay on the same screen, not navigate.
      expect(navigatedTo, isNull);
      expect(find.text('My References'), findsOneWidget);
    });

    testWidgets('manage mode hides chevron on tiles', (tester) async {
      repo.save(_makeRef(id: 'ref_1', name: 'Some Dance'));

      await tester.pumpWidget(buildSubject(mode: 'manage'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });
  });
}
