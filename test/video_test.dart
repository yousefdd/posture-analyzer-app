import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foot_analyzer/pose/video_pose.dart';

void main() {
  test('a video frame\'s size is read from the JPEG header', () {
    expect(jpegSize(File('test/fixtures/frame_480x270.jpg').readAsBytesSync()), (480, 270));
    expect(jpegSize(File('test/fixtures/frame_360x480_progressive.jpg').readAsBytesSync()), (360, 480));
  });
}
