import 'package:flutter/widgets.dart';

import 'live_source.dart';
import 'pose_camera.dart';
import 'video_pose.dart';

/// Not a browser: the phone uses [PoseCamera] instead.
class WebCamera implements LiveSource {
  WebCamera({required bool front, required bool mirror});

  static Future<bool> check() async => false;
  static void preload() {}

  @override
  final ValueNotifier<bool> ready = ValueNotifier(false);
  @override
  Stream<PoseSample> get samples => const Stream.empty();
  @override
  bool get recording => false;
  @override
  Future<void> start({bool record = false}) => throw UnsupportedError('web only');
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Widget preview({Widget? overlay}) => const SizedBox.shrink();
  @override
  Future<String?> stop({bool save = false}) async => null;
}

Stream<VideoSample> analyseVideoWeb(String url, {double fps = 10, bool Function()? cancel}) =>
    throw UnsupportedError('web only');
