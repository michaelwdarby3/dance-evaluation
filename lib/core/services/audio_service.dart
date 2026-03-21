import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'package:dance_evaluation/core/models/reference_choreography.dart';

/// Thin wrapper around audio player operations so we can mock in tests.
abstract class AudioPlayerAdapter {
  Future<void> setUrl(String url);
  Future<void> setAsset(String assetPath);
  Future<void> setAudioSource(AudioSource source);
  Future<void> seek(Duration position);
  Future<void> play();
  Future<void> stop();
  Future<void> dispose();
}

/// Default implementation using just_audio's AudioPlayer.
class JustAudioPlayerAdapter implements AudioPlayerAdapter {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> setUrl(String url) => _player.setUrl(url);
  @override
  Future<void> setAsset(String assetPath) => _player.setAsset(assetPath);
  @override
  Future<void> setAudioSource(AudioSource source) =>
      _player.setAudioSource(source);
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

/// Manages audio playback during dance capture.
///
/// Plays the reference's audio track if available, otherwise generates
/// a metronome click track based on BPM.
class AudioService extends ChangeNotifier {
  AudioService({AudioPlayerAdapter Function()? playerFactory})
      : _playerFactory = playerFactory ?? (() => JustAudioPlayerAdapter());

  final AudioPlayerAdapter Function() _playerFactory;
  AudioPlayerAdapter? _player;
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  /// Prepares audio for the given reference.
  /// Call before starting capture so playback begins instantly.
  Future<void> prepare(ReferenceChoreography reference) async {
    await stop();
    _player = _playerFactory();

    try {
      if (reference.audioAsset != null &&
          reference.audioAsset!.isNotEmpty) {
        // Play the bundled audio file.
        if (reference.audioAsset!.startsWith('http')) {
          await _player!.setUrl(reference.audioAsset!);
        } else {
          await _player!.setAsset(reference.audioAsset!);
        }
      } else {
        // Generate a metronome click track from BPM.
        await _setupMetronome(reference.bpm, reference.poses.duration);
      }
    } catch (e) {
      debugPrint('AudioService: failed to prepare audio: $e');
      // Non-fatal — capture can proceed without audio.
    }
  }

  /// Starts playback. Call when recording begins.
  Future<void> play() async {
    try {
      await _player?.seek(Duration.zero);
      await _player?.play();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('AudioService: playback error: $e');
    }
  }

  /// Stops playback. Call when recording stops.
  Future<void> stop() async {
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (_) {}
    _player = null;
    _isPlaying = false;
    notifyListeners();
  }

  /// Sets up a metronome using a concatenated sequence of silence + tick.
  Future<void> _setupMetronome(double bpm, Duration duration) async {
    if (bpm <= 0) return;

    final beatInterval = Duration(milliseconds: (60000 / bpm).round());
    final totalBeats = (duration.inMilliseconds / beatInterval.inMilliseconds)
            .ceil()
            .clamp(1, 120);

    // Build a playlist of short tick sounds with gaps between them.
    final sources = <AudioSource>[];
    for (var i = 0; i < totalBeats; i++) {
      sources.add(AudioSource.uri(
        Uri.dataFromBytes(
          _generateTickWav(50),
          mimeType: 'audio/wav',
        ),
      ));
      final silenceMs = beatInterval.inMilliseconds - 50;
      if (silenceMs > 0) {
        sources.add(AudioSource.uri(
          Uri.dataFromBytes(
            _generateSilenceWav(silenceMs),
            mimeType: 'audio/wav',
          ),
        ));
      }
    }

    await _player!
        .setAudioSource(ConcatenatingAudioSource(children: sources));
  }

  /// Generates a WAV file with a short sine wave tick.
  static List<int> _generateTickWav(int durationMs) {
    const sampleRate = 22050;
    const frequency = 880.0; // A5
    final numSamples = (sampleRate * durationMs / 1000).round();
    return _buildWav(sampleRate, numSamples, (i) {
      final t = i / sampleRate;
      // Sine wave with quick envelope.
      final envelope = 1.0 - (i / numSamples);
      final sample = (envelope * 0.5 * math.sin(2 * math.pi * frequency * t));
      return (sample * 32767).round().clamp(-32768, 32767);
    });
  }

  /// Generates a WAV file with silence.
  static List<int> _generateSilenceWav(int durationMs) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationMs / 1000).round();
    return _buildWav(sampleRate, numSamples, (_) => 0);
  }

  /// Builds a minimal 16-bit mono WAV file.
  static List<int> _buildWav(
      int sampleRate, int numSamples, int Function(int i) sampleFn) {
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final fileSize = 36 + dataSize;
    final bytes = <int>[];

    void addStr(String s) => bytes.addAll(s.codeUnits);
    void add32(int v) {
      bytes.add(v & 0xFF);
      bytes.add((v >> 8) & 0xFF);
      bytes.add((v >> 16) & 0xFF);
      bytes.add((v >> 24) & 0xFF);
    }

    void add16(int v) {
      bytes.add(v & 0xFF);
      bytes.add((v >> 8) & 0xFF);
    }

    // RIFF header
    addStr('RIFF');
    add32(fileSize);
    addStr('WAVE');

    // fmt chunk
    addStr('fmt ');
    add32(16); // chunk size
    add16(1); // PCM
    add16(1); // mono
    add32(sampleRate);
    add32(sampleRate * 2); // byte rate
    add16(2); // block align
    add16(16); // bits per sample

    // data chunk
    addStr('data');
    add32(dataSize);
    for (var i = 0; i < numSamples; i++) {
      final s = sampleFn(i);
      add16(s & 0xFFFF);
    }

    return bytes;
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }
}
