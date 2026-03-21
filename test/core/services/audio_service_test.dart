import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

import 'package:dance_evaluation/core/services/audio_service.dart';
import 'package:dance_evaluation/core/constants/style_constants.dart';
import 'package:dance_evaluation/core/models/reference_choreography.dart';
import 'package:dance_evaluation/core/models/pose_frame.dart';
import 'package:dance_evaluation/core/models/landmark.dart';
import 'package:dance_evaluation/core/models/pose_sequence.dart';

ReferenceChoreography _makeReference({
  double bpm = 120,
  int durationMs = 2000,
  int frameCount = 10,
  String? audioAsset,
}) {
  final landmarks = List.generate(
    33,
    (i) => Landmark(x: 0.5, y: 0.5 + i * 0.01, z: 0.0, visibility: 0.9),
  );
  final frames = List.generate(
    frameCount,
    (i) => PoseFrame(
      timestamp: Duration(
        milliseconds: (i * durationMs / frameCount).round(),
      ),
      landmarks: landmarks,
    ),
  );
  return ReferenceChoreography(
    id: 'test_ref',
    name: 'Test Reference',
    style: DanceStyle.hipHop,
    poses: PoseSequence(
      frames: frames,
      fps: frameCount / (durationMs / 1000),
      duration: Duration(milliseconds: durationMs),
    ),
    bpm: bpm,
    description: 'Test',
    difficulty: 'beginner',
    audioAsset: audioAsset,
  );
}

class _FakePlayerAdapter implements AudioPlayerAdapter {
  bool playCalled = false;
  bool stopCalled = false;
  bool disposeCalled = false;
  String? lastUrl;
  String? lastAsset;

  @override
  Future<void> setUrl(String url) async => lastUrl = url;
  @override
  Future<void> setAsset(String assetPath) async => lastAsset = assetPath;
  @override
  Future<void> setAudioSource(AudioSource source) async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> play() async => playCalled = true;
  @override
  Future<void> stop() async => stopCalled = true;
  @override
  Future<void> dispose() async => disposeCalled = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioService', () {
    late AudioService service;
    late _FakePlayerAdapter lastPlayer;

    setUp(() {
      service = AudioService(playerFactory: () {
        lastPlayer = _FakePlayerAdapter();
        return lastPlayer;
      });
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state is not playing', () {
      expect(service.isPlaying, isFalse);
    });

    test('prepare does not throw for reference without audio', () async {
      final ref = _makeReference(bpm: 120, durationMs: 2000);
      await expectLater(service.prepare(ref), completes);
    });

    test('prepare does not throw for zero BPM', () async {
      final ref = _makeReference(bpm: 0, durationMs: 2000);
      await expectLater(service.prepare(ref), completes);
    });

    test('prepare does not throw for very high BPM', () async {
      final ref = _makeReference(bpm: 300, durationMs: 5000);
      await expectLater(service.prepare(ref), completes);
    });

    test('stop resets playing state', () async {
      final ref = _makeReference();
      await service.prepare(ref);
      await service.stop();
      expect(service.isPlaying, isFalse);
    });

    test('stop is safe to call without prepare', () async {
      await expectLater(service.stop(), completes);
    });

    test('stop is safe to call multiple times', () async {
      final ref = _makeReference();
      await service.prepare(ref);
      await service.stop();
      await expectLater(service.stop(), completes);
    });

    test('prepare replaces previous audio', () async {
      final ref1 = _makeReference(bpm: 100);
      final ref2 = _makeReference(bpm: 140);
      await service.prepare(ref1);
      await expectLater(service.prepare(ref2), completes);
    });

    test('play sets isPlaying to true', () async {
      final ref = _makeReference(bpm: 120, durationMs: 1000);
      await service.prepare(ref);
      await service.play();
      expect(service.isPlaying, isTrue);
      expect(lastPlayer.playCalled, isTrue);
    });

    test('notifies listeners on state changes', () async {
      final ref = _makeReference();
      int notifyCount = 0;
      service.addListener(() => notifyCount++);

      await service.prepare(ref);
      await service.stop();

      expect(notifyCount, greaterThan(0));
    });

    test('prepare with URL audio sets URL on player', () async {
      final ref = _makeReference(audioAsset: 'http://example.com/track.mp3');
      await service.prepare(ref);
      expect(lastPlayer.lastUrl, 'http://example.com/track.mp3');
    });

    test('prepare with asset audio sets asset on player', () async {
      final ref = _makeReference(audioAsset: 'assets/audio/track.mp3');
      await service.prepare(ref);
      expect(lastPlayer.lastAsset, 'assets/audio/track.mp3');
    });
  });
}
