// ABOUTME: Converts raw camera frame bytes into averaged RGB color samples.
// ABOUTME: Supports BGRA and YUV frame layouts used by mobile camera streams.
import 'dart:typed_data';

import 'package:camera/camera.dart';

import 'color_workspace.dart';

class ColorSampler {
  static const int gridSize = 9;

  static SampledColor? sampleCameraImage(CameraImage image) {
    return switch (image.format.group) {
      ImageFormatGroup.bgra8888 => sampleBgra(
        bytes: image.planes[0].bytes,
        width: image.width,
        height: image.height,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
      ImageFormatGroup.yuv420 => sampleYuv420(
        yBytes: image.planes[0].bytes,
        uBytes: image.planes[1].bytes,
        vBytes: image.planes[2].bytes,
        width: image.width,
        height: image.height,
        yBytesPerRow: image.planes[0].bytesPerRow,
        uvBytesPerRow: image.planes[1].bytesPerRow,
        uvBytesPerPixel: image.planes[1].bytesPerPixel ?? 1,
      ),
      _ => null,
    };
  }

  static SampledColor sampleBgra({
    required Uint8List bytes,
    required int width,
    required int height,
    required int bytesPerRow,
  }) {
    var red = 0;
    var green = 0;
    var blue = 0;
    var count = 0;

    for (final point in _samplePoints(width, height)) {
      final index = (point.y * bytesPerRow) + (point.x * 4);
      if (index + 2 >= bytes.length) {
        continue;
      }

      blue += bytes[index];
      green += bytes[index + 1];
      red += bytes[index + 2];
      count++;
    }

    return _average(red: red, green: green, blue: blue, count: count);
  }

  static SampledColor sampleYuv420({
    required Uint8List yBytes,
    required Uint8List uBytes,
    required Uint8List vBytes,
    required int width,
    required int height,
    required int yBytesPerRow,
    required int uvBytesPerRow,
    required int uvBytesPerPixel,
  }) {
    var red = 0;
    var green = 0;
    var blue = 0;
    var count = 0;

    for (final point in _samplePoints(width, height)) {
      final yIndex = (point.y * yBytesPerRow) + point.x;
      final uvIndex =
          (point.y ~/ 2) * uvBytesPerRow + (point.x ~/ 2) * uvBytesPerPixel;

      if (yIndex >= yBytes.length ||
          uvIndex >= uBytes.length ||
          uvIndex >= vBytes.length) {
        continue;
      }

      final y = yBytes[yIndex];
      final u = uBytes[uvIndex] - 128;
      final v = vBytes[uvIndex] - 128;

      red += (y + 1.402 * v).round().clamp(0, 255);
      green += (y - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
      blue += (y + 1.772 * u).round().clamp(0, 255);
      count++;
    }

    return _average(red: red, green: green, blue: blue, count: count);
  }

  static Iterable<_SamplePoint> _samplePoints(int width, int height) sync* {
    final centerX = width ~/ 2;
    final centerY = height ~/ 2;
    final radius = gridSize ~/ 2;

    for (var y = centerY - radius; y <= centerY + radius; y++) {
      for (var x = centerX - radius; x <= centerX + radius; x++) {
        yield _SamplePoint(x: x.clamp(0, width - 1), y: y.clamp(0, height - 1));
      }
    }
  }

  static SampledColor _average({
    required int red,
    required int green,
    required int blue,
    required int count,
  }) {
    if (count == 0) {
      return SampledColor.black;
    }

    return SampledColor(
      red: (red / count).round(),
      green: (green / count).round(),
      blue: (blue / count).round(),
    );
  }
}

class _SamplePoint {
  const _SamplePoint({required this.x, required this.y});

  final int x;
  final int y;
}
