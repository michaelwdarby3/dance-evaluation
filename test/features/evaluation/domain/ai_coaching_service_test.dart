import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/evaluation_result.dart';
import 'package:dance_evaluation/features/evaluation/domain/ai_coaching_service.dart';
import 'package:dance_evaluation/features/evaluation/domain/feedback_generator.dart';

EvaluationResult _makeResult() => EvaluationResult(
      id: 'test',
      overallScore: 72,
      dimensions: const [
        DimensionScore(
          dimension: EvalDimension.timing,
          score: 80,
          summary: 'Good',
        ),
        DimensionScore(
          dimension: EvalDimension.technique,
          score: 65,
          summary: 'Decent',
        ),
      ],
      jointFeedback: const [],
      drills: const [],
      createdAt: DateTime(2026, 3, 21),
      style: DanceStyle.hipHop,
    );

const _localFeedback = DetailedFeedback(
  timingInsights: ['You rushed in the first quarter.'],
  jointInsights: ['Your left elbow was too extended in the second quarter.'],
  overallCoaching: 'Local coaching text.',
);

void main() {
  group('AiCoachingService', () {
    test('isConfigured returns false without API key', () {
      final service = AiCoachingService(apiKey: '');
      expect(service.isConfigured, isFalse);
      service.dispose();
    });

    test('isConfigured returns true with API key', () {
      final service = AiCoachingService(apiKey: 'sk-test-key');
      expect(service.isConfigured, isTrue);
      service.dispose();
    });

    test('returns local feedback when not configured', () async {
      final service = AiCoachingService(apiKey: '');
      final result = await service.generateCoaching(
        result: _makeResult(),
        localFeedback: _localFeedback,
      );
      expect(result, 'Local coaching text.');
      service.dispose();
    });

    test('returns AI response on successful API call', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/v1/messages');
        expect(request.headers['x-api-key'], 'sk-test-key');

        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'Great session! Focus on your elbows.'},
            ],
          }),
          200,
        );
      });

      final service = AiCoachingService(
        apiKey: 'sk-test-key',
        httpClient: mockClient,
      );

      final result = await service.generateCoaching(
        result: _makeResult(),
        localFeedback: _localFeedback,
      );

      expect(result, 'Great session! Focus on your elbows.');
      service.dispose();
    });

    test('falls back to local on API error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"error": "unauthorized"}', 401);
      });

      final service = AiCoachingService(
        apiKey: 'sk-bad-key',
        httpClient: mockClient,
      );

      final result = await service.generateCoaching(
        result: _makeResult(),
        localFeedback: _localFeedback,
      );

      expect(result, 'Local coaching text.');
      service.dispose();
    });

    test('falls back to local on network error', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network error');
      });

      final service = AiCoachingService(
        apiKey: 'sk-test-key',
        httpClient: mockClient,
      );

      final result = await service.generateCoaching(
        result: _makeResult(),
        localFeedback: _localFeedback,
      );

      expect(result, 'Local coaching text.');
      service.dispose();
    });

    test('includes history in prompt when provided', () async {
      String? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = request.body;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': 'You are improving!'},
            ],
          }),
          200,
        );
      });

      final service = AiCoachingService(
        apiKey: 'sk-test-key',
        httpClient: mockClient,
      );

      await service.generateCoaching(
        result: _makeResult(),
        localFeedback: _localFeedback,
        recentHistory: [
          _makeResult(),
          EvaluationResult(
            id: 'old',
            overallScore: 60,
            dimensions: const [],
            jointFeedback: const [],
            drills: const [],
            createdAt: DateTime(2026, 3, 20),
            style: DanceStyle.hipHop,
          ),
        ],
      );

      expect(capturedBody, contains('Recent session scores'));
      service.dispose();
    });
  });
}
