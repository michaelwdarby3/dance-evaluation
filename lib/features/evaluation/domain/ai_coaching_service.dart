import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/features/evaluation/domain/feedback_generator.dart';

/// AI-powered coaching feedback using the Claude API.
///
/// Enhances the local [DetailedFeedback] with natural-sounding, personalized
/// coaching language. Falls back to local feedback if the API is unavailable.
class AiCoachingService {
  AiCoachingService({
    String? apiKey,
    String? baseUrl,
    http.Client? httpClient,
  })  : _apiKey = apiKey ?? const String.fromEnvironment(
              'CLAUDE_API_KEY',
              defaultValue: '',
            ),
        _baseUrl = baseUrl ?? 'https://api.anthropic.com',
        _httpClient = httpClient ?? http.Client();

  final String _apiKey;
  final String _baseUrl;
  final http.Client _httpClient;

  /// Whether the service is configured with a valid API key.
  bool get isConfigured => _apiKey.isNotEmpty;

  /// Generate AI-enhanced coaching feedback.
  ///
  /// Takes the local [DetailedFeedback] and [EvaluationResult] as context,
  /// sends them to Claude for natural language coaching, and returns the
  /// enhanced text. Falls back to local feedback on any error.
  Future<String> generateCoaching({
    required EvaluationResult result,
    required DetailedFeedback localFeedback,
    List<EvaluationResult>? recentHistory,
  }) async {
    if (!isConfigured) {
      return localFeedback.overallCoaching;
    }

    try {
      final prompt = _buildPrompt(result, localFeedback, recentHistory);

      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 300,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final content = body['content'] as List;
        if (content.isNotEmpty) {
          final text = content.first['text'] as String;
          return text.trim();
        }
      }

      debugPrint(
        'AiCoachingService: API returned ${response.statusCode}',
      );
      return localFeedback.overallCoaching;
    } catch (e) {
      debugPrint('AiCoachingService: error: $e');
      return localFeedback.overallCoaching;
    }
  }

  String _buildPrompt(
    EvaluationResult result,
    DetailedFeedback localFeedback,
    List<EvaluationResult>? history,
  ) {
    final buf = StringBuffer();

    buf.writeln(
      'You are a supportive dance coach giving brief, actionable feedback '
      'after a practice session. Be encouraging but honest. '
      'Keep your response to 2-4 sentences. Do not use bullet points.',
    );
    buf.writeln();
    buf.writeln('Dance style: ${result.style.name}');
    buf.writeln(
      'Overall score: ${result.overallScore.toStringAsFixed(1)}/100',
    );
    buf.writeln();
    buf.writeln('Dimension scores:');
    for (final dim in result.dimensions) {
      buf.writeln(
        '- ${dim.dimension.name}: ${dim.score.toStringAsFixed(1)}',
      );
    }
    buf.writeln();
    buf.writeln('Timing analysis:');
    for (final t in localFeedback.timingInsights) {
      buf.writeln('- $t');
    }
    buf.writeln();
    buf.writeln('Joint issues:');
    for (final j in localFeedback.jointInsights) {
      buf.writeln('- $j');
    }

    if (history != null && history.length >= 2) {
      buf.writeln();
      buf.writeln('Recent session scores (newest first):');
      for (final h in history.take(5)) {
        buf.writeln(
          '- ${h.overallScore.toStringAsFixed(1)} '
          '(${h.createdAt.toIso8601String().substring(0, 10)})',
        );
      }
    }

    buf.writeln();
    buf.writeln(
      'Give a personalized coaching response based on the above data.',
    );

    return buf.toString();
  }

  void dispose() {
    _httpClient.close();
  }
}
