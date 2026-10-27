import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'pose_camera.dart';
import 'web_camera.dart';

/// A live camera that analyses the body: ML Kit on the phone, MediaPipe in
/// the browser (the desktop version). The analysis screen only sees this.
abstract class LiveSource {
  ValueNotifier<bool> get ready;
  Stream<PoseSample> get samples;

  /// The session is being recorded.
  bool get recording;

  /// Opens the camera; throws if there is none or it was refused.
  Future<void> start({bool record = false});
  Future<void> pause();
  Future<void> resume();

  /// The camera filling its box, [overlay] drawn in the same 1000-high box.
  Widget preview({Widget? overlay});

  /// Closes the camera. With [save], keeps the recording (the gallery on a
  /// phone, a download on a computer) and says where.
  Future<String?> stop({bool save = false});
}

LiveSource liveSource({required bool front, required bool mirror}) =>
    kIsWeb ? WebCamera(front: front, mirror: mirror) : PoseCamera(front: front, mirror: mirror);
