/// Platform-agnostic interface for sharing text and JSON files.
abstract class SharingService {
  /// Shares a text string (share sheet on mobile, clipboard on web).
  Future<void> shareText(String text);

  /// Saves/shares a JSON string as a downloadable file.
  Future<void> saveJsonFile(String jsonString, String fileName);

  /// Opens a file picker and returns the contents of the selected JSON file,
  /// or null if cancelled.
  Future<String?> pickJsonFile();
}
