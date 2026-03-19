// Standalone test of the evaluation pipeline — no Flutter/web needed.
//
// Loads reference JSON files, evaluates one against another (or itself),
// and prints the results.
//
// Run: dart run tools/test_evaluation.dart

import 'dart:convert';
import 'dart:io';

import 'package:dance_evaluation/core/models/pose_sequence.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/features/evaluation/domain/evaluation_service.dart';

Future<ReferenceChoreography> loadReference(String path) async {
  final raw = File(path).readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ReferenceChoreography.fromJson(json);
}

Future<void> evaluate(String label, PoseSequence user, ReferenceChoreography ref) async {
  final service = EvaluationService();
  final result = await service.evaluate(user, ref);

  print('');
  print('=== $label ===');
  print('Reference: ${ref.name} (${ref.poses.frames.length} frames, ${ref.style.name})');
  print('User:      ${user.frames.length} frames');
  print('');
  print('Overall Score: ${result.overallScore.toStringAsFixed(1)}');
  print('');
  print('Dimensions:');
  for (final dim in result.dimensions) {
    print('  ${dim.dimension.name.padRight(18)} ${dim.score.toStringAsFixed(1).padLeft(5)}  ${dim.summary}');
  }
  print('');
  print('Joint Feedback (worst ${result.jointFeedback.length}):');
  for (final jf in result.jointFeedback) {
    print('  ${jf.jointName.padRight(20)} ${jf.score.toStringAsFixed(1).padLeft(5)}  ${jf.issue}');
  }
  print('');
}

void main() async {
  final refDir = Directory('assets/references');
  final files = refDir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  print('Available references:');
  for (final f in files) {
    final ref = await loadReference(f.path);
    print('  ${f.path.split('/').last.padRight(30)} ${ref.name} (${ref.poses.frames.length} frames)');
  }

  // Load all references.
  final refs = <String, ReferenceChoreography>{};
  for (final f in files) {
    final name = f.path.split('/').last;
    refs[name] = await loadReference(f.path);
  }

  // Test 1: Self-evaluation (should score very high).
  final firstRef = refs.values.first;
  await evaluate(
    'Self-evaluation (${firstRef.name} vs itself)',
    firstRef.poses,
    firstRef,
  );

  // Test 2: Cross-evaluation (different references).
  if (refs.length >= 2) {
    final entries = refs.entries.toList();
    final refA = entries[0].value;
    final refB = entries[1].value;
    await evaluate(
      'Cross-evaluation (${refA.name} vs ${refB.name})',
      refA.poses,
      refB,
    );
  }

  // Test 3: Every reference against itself.
  print('\n=== Self-score summary ===');
  for (final entry in refs.entries) {
    final ref = entry.value;
    final service = EvaluationService();
    final result = await service.evaluate(ref.poses, ref);
    print('  ${entry.key.padRight(30)} ${result.overallScore.toStringAsFixed(1).padLeft(5)}');
  }

  // Test 4: Cross-score matrix.
  print('\n=== Cross-score matrix ===');
  final keys = refs.keys.toList();
  // Header.
  stdout.write('${''.padRight(30)}');
  for (final k in keys) {
    stdout.write(k.substring(0, k.length > 12 ? 12 : k.length).padLeft(13));
  }
  print('');
  // Rows.
  for (final rowKey in keys) {
    stdout.write(rowKey.padRight(30));
    for (final colKey in keys) {
      final service = EvaluationService();
      final result = await service.evaluate(refs[rowKey]!.poses, refs[colKey]!);
      stdout.write(result.overallScore.toStringAsFixed(1).padLeft(13));
    }
    print('');
  }
}
