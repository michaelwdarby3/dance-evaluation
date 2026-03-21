import 'package:image_picker/image_picker.dart';

import 'video_file_picker.dart';

VideoFilePicker createVideoFilePicker() => MobileVideoFilePicker();

/// Picks a video file from the device gallery using image_picker.
class MobileVideoFilePicker implements VideoFilePicker {
  final _picker = ImagePicker();

  @override
  Future<String?> pickVideo() async {
    final xFile = await _picker.pickVideo(source: ImageSource.gallery);
    return xFile?.path;
  }

  @override
  void dispose() {}
}
