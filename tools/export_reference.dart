// Standalone Dart script to export the hardcoded hip_hop_basic reference to JSON.
// Run: dart run tools/export_reference.dart

import 'dart:convert';
import 'dart:io';

import 'package:dance_evaluation/data/references/hip_hop_basic.dart';

void main() {
  final ref = getHipHopBasicReference();
  final json = const JsonEncoder.withIndent('  ').convert(ref.toJson());
  final outFile = File('assets/references/hip_hop_basic.json');
  outFile.writeAsStringSync(json);
  print('Exported ${ref.poses.frames.length} frames to ${outFile.path}');
}
