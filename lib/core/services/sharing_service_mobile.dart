import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'sharing_service.dart';

SharingService createSharingService() => MobileSharingService();

class MobileSharingService implements SharingService {
  @override
  Future<void> shareText(String text) async {
    await Share.share(text);
  }

  @override
  Future<void> saveJsonFile(String jsonString, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonString);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
    );
  }

  @override
  Future<String?> pickJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return null;

    final path = result.files.single.path;
    if (path == null) return null;

    return File(path).readAsString();
  }
}
