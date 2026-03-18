import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/references/hip_hop_basic.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/features/capture/presentation/pages/capture_screen.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';
import 'package:dance_evaluation/features/evaluation/presentation/pages/evaluation_result_screen.dart';
import 'package:dance_evaluation/features/home/presentation/pages/home_screen.dart';
import 'package:dance_evaluation/features/upload/presentation/pages/upload_processing_screen.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/capture',
      builder: (context, state) => const CaptureScreen(),
    ),
    GoRoute(
      path: '/upload',
      builder: (context, state) => const UploadProcessingScreen(),
    ),
    GoRoute(
      path: '/evaluation/:id',
      builder: (context, state) => const _EvaluationLoader(),
    ),
  ],
);

/// Runs the evaluation pipeline on the captured sequence and shows results.
class _EvaluationLoader extends StatefulWidget {
  const _EvaluationLoader();

  @override
  State<_EvaluationLoader> createState() => _EvaluationLoaderState();
}

class _EvaluationLoaderState extends State<_EvaluationLoader> {
  EvaluationResult? _result;

  @override
  void initState() {
    super.initState();
    _runEvaluation();
  }

  Future<void> _runEvaluation() async {
    final sl = ServiceLocator.instance;
    final capture = sl.get<CaptureController>();
    final evaluationService = sl.get<EvaluationService>();

    final userSequence = capture.getRecordedSequence();
    final reference = getHipHopBasicReference();

    final result = await evaluationService.evaluate(userSequence, reference);

    if (mounted) {
      setState(() => _result = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return EvaluationResultScreen(result: result);
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
        colorScheme: ColorScheme.dark(
          primary: _purple,
          secondary: _cyan,
          surface: const Color(0xFF1E1E2C),
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
