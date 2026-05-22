// ABOUTME: Bridges desktop eye-dropper requests to native platform color APIs.
// ABOUTME: Normalizes picked desktop colors into app color model values.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'color_workspace.dart';

class DesktopColorPicker {
  static const MethodChannel _channel = MethodChannel(
    'eye_inspector/desktop_color',
  );

  Future<SampledColor?> pickColor() async {
    final hex = Platform.isMacOS
        ? await _invoke('pickColor')
        : await _sampleCursorAfterDelay();
    return _decodeHex(hex);
  }

  Future<SampledColor?> sampleCursorColor() async {
    final hex = await _invoke('sampleCursorColor');
    return _decodeHex(hex);
  }

  SampledColor? _decodeHex(String? hex) {
    if (hex == null || hex.isEmpty) {
      return null;
    }

    return SampledColor.fromHex(hex);
  }

  Future<String?> _sampleCursorAfterDelay() async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    return _invoke('sampleCursorColor');
  }

  Future<String?> _invoke(String method) async {
    try {
      return await _channel.invokeMethod<String>(method);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
