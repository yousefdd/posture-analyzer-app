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

/// Width and height from a JPEG's header, without decoding the picture.
(int, int)? jpegSize(Uint8List b) {
  var i = 2;
  while (i + 8 < b.length) {
    if (b[i] != 0xFF) {
      i++;
      continue;
    }
    final m = b[i + 1];
    if (m == 0xFF) {
      i++;
      continue;
    }
    if (m == 0x01 || (m >= 0xD0 && m <= 0xD8)) {
      i += 2;
      continue;
    }
    // A start-of-frame marker holds the size; C4, C8 and CC are not frames.
    if (m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC) {
      return ((b[i + 7] << 8) | b[i + 8], (b[i + 5] << 8) | b[i + 6]);
    }
    i += 2 + ((b[i + 2] << 8) | b[i + 3]);
  }
  return null;
}

/// Walks through a video file [fps] frames a second, runs pose detection on
/// each, and reports every frame. The next frame is taken out of the video
/// while the current one is analysed, so the two waits overlap. [cancel]
/// stops it early.
Stream<VideoSample> analyseVideo(String path, {double fps = 8, bool Function()? cancel}) async* {
  final player = VideoPlayerController.file(File(path));
  await player.initialize();
  final duration = player.value.duration.inMilliseconds / 1000;
  await player.dispose();
  if (duration <= 0) throw const FormatException('empty video');

  final dir = await getTemporaryDirectory();
  // The same model as the live camera: a few times faster than the
  // accurate one, and the analysis is tuned to it.
  final detector = mlkit.PoseDetector(
    options: mlkit.PoseDetectorOptions(mode: mlkit.PoseDetectionMode.single, model: mlkit.PoseDetectionModel.base),
  );
  final times = [for (var t = 0.0; t < duration; t += 1 / fps) t];
  var n = 0;
  // Both sides inside 480 lets Android scale while it decodes.
  Future<String?> frameAt(double t) => VideoThumbnail.thumbnailFile(
        video: path,
        thumbnailPath: '${dir.path}/fa_frame_${n++ % 3}.jpg',
        imageFormat: ImageFormat.JPEG,
        maxWidth: 480,
        maxHeight: 480,
        timeMs: (t * 1000).round(),
        quality: 80,
      );
  try {
    Future<String?>? next = times.isEmpty ? null : frameAt(times.first);
    for (var k = 0; k < times.length; k++) {
      final file = await next!;
      next = k + 1 < times.length ? frameAt(times[k + 1]) : null;
      if (cancel?.call() ?? false) break;
      if (file == null) continue;
      final bytes = await File(file).readAsBytes();
      var size = jpegSize(bytes);
      if (size == null) {
        final frame = (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;
        size = (frame.width, frame.height);
        frame.dispose();
      }
      final w = size.$1.toDouble(), h = size.$2.toDouble();
      final poses = await detector.processImage(mlkit.InputImage.fromFilePath(file));
      yield VideoSample(
        times[k],
        duration,
        bytes,
        PoseSample(poses.isEmpty ? null : landmarksOf(poses.first, w, h, mirror: false), w / h),
      );
    }
    await next?.catchError((_) => null);
  } finally {
    await detector.close();
  }
}
