// ABOUTME: Defines saved swatch and color set models for the desktop app.
// ABOUTME: Handles JSON conversion for local persistence.
import 'dart:convert';

import 'package:flutter/material.dart';

class SampledColor {
  const SampledColor({
    required this.red,
    required this.green,
    required this.blue,
  });

  factory SampledColor.fromHex(String hex) {
    final normalized = hex.replaceFirst('#', '');
    if (normalized.length != 6) {
      throw FormatException('Expected a six digit color hex value.', hex);
    }

    return SampledColor(
      red: int.parse(normalized.substring(0, 2), radix: 16),
      green: int.parse(normalized.substring(2, 4), radix: 16),
      blue: int.parse(normalized.substring(4, 6), radix: 16),
    );
  }

  static const black = SampledColor(red: 0, green: 0, blue: 0);

  final int red;
  final int green;
  final int blue;

  Color get color => Color.fromRGBO(red, green, blue, 1);

  String get hex {
    final r = red.toRadixString(16).padLeft(2, '0');
    final g = green.toRadixString(16).padLeft(2, '0');
    final b = blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }
}

class SavedSwatch {
  const SavedSwatch({required this.color, required this.createdAt});

  factory SavedSwatch.now(SampledColor color) {
    return SavedSwatch(color: color, createdAt: DateTime.now().toUtc());
  }

  factory SavedSwatch.fromJson(Map<String, Object?> json) {
    return SavedSwatch(
      color: SampledColor.fromHex(json['hex'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final SampledColor color;
  final DateTime createdAt;

  Map<String, Object?> toJson() {
    return {'hex': color.hex, 'createdAt': createdAt.toIso8601String()};
  }
}

class ColorSet {
  const ColorSet({
    required this.name,
    required this.swatches,
    required this.createdAt,
  });

  factory ColorSet.fromJson(Map<String, Object?> json) {
    final swatchesJson = json['swatches'] as List<Object?>;
    return ColorSet(
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      swatches: swatchesJson
          .cast<Map<String, Object?>>()
          .map(SavedSwatch.fromJson)
          .toList(),
    );
  }

  final String name;
  final List<SavedSwatch> swatches;
  final DateTime createdAt;

  String encode() => jsonEncode(toJson());

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'swatches': swatches.map((swatch) => swatch.toJson()).toList(),
    };
  }
}
