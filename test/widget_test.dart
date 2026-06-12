// ABOUTME: Verifies the camera frame color sampling math without hardware.
// ABOUTME: Covers BGRA and YUV frame layouts used by supported platforms.
import 'dart:typed_data';

import 'package:eye_inspector/color_catalog.dart';
import 'package:eye_inspector/color_sampler.dart';
import 'package:eye_inspector/color_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats sampled colors as uppercase hex', () {
    const sample = SampledColor(red: 10, green: 27, blue: 255);

    expect(sample.hex, '#0A1BFF');
  });

  test('formats derived color outputs', () {
    const sample = SampledColor(red: 255, green: 0, blue: 0);

    expect(sample.rgbLabel, '255 0 0');
    expect(sample.hslLabel, '0 100% 50%');
    expect(sample.hsvLabel, '0 100% 100%');
    expect(sample.luminanceLabel, '21%');
  });

  test('finds nearest canonical color names', () {
    final catalog = ColorCatalog.fromCsv(
      'name,hex\nblack,#000000\nred,#ff0000',
    );

    expect(
      catalog.nearestName(const SampledColor(red: 250, green: 2, blue: 3)),
      'red',
    );
    expect(
      catalog.nearestName(const SampledColor(red: 1, green: 2, blue: 3)),
      'black',
    );
  });

  test('averages BGRA pixels around the frame center', () {
    const width = 11;
    const height = 11;
    final bytes = Uint8List(width * height * 4);

    for (var i = 0; i < bytes.length; i += 4) {
      bytes[i] = 10;
      bytes[i + 1] = 20;
      bytes[i + 2] = 30;
      bytes[i + 3] = 255;
    }

    final sample = ColorSampler.sampleBgra(
      bytes: bytes,
      width: width,
      height: height,
      bytesPerRow: width * 4,
    );

    expect(sample.red, 30);
    expect(sample.green, 20);
    expect(sample.blue, 10);
  });

  test('converts neutral YUV values to gray RGB', () {
    const width = 12;
    const height = 12;
    final yBytes = Uint8List(width * height)..fillRange(0, width * height, 90);
    final uBytes = Uint8List((width ~/ 2) * (height ~/ 2))
      ..fillRange(0, (width ~/ 2) * (height ~/ 2), 128);
    final vBytes = Uint8List((width ~/ 2) * (height ~/ 2))
      ..fillRange(0, (width ~/ 2) * (height ~/ 2), 128);

    final sample = ColorSampler.sampleYuv420(
      yBytes: yBytes,
      uBytes: uBytes,
      vBytes: vBytes,
      width: width,
      height: height,
      yBytesPerRow: width,
      uvBytesPerRow: width ~/ 2,
      uvBytesPerPixel: 1,
    );

    expect(sample.red, 90);
    expect(sample.green, 90);
    expect(sample.blue, 90);
  });
}
