import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/result_content.dart';

/// Shows a detailed view of a past evaluation result.
class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, required this.resultId});

  final String resultId;

  @override
  Widget build(BuildContext context) {
    final repo = ServiceLocator.instance.get<EvaluationHistoryRepository>();
    final result = repo.load(resultId);

    if (result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session Details')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              const Text(
                'Session not found',
                style: TextStyle(color: Colors.white54, fontSize: 18),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/history'),
                child: const Text('Back to History'),
              ),
            ],
          ),
        ),
      );
    }

    final title = result.sessionName ??
        result.referenceName ??
        result.style.name;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ResultContent(result: result),
        ),
      ),
    );
  }
}
