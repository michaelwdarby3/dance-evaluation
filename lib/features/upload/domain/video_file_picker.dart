/// Platform-agnostic video file picker.
abstract class VideoFilePicker {
  /// Returns a URL/path to the picked video, or null if cancelled.
  /// On web: an object URL. On mobile: a file path.
  Future<String?> pickVideo();

  void dispose();
}
