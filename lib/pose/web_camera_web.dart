import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../analysis/analyzer.dart';
import 'live_source.dart';
import 'pose_camera.dart';
import 'video_pose.dart';

JSObject get _bridge => globalContext['paPose'] as JSObject;

List<Lm>? _points(JSArray<JSArray<JSNumber>> lm) {
  final list = lm.toDart;
  if (list.length < 33) return null;
  return [
    for (final p in list.take(33))
      () {
        final v = p.toDart.map((n) => n.toDartDouble).toList();
        return Lm(v[0].clamp(0.0, 1.0), v[1].clamp(0.0, 1.0), v[2]);
      }(),
  ];
}

/// The webcam in a browser, with MediaPipe finding the body on every frame
/// (web/pa_pose.js). Dart polls the latest result thirty times a second.
class WebCamera implements LiveSource {
  WebCamera({required this.front, required this.mirror});
  final bool front, mirror;

  static const _viewType = 'pa-camera';
  static bool _registered = false;

  /// Is there a camera this page may use?
  static Future<bool> check() async {
    if (!globalContext.has('paPose')) return false;
    return (await _bridge.callMethod<JSPromise<JSBoolean>>('check'.toJS).toDart).toDart;
  }

  /// Starts loading the body model in the background, so the camera
  /// screen opens at once later.
  static void preload() {
    if (globalContext.has('paPose')) _bridge.callMethod('preload'.toJS);
  }

  final _samples = StreamController<PoseSample>.broadcast();
  Timer? _poll;
  double _lastT = -1;
  double _aspect = 16 / 9;
  bool _recording = false;

  @override
  final ValueNotifier<bool> ready = ValueNotifier(false);
  @override
  Stream<PoseSample> get samples => _samples.stream;
  @override
  bool get recording => _recording;

  @override
  Future<void> start({bool record = false}) async {
    if (!globalContext.has('paPose')) throw StateError('no bridge');
    if (!_registered) {
      final video = _bridge.callMethod<JSObject>('video'.toJS);
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => video);
      _registered = true;
    }
    final ok = (await _bridge.callMethod<JSPromise<JSBoolean>>('start'.toJS, mirror.toJS, front.toJS).toDart).toDart;
    if (!ok) throw StateError('camera refused');
    if (record) _recording = _bridge.callMethod<JSBoolean>('record'.toJS).toDart;
    ready.value = true;
    _poll = Timer.periodic(const Duration(milliseconds: 33), (_) => _read());
  }

  void _read() {
    final f = _bridge.callMethod<JSAny?>('frame'.toJS);
    if (f == null || _samples.isClosed) return;
    final o = f as JSObject;
    final t = (o['t'] as JSNumber).toDartDouble;
    if (t == _lastT) return;
    _lastT = t;
    final w = (o['w'] as JSNumber).toDartDouble, h = (o['h'] as JSNumber).toDartDouble;
    if (w > 0 && h > 0) _aspect = w / h;
    _samples.add(PoseSample(_points(o['lm'] as JSArray<JSArray<JSNumber>>), _aspect));
  }

  @override
  Future<void> pause() async => _bridge.callMethod('pause'.toJS);

  @override
  Future<void> resume() async => _bridge.callMethod('resume'.toJS);

  @override
  Widget preview({Widget? overlay}) => ValueListenableBuilder<bool>(
        valueListenable: ready,
        builder: (context, isReady, _) => ColoredBox(
          color: Colors.black,
          child: !isReady
              ? const SizedBox.expand()
              : ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: 1000 * _aspect,
                      height: 1000,
                      child: Stack(fit: StackFit.expand, children: [
                        const HtmlElementView(viewType: _viewType),
                        if (overlay != null) IgnorePointer(child: overlay),
                      ]),
                    ),
                  ),
                ),
        ),
      );

  @override
  Future<String?> stop({bool save = false}) async {
    _poll?.cancel();
    _poll = null;
    String? saved;
    if (save && _recording) {
      final d = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final name = 'PostureAnalyzer_${d.year}${two(d.month)}${two(d.day)}_${two(d.hour)}${two(d.minute)}.webm';
      final ok = (await _bridge.callMethod<JSPromise<JSBoolean>>('saveRecording'.toJS, name.toJS).toDart).toDart;
      if (ok) saved = 'تم تنزيل فيديو الجلسة ($name) إلى مجلد التنزيلات';
    }
    _recording = false;
    _bridge.callMethod('stop'.toJS);
    ready.value = false;
    if (!_samples.isClosed) await _samples.close();
    return saved;
  }
}

/// A video file in the browser, [fps] moments a second, each with its pose.
Stream<VideoSample> analyseVideoWeb(String url, {double fps = 10, bool Function()? cancel}) async* {
  final duration = (await _bridge.callMethod<JSPromise<JSNumber>>('openFile'.toJS, url.toJS).toDart).toDartDouble;
  if (duration <= 0) throw const FormatException('cannot open the video');
  try {
    for (var t = 0.0; t < duration; t += 1 / fps) {
      if (cancel?.call() ?? false) break;
      final r = await _bridge.callMethod<JSPromise<JSObject?>>('analyseAt'.toJS, t.toJS).toDart;
      if (r == null) continue;
      final w = (r['w'] as JSNumber).toDartDouble, h = (r['h'] as JSNumber).toDartDouble;
      final jpeg = (r['jpeg'] as JSString).toDart;
      final bytes = base64Decode(jpeg.substring(jpeg.indexOf(',') + 1));
      yield VideoSample(t, duration, bytes, PoseSample(_points(r['lm'] as JSArray<JSArray<JSNumber>>), w / h));
    }
  } finally {
    _bridge.callMethod('closeFile'.toJS);
  }
}
