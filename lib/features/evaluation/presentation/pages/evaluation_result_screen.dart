import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/core/models/multi_evaluation_result.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/dimension_bar.dart';
import 'package:dance_evaluation/features/evaluation/presentation/widgets/score_indicator.dart';

/// Displays the full evaluation result: overall score, dimension breakdown,
/// and per-joint feedback. Supports both single-person and multi-person results.
class EvaluationResultScreen extends StatelessWidget {
  const EvaluationResultScreen({
    super.key,
    required this.result,
    this.multiResult,
  });

  final EvaluationResult result;
  final MultiPersonEvaluationResult? multiResult;

  @override
  Widget build(BuildContext context) {
    final multi = multiResult;
    if (multi != null && !multi.isSinglePerson) {
      return _buildMultiPersonScreen(context, multi);
    }
    return _buildSinglePersonScreen(context, result);
  }

  Widget _buildMultiPersonScreen(
      BuildContext context, MultiPersonEvaluationResult multi) {
    return DefaultTabController(
      length: multi.personCount,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your Results'),
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
              // Overall aggregate score.
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
              // Per-person tabs.
              Expanded(
                child: TabBarView(
                  children: multi.personResults.map((personResult) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildResultContent(context, personResult),
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
      BuildContext context, EvaluationResult result) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Results')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _buildResultContent(context, result),
        ),
      ),
    );
  }

  Widget _buildResultContent(BuildContext context, EvaluationResult result) {
    return Column(
      children: [
        // Overall score
        ScoreIndicator(score: result.overallScore),
        const SizedBox(height: 8),
        Text(
          result.style.name.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            letterSpacing: 3,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 32),

        // Dimension scores
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Dimensions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...result.dimensions.map(
          (d) => DimensionBar(dimension: d.dimension, score: d.score),
        ),
        const SizedBox(height: 8),
        ...result.dimensions.map(
          (d) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              d.summary,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Joint feedback
        if (result.jointFeedback.isNotEmpty) ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Joint Feedback',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...result.jointFeedback.map(_buildJointCard),
          const SizedBox(height: 32),
        ],

        // Actions
        Row(
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
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildJointCard(JointFeedback jf) {
    final color = jf.score >= 70
        ? const Color(0xFF4CAF50)
        : jf.score >= 40
            ? const Color(0xFFFFC107)
            : const Color(0xFFF44336);

    return Card(
      color: const Color(0xFF1E1E2C),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.circle, color: color, size: 10),
                const SizedBox(width: 8),
                Text(
                  _readableJointName(jf.jointName),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${jf.score.round()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: jf.score / 100,
                minHeight: 4,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              jf.issue,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              jf.correction,
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _readableJointName(String joint) {
    return joint
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m.group(1)} ${m.group(2)!.toLowerCase()}',
        )
        .replaceFirst(joint[0], joint[0].toUpperCase());
  }
}
