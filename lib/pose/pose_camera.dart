import 'dart:async';
import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart' as mlkit;

import '../analysis/analyzer.dart';
import 'live_source.dart';

/// One analysed frame: the 33 body points (0..1, already mirrored when the
/// preview is) and the frame's upright width / height.
class PoseSample {
  const PoseSample(this.points, this.aspect);
  final List<Lm>? points; // null: nobody in the frame
  final double aspect;
}

/// ML Kit's 33 points, in MediaPipe order, from a detected pose.
List<Lm> landmarksOf(mlkit.Pose pose, double width, double height, {required bool mirror}) {
  final out = List<Lm>.filled(33, const Lm(0, 0, 0));
  for (final e in pose.landmarks.entries) {
    final i = e.key.index; // PoseLandmarkType follows the 33-point order
    if (i < 0 || i >= 33) continue;
    var x = width > 0 ? e.value.x / width : 0.0;
    if (mirror) x = 1 - x;
    out[i] = Lm(x.clamp(0.0, 1.0), (height > 0 ? e.value.y / height : 0.0).clamp(0.0, 1.0), e.value.likelihood);
  }
  return out;
}

/// The phone camera, front or back, with every frame run through ML Kit
/// pose detection. Frames that arrive while ML Kit is busy are dropped, so
/// the overlay stays live. It can record the session to a video at the same
/// time.
class PoseCamera implements LiveSource {
  PoseCamera({required this.front, required this.mirror});

  final bool front;
  final bool mirror;

  CameraController? _camera;
  final _detector = mlkit.PoseDetector(
    // The base model keeps up with the camera on most phones; the accurate
    // one is several times slower.
    options: mlkit.PoseDetectorOptions(mode: mlkit.PoseDetectionMode.stream, model: mlkit.PoseDetectionModel.base),
  );
  final _samples = StreamController<PoseSample>.broadcast();
  bool _busy = false;
  bool _closed = false;
  bool _recording = false;

  @override
  bool get recording => _recording;

  @override
  final ValueNotifier<bool> ready = ValueNotifier(false);

  @override
  Stream<PoseSample> get samples => _samples.stream;
  bool get _mirrored => front && mirror;

  /// Upright width / height of the analysed frames.
  double get aspect {
    final size = _camera?.value.previewSize;
    if (size == null) return 3 / 4;
    return size.height / size.width; // previewSize is reported landscape
  }

  /// Opens the camera; [record] also starts a video of the session.
  @override
  Future<void> start({bool record = false}) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw CameraException('none', 'No camera');
    final want = front ? CameraLensDirection.front : CameraLensDirection.back;
    final desc = cameras.firstWhere((c) => c.lensDirection == want, orElse: () => cameras.first);
    final camera = CameraController(
      desc,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    await camera.initialize(); // asks for the camera permission if needed
    _camera = camera;
    if (record) {
      try {
        await camera.startVideoRecording(onAvailable: _onImage);
        _recording = true;
      } catch (_) {
        await camera.startImageStream(_onImage);
      }
    } else {
      await camera.startImageStream(_onImage);
    }
    ready.value = true;
  }

  Future<void> _onImage(CameraImage image) async {
    if (_busy || _closed) return;
    _busy = true;
    try {
      final input = _input(image);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (_samples.isClosed) return;
      final sideways = _rotation % 180 != 0;
      final w = (sideways ? image.height : image.width).toDouble();
      final h = (sideways ? image.width : image.height).toDouble();
      _samples.add(PoseSample(
        poses.isEmpty ? null : landmarksOf(poses.first, w, h, mirror: _mirrored),
        w / h,
      ));
    } catch (_) {
      // A dropped frame.
    } finally {
      _busy = false;
    }
  }

  int get _rotation => _camera?.description.sensorOrientation ?? 0;

  mlkit.InputImage? _input(CameraImage image) {
    final rotation = mlkit.InputImageRotationValue.fromRawValue(_rotation);
    final format = mlkit.InputImageFormatValue.fromRawValue(image.format.raw);
    if (rotation == null || format == null || image.planes.length != 1) return null;
    final plane = image.planes.first;
    return mlkit.InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: mlkit.InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Future<void> pause() async {
    final c = _camera;
    if (c == null) return;
    if (_recording) {
      await c.pauseVideoRecording();
    }
    _closed = true;
  }

  @override
  Future<void> resume() async {
    final c = _camera;
    if (c == null) return;
    if (_recording) await c.resumeVideoRecording();
    _closed = false;
  }

  /// The camera filling its box, with [overlay] drawn in the same
  /// 1000-high coordinate box so points land on the body.
  @override
  Widget preview({Widget? overlay}) {
    return ValueListenableBuilder<bool>(
      valueListenable: ready,
      builder: (context, isReady, _) {
        final camera = _camera;
        if (!isReady || camera == null) return const ColoredBox(color: Colors.black);
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 1000 * aspect,
              height: 1000,
              child: Stack(fit: StackFit.expand, children: [
                // The front preview is already mirrored; the back one only when asked.
                if (!front && mirror)
                  Transform.flip(flipX: true, child: CameraPreview(camera))
                else
                  CameraPreview(camera),
                if (overlay != null) overlay,
              ]),
            ),
          ),
        );
      },
    );
  }

  /// Stops everything; with [save], puts the recording in the gallery.
  @override
  Future<String?> stop({bool save = false}) async {
    _closed = true;
    final camera = _camera;
    _camera = null;
    ready.value = false;
    String? video;
    if (camera != null) {
      try {
        if (_recording && camera.value.isRecordingVideo) {
          video = (await camera.stopVideoRecording()).path;
        } else if (camera.value.isStreamingImages) {
          await camera.stopImageStream();
        }
      } catch (_) {}
      await camera.dispose();
    }
    await _detector.close();
    if (!_samples.isClosed) await _samples.close();
    if (!save || video == null) return null;
    try {
      await Gal.putVideo(video, album: 'Posture Analyzer');
      return 'تم حفظ فيديو الجلسة في المعرض (ألبوم Posture Analyzer)';
    } catch (_) {
      return null;
    }
  }
}
