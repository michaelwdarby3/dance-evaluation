import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/models/multi_evaluation_result.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/reference_repository.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/capture/presentation/pages/capture_screen.dart';
import 'package:dance_evaluation/features/evaluation/domain/ai_coaching_service.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';
import 'package:dance_evaluation/features/evaluation/domain/feedback_generator.dart';
import 'package:dance_evaluation/features/evaluation/presentation/pages/evaluation_result_screen.dart';
import 'package:dance_evaluation/features/history/presentation/pages/history_screen.dart';
import 'package:dance_evaluation/features/home/presentation/pages/home_screen.dart';
import 'package:dance_evaluation/features/playback/presentation/pages/playback_screen.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';
import 'package:dance_evaluation/features/references/presentation/pages/create_reference_screen.dart';
import 'package:dance_evaluation/features/references/presentation/pages/reference_list_screen.dart';
import 'package:dance_evaluation/features/upload/presentation/pages/upload_processing_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/references/:mode',
      builder: (context, state) => ReferenceListScreen(
        mode: state.pathParameters['mode'] ?? 'capture',
      ),
    ),
    GoRoute(
      path: '/create-reference',
      builder: (context, state) => const CreateReferenceScreen(),
    ),
    GoRoute(
      path: '/capture',
      builder: (context, state) {
        final ref = state.uri.queryParameters['ref'];
        return CaptureScreen(referenceKey: ref);
      },
    ),
    GoRoute(
      path: '/upload',
      builder: (context, state) {
        final ref = state.uri.queryParameters['ref'];
        return UploadProcessingScreen(referenceKey: ref);
      },
    ),
    GoRoute(
      path: '/playback',
      builder: (context, state) {
        final sl = ServiceLocator.instance;
        final capture = sl.get<CaptureController>();
        final videoPath = capture.videoPath;
        if (videoPath == null) {
          return const Scaffold(
            body: Center(
              child: Text(
                'No video available',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );
        }
        return PlaybackScreen(
          videoPath: videoPath,
          poseSequence: capture.getRecordedSequence(),
        );
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/evaluation/:id',
      builder: (context, state) {
        final ref = state.uri.queryParameters['ref'];
        return _EvaluationLoader(referenceKey: ref);
      },
    ),
  ],
);

/// Runs the evaluation pipeline on the captured sequence and shows results.
class _EvaluationLoader extends StatefulWidget {
  const _EvaluationLoader({this.referenceKey});

  final String? referenceKey;

  @override
  State<_EvaluationLoader> createState() => _EvaluationLoaderState();
}

class _EvaluationLoaderState extends State<_EvaluationLoader> {
  EvaluationResult? _result;
  MultiPersonEvaluationResult? _multiResult;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runEvaluation();
  }

  Future<void> _runEvaluation() async {
    try {
      final sl = ServiceLocator.instance;
      final capture = sl.get<CaptureController>();
      final evaluationService = sl.get<EvaluationService>();
      final referenceRepo = sl.get<ReferenceRepository>();

      final refKey = widget.referenceKey ?? 'hip_hop_basic.json';
      final reference = await referenceRepo.load(refKey);

      final historyRepo = sl.get<EvaluationHistoryRepository>();

      if (capture.isMultiPerson || reference.isMultiPerson) {
        // Multi-person evaluation path.
        final multiSequence = capture.getRecordedMultiSequence();
        final multiResult =
            await evaluationService.evaluateMulti(multiSequence, reference);

        if (multiResult.personResults.isEmpty) {
          throw StateError('Evaluation produced no person results');
        }

        // Save the primary result to history.
        final primary = multiResult.personResults.first;
        final saved = EvaluationResult(
          id: primary.id,
          overallScore: multiResult.overallScore,
          dimensions: primary.dimensions,
          jointFeedback: primary.jointFeedback,
          drills: primary.drills,
          createdAt: primary.createdAt,
          style: primary.style,
          referenceName: reference.name,
          timingInsights: primary.timingInsights,
          jointInsights: primary.jointInsights,
          coachingSummary: primary.coachingSummary,
        );
        historyRepo.save(saved);

        if (mounted) {
          setState(() {
            _multiResult = multiResult;
            _result = multiResult.personResults.first;
          });
        }
      } else {
        // Single-person evaluation path.
        final userSequence = capture.getRecordedSequence();
        var result =
            await evaluationService.evaluate(userSequence, reference);

        // Try AI-enhanced coaching (non-blocking — falls back to local).
        final aiCoaching = sl.get<AiCoachingService>();
        if (aiCoaching.isConfigured) {
          final localFeedback = DetailedFeedback(
            timingInsights: result.timingInsights,
            jointInsights: result.jointInsights,
            overallCoaching: result.coachingSummary ?? '',
          );
          final aiSummary = await aiCoaching.generateCoaching(
            result: result,
            localFeedback: localFeedback,
            recentHistory: historyRepo.listAll(),
          );
          result = EvaluationResult(
            id: result.id,
            overallScore: result.overallScore,
            dimensions: result.dimensions,
            jointFeedback: result.jointFeedback,
            drills: result.drills,
            createdAt: result.createdAt,
            style: result.style,
            referenceName: reference.name,
            timingInsights: result.timingInsights,
            jointInsights: result.jointInsights,
            coachingSummary: aiSummary,
          );
        } else {
          // Add reference name to local result.
          result = EvaluationResult(
            id: result.id,
            overallScore: result.overallScore,
            dimensions: result.dimensions,
            jointFeedback: result.jointFeedback,
            drills: result.drills,
            createdAt: result.createdAt,
            style: result.style,
            referenceName: reference.name,
            timingInsights: result.timingInsights,
            jointInsights: result.jointInsights,
            coachingSummary: result.coachingSummary,
          );
        }

        historyRepo.save(result);

        if (mounted) {
          setState(() => _result = result);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Evaluation Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final result = _result;
    if (result != null) {
      return EvaluationResultScreen(
        result: result,
        multiResult: _multiResult,
      );
    }

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Analyzing your dance...',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class DanceEvalApp extends StatelessWidget {
  const DanceEvalApp({super.key});

  static const _purple = Color(0xFF7C4DFF);
  static const _cyan = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Dance Eval',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: _purple,
          secondary: _cyan,
          surface: Color(0xFF1E1E2C),
        ),
        scaffoldBackgroundColor: const Color(0xFF121220),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E2C),
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        useMaterial3: true,
      ),
    );
  }
}
