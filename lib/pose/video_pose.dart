import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'pose_camera.dart';

/// One analysed frame of a video: its time, the image shown, and the pose.
class VideoSample {
  const VideoSample(this.seconds, this.duration, this.image, this.sample);
  final double seconds, duration;
  final Uint8List image;
  final PoseSample sample;
}

/// Walks through a video file [fps] frames a second, runs pose detection on
/// each, and reports every frame. Slower than real time on most phones, so
/// the screen shows progress. [cancel] stops it early.
Stream<VideoSample> analyseVideo(String path, {double fps = 10, bool Function()? cancel}) async* {
  final player = VideoPlayerController.file(File(path));
  await player.initialize();
  final duration = player.value.duration.inMilliseconds / 1000;
  await player.dispose();
  if (duration <= 0) throw const FormatException('empty video');

  final dir = await getTemporaryDirectory();
  final detector = mlkit.PoseDetector(
    options: mlkit.PoseDetectorOptions(mode: mlkit.PoseDetectionMode.single, model: mlkit.PoseDetectionModel.accurate),
  );
  try {
    final step = 1 / fps;
    var n = 0;
    for (var t = 0.0; t < duration; t += step) {
      if (cancel?.call() ?? false) break;
      final file = await VideoThumbnail.thumbnailFile(
        video: path,
        thumbnailPath: '${dir.path}/fa_frame_${n++ % 2}.jpg',
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        timeMs: (t * 1000).round(),
        quality: 80,
      );
      if (file == null) continue;
      final f = File(file);
      final bytes = await f.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = (await codec.getNextFrame()).image;
      final w = frame.width.toDouble(), h = frame.height.toDouble();
      frame.dispose();
      final poses = await detector.processImage(mlkit.InputImage.fromFilePath(file));
      yield VideoSample(
        t,
        duration,
        bytes,
        PoseSample(poses.isEmpty ? null : landmarksOf(poses.first, w, h, mirror: false), w / h),
      );
    }
  } finally {
    await detector.close();
  }
}
