import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/models/multi_evaluation_result.dart';
import 'package:dance_evaluation/core/services/service_locator.dart';
import 'package:dance_evaluation/features/capture/presentation/capture_controller.dart';
import 'package:dance_evaluation/core/services/result_formatter.dart';
import 'package:dance_evaluation/core/services/sharing_service.dart';
import 'package:dance_evaluation/data/evaluation_history_repository.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/result_content.dart';

/// Displays the full evaluation result: overall score, dimension breakdown,
/// and per-joint feedback. Supports both single-person and multi-person results.
class EvaluationResultScreen extends StatefulWidget {
  const EvaluationResultScreen({
    super.key,
    required this.result,
    this.multiResult,
  });

  final EvaluationResult result;
  final MultiPersonEvaluationResult? multiResult;

  @override
  State<EvaluationResultScreen> createState() => _EvaluationResultScreenState();
}

class _EvaluationResultScreenState extends State<EvaluationResultScreen> {
  final _nameController = TextEditingController();
  bool _nameSaved = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _saveSessionName() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final result = widget.result;
    final updated = EvaluationResult(
      id: result.id,
      overallScore: result.overallScore,
      dimensions: result.dimensions,
      jointFeedback: result.jointFeedback,
      drills: result.drills,
      createdAt: result.createdAt,
      style: result.style,
      referenceName: result.referenceName,
      sessionName: name,
      timingInsights: result.timingInsights,
      jointInsights: result.jointInsights,
      coachingSummary: result.coachingSummary,
    );

    try {
      final repo = ServiceLocator.instance.get<EvaluationHistoryRepository>();
      repo.save(updated);
      setState(() => _nameSaved = true);
    } catch (_) {
      // History repo may not be available.
    }
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.multiResult;
    if (multi != null && !multi.isSinglePerson) {
      return _buildMultiPersonScreen(context, multi);
    }
    return _buildSinglePersonScreen(context, widget.result);
  }

  Widget _buildMultiPersonScreen(
    BuildContext context,
    MultiPersonEvaluationResult multi,
  ) {
    return DefaultTabController(
      length: multi.personCount,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Results'),
          actions: _buildShareActions(context, widget.result),
          bottom: TabBar(
            isScrollable: multi.personCount > 3,
            tabs: List.generate(
              multi.personCount,
              (i) => Tab(text: 'Person ${i + 1}'),
            ),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Group Score: ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${multi.overallScore.round()}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00E5FF),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: multi.personResults.map((personResult) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ResultContent(
                        result: personResult,
                        trailing: _buildActions(context),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSinglePersonScreen(
    BuildContext context,
    EvaluationResult result,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Results'),
        actions: _buildShareActions(context, result),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ResultContent(
            result: result,
            trailing: Column(
              children: [
                // Session name input
                _buildSessionNameInput(),
                const SizedBox(height: 16),
                // Watch playback
                _buildPlaybackButton(context),
                // Actions
                _buildActions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionNameInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Name this session (optional)',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true,
              fillColor: const Color(0xFF1E1E2C),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: const TextStyle(color: Colors.white),
            enabled: !_nameSaved,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _nameSaved ? null : _saveSessionName,
          icon: Icon(
            _nameSaved ? Icons.check_circle : Icons.save,
            color: _nameSaved ? Colors.greenAccent : const Color(0xFF7C4DFF),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackButton(BuildContext context) {
    try {
      final hasVideo = ServiceLocator.instance
              .get<CaptureController>()
              .videoPath !=
          null;
      if (!hasVideo) return const SizedBox.shrink();
    } catch (_) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => context.push('/playback'),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Watch Playback'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        OutlinedButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home),
          label: const Text('Home'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => context.go('/capture'),
          icon: const Icon(Icons.replay),
          label: const Text('Try Again'),
        ),
      ],
    );
  }

  List<Widget> _buildShareActions(
    BuildContext context,
    EvaluationResult result,
  ) {
    return [
      IconButton(
        icon: const Icon(Icons.share),
        tooltip: 'Share Results',
        onPressed: () async {
          final text = ResultFormatter.formatResultAsText(result);
          try {
            final sharing =
                ServiceLocator.instance.get<SharingService>();
            await sharing.shareText(text);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Results shared')),
              );
            }
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing not available')),
              );
            }
          }
        },
      ),
      IconButton(
        icon: const Icon(Icons.download),
        tooltip: 'Export JSON',
        onPressed: () async {
          final json = ResultFormatter.exportAllAsJson([result]);
          try {
            final sharing =
                ServiceLocator.instance.get<SharingService>();
            await sharing.saveJsonFile(
              json,
              'evaluation_${result.id}.json',
            );
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export not available')),
              );
            }
          }
        },
      ),
    ];
  }
}
