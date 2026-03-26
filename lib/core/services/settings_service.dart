import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent app settings with change notification.
///
/// All settings have sensible defaults and are persisted via SharedPreferences.
class SettingsService extends ChangeNotifier {
  SettingsService();

  SharedPreferences? _prefs;
  bool _loaded = false;

  // ---------------------------------------------------------------------------
  // Keys
  // ---------------------------------------------------------------------------

  static const _kAudioEnabled = 'audio_enabled';
  static const _kSkeletonOverlay = 'skeleton_overlay';
  static const _kReferenceGhost = 'reference_ghost';
  static const _kGhostOpacity = 'ghost_opacity';
  static const _kCountdownSeconds = 'countdown_seconds';
  static const _kMaxRecordingSeconds = 'max_recording_seconds';
  static const _kMultiPersonDetection = 'multi_person_detection';
  static const _kAiCoaching = 'ai_coaching';
  static const _kAiApiKey = 'ai_api_key';
  static const _kMirrorPreview = 'mirror_preview';
  static const _kHapticFeedback = 'haptic_feedback';
  static const _kDefaultStyle = 'default_style';
  static const _kVideoRecording = 'video_recording';
  static const _kHasSeenOnboarding = 'has_seen_onboarding';
  static const _kMinConfidence = 'min_confidence';

  // ---------------------------------------------------------------------------
  // Defaults
  // ---------------------------------------------------------------------------

  static const bool defaultAudioEnabled = true;
  static const bool defaultSkeletonOverlay = true;
  static const bool defaultReferenceGhost = true;
  static const double defaultGhostOpacity = 0.5;
  static const int defaultCountdownSeconds = 3;
  static const int defaultMaxRecordingSeconds = 30;
  static const bool defaultMultiPersonDetection = true;
  static const bool defaultAiCoaching = false;
  static const bool defaultMirrorPreview = true;
  static const bool defaultHapticFeedback = true;
  static const String defaultDefaultStyle = 'hip_hop';
  static const bool defaultVideoRecording = true;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Load persisted settings. Call once at app startup.
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loaded = true;
    notifyListeners();
  }

  bool get isLoaded => _loaded;

  // ---------------------------------------------------------------------------
  // Capture settings
  // ---------------------------------------------------------------------------

  /// Play audio (reference track or metronome) during capture.
  bool get audioEnabled => _prefs?.getBool(_kAudioEnabled) ?? defaultAudioEnabled;
  set audioEnabled(bool v) {
    _prefs?.setBool(_kAudioEnabled, v);
    notifyListeners();
  }

  /// Show the real-time skeleton overlay on the camera preview.
  bool get skeletonOverlay =>
      _prefs?.getBool(_kSkeletonOverlay) ?? defaultSkeletonOverlay;
  set skeletonOverlay(bool v) {
    _prefs?.setBool(_kSkeletonOverlay, v);
    notifyListeners();
  }

  /// Show the reference ghost overlay during recording.
  bool get referenceGhost =>
      _prefs?.getBool(_kReferenceGhost) ?? defaultReferenceGhost;
  set referenceGhost(bool v) {
    _prefs?.setBool(_kReferenceGhost, v);
    notifyListeners();
  }

  /// Opacity of the reference ghost overlay (0.0 – 1.0).
  double get ghostOpacity =>
      _prefs?.getDouble(_kGhostOpacity) ?? defaultGhostOpacity;
  set ghostOpacity(double v) {
    _prefs?.setDouble(_kGhostOpacity, v.clamp(0.0, 1.0));
    notifyListeners();
  }

  /// Seconds to count down before recording starts.
  int get countdownSeconds =>
      _prefs?.getInt(_kCountdownSeconds) ?? defaultCountdownSeconds;
  set countdownSeconds(int v) {
    _prefs?.setInt(_kCountdownSeconds, v.clamp(1, 10));
    notifyListeners();
  }

  /// Maximum recording duration in seconds.
  int get maxRecordingSeconds =>
      _prefs?.getInt(_kMaxRecordingSeconds) ?? defaultMaxRecordingSeconds;
  set maxRecordingSeconds(int v) {
    _prefs?.setInt(_kMaxRecordingSeconds, v.clamp(5, 120));
    notifyListeners();
  }

  /// Record video alongside pose capture (for playback after evaluation).
  bool get videoRecording =>
      _prefs?.getBool(_kVideoRecording) ?? defaultVideoRecording;
  set videoRecording(bool v) {
    _prefs?.setBool(_kVideoRecording, v);
    notifyListeners();
  }

  /// Mirror the front camera preview horizontally.
  bool get mirrorPreview =>
      _prefs?.getBool(_kMirrorPreview) ?? defaultMirrorPreview;
  set mirrorPreview(bool v) {
    _prefs?.setBool(_kMirrorPreview, v);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Detection settings
  // ---------------------------------------------------------------------------

  /// Enable multi-person pose detection (detects up to 5 people).
  bool get multiPersonDetection =>
      _prefs?.getBool(_kMultiPersonDetection) ?? defaultMultiPersonDetection;
  set multiPersonDetection(bool v) {
    _prefs?.setBool(_kMultiPersonDetection, v);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Evaluation settings
  // ---------------------------------------------------------------------------

  /// Enable AI-enhanced coaching via Claude API.
  bool get aiCoaching => _prefs?.getBool(_kAiCoaching) ?? defaultAiCoaching;
  set aiCoaching(bool v) {
    _prefs?.setBool(_kAiCoaching, v);
    notifyListeners();
  }

  /// Claude API key for AI coaching (stored locally only).
  String get aiApiKey => _prefs?.getString(_kAiApiKey) ?? '';
  set aiApiKey(String v) {
    _prefs?.setString(_kAiApiKey, v);
    notifyListeners();
  }

  /// Default dance style for new evaluations.
  String get defaultStyle =>
      _prefs?.getString(_kDefaultStyle) ?? defaultDefaultStyle;
  set defaultStyle(String v) {
    _prefs?.setString(_kDefaultStyle, v);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Feedback settings
  // ---------------------------------------------------------------------------

  /// Haptic feedback on countdown ticks and recording start/stop.
  bool get hapticFeedback =>
      _prefs?.getBool(_kHapticFeedback) ?? defaultHapticFeedback;
  set hapticFeedback(bool v) {
    _prefs?.setBool(_kHapticFeedback, v);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Confidence filtering
  // ---------------------------------------------------------------------------

  static const double defaultMinConfidence = 0.3;

  /// Minimum confidence threshold for pose frames (0.0 – 1.0).
  /// Frames below this are dropped before evaluation.
  double get minConfidence =>
      _prefs?.getDouble(_kMinConfidence) ?? defaultMinConfidence;
  set minConfidence(double v) {
    _prefs?.setDouble(_kMinConfidence, v.clamp(0.0, 1.0));
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------

  /// Whether the user has completed the onboarding flow.
  bool get hasSeenOnboarding =>
      _prefs?.getBool(_kHasSeenOnboarding) ?? false;
  set hasSeenOnboarding(bool v) {
    _prefs?.setBool(_kHasSeenOnboarding, v);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Reset all settings to defaults.
  Future<void> resetAll() async {
    await _prefs?.clear();
    notifyListeners();
  }
}
