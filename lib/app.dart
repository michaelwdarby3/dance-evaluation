import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/models/multi_evaluation_result.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/core/services/settings_service.dart';
import 'package:dance_evaluation/data/reference_repository.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/capture/presentation/pages/capture_screen.dart';
import 'package:dance_evaluation/features/evaluation/domain/ai_coaching_service.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';
import 'package:dance_evaluation/features/evaluation/domain/feedback_generator.dart';
import 'package:dance_evaluation/features/evaluation/presentation/pages/evaluation_result_screen.dart';
import 'package:dance_evaluation/features/history/presentation/pages/history_detail_screen.dart';
import 'package:dance_evaluation/features/history/presentation/pages/history_screen.dart';
import 'package:dance_evaluation/features/home/presentation/pages/home_screen.dart';
import 'package:dance_evaluation/features/playback/presentation/pages/playback_screen.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';
import 'package:dance_evaluation/features/references/presentation/pages/create_reference_screen.dart';
import 'package:dance_evaluation/features/references/presentation/pages/reference_list_screen.dart';
import 'package:dance_evaluation/features/onboarding/presentation/pages/onboarding_screen.dart';
import 'package:dance_evaluation/features/settings/presentation/pages/settings_screen.dart';
import 'package:dance_evaluation/features/upload/presentation/pages/upload_processing_screen.dart';

GoRouter _createRouter() => GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    try {
      final settings = ServiceLocator.instance.get<SettingsService>();
      final isOnboarding = state.matchedLocation == '/onboarding';
      if (!settings.hasSeenOnboarding && !isOnboarding) {
        return '/onboarding';
      }
    } catch (_) {
      // SettingsService may not be registered in tests.
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      path: '/references/:mode',
      builder: (context, state) => ReferenceListScreen(
        mode: state.pathParameters['mode'] ?? 'capture',
      ),
    ),
    GoRoute(
      path: '/create-reference',
      builder: (context, state) {
        final fromCapture =
            state.uri.queryParameters['fromCapture'] == 'true';
        return CreateReferenceScreen(fromCapture: fromCapture);
      },
    ),
    GoRoute(
      path: '/capture',
      builder: (context, state) {
        final ref = state.uri.queryParameters['ref'];
        final mode = state.uri.queryParameters['mode'] ?? 'evaluate';
        return CaptureScreen(referenceKey: ref, mode: mode);
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
      path: '/history/:id',
      builder: (context, state) => HistoryDetailScreen(
        resultId: state.pathParameters['id'] ?? '',
      ),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
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
  String _progressStage = 'Preparing...';
  double _progressValue = 0.0;

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

      // Apply confidence threshold from settings.
      try {
        final settings = sl.get<SettingsService>();
        evaluationService.minConfidence = settings.minConfidence;
      } catch (_) {}

      final historyRepo = sl.get<EvaluationHistoryRepository>();

      void onProgress(String stage, double progress) {
        if (mounted) {
          setState(() {
            _progressStage = stage;
            _progressValue = progress;
          });
        }
      }

      if (capture.isMultiPerson || reference.isMultiPerson) {
        // Multi-person evaluation path.
        final multiSequence = capture.getRecordedMultiSequence();
        final multiResult =
            await evaluationService.evaluateMulti(multiSequence, reference, onProgress: onProgress);

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
            await evaluationService.evaluate(userSequence, reference, onProgress: onProgress);

        // Try AI-enhanced coaching (non-blocking — falls back to local).
        final aiCoaching = sl.get<AiCoachingService>();
        final settingsService = sl.get<SettingsService>();
        final aiEnabled = settingsService.aiCoaching &&
            (aiCoaching.isConfigured || settingsService.aiApiKey.isNotEmpty);
        if (aiEnabled) {
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
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _result = null;
                      _multiResult = null;
                    });
                    _runEvaluation();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.go('/'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
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

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _progressStage,
                style: const TextStyle(fontSize: 18, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progressValue,
                  minHeight: 6,
                  backgroundColor: Colors.white10,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_progressValue * 100).round()}%',
                style: const TextStyle(fontSize: 13, color: Colors.white38),
              ),
            ],
          ),
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
      routerConfig: _createRouter(),
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
