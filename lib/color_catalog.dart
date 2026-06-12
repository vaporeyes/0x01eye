// ABOUTME: Loads canonical color names and finds nearest matches for samples.
// ABOUTME: Uses the bundled CSV color list as the app's naming catalog.
import 'package:flutter/services.dart';

import 'color_workspace.dart';

class ColorCatalog {
  ColorCatalog._(this._entries);

  factory ColorCatalog.fromCsv(String csv) {
    final entries = <ColorCatalogEntry>[];
    final lines = csv.split(RegExp(r'\r?\n'));

    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) {
        continue;
      }

      final commaIndex = line.lastIndexOf(',');
      if (commaIndex <= 0 || commaIndex == line.length - 1) {
        continue;
      }

      final name = line.substring(0, commaIndex).trim();
      final color = SampledColor.fromHex(line.substring(commaIndex + 1).trim());
      entries.add(ColorCatalogEntry(name: name, color: color));
    }

    return ColorCatalog._(List.unmodifiable(entries));
  }

  static Future<ColorCatalog> load() async {
    final csv = await rootBundle.loadString('assets/colors.csv');
    return ColorCatalog.fromCsv(csv);
  }

  final List<ColorCatalogEntry> _entries;
  final Map<String, String> _nearestNameCache = {};

  String nearestName(SampledColor color) {
    return _nearestNameCache.putIfAbsent(color.hex, () {
      var bestName = 'unknown';
      var bestDistance = 1 << 62;

      for (final entry in _entries) {
        final distance = _distance(color, entry.color);
        if (distance < bestDistance) {
          bestName = entry.name;
          bestDistance = distance;
        }
      }

      return bestName;
    });
  }

  static int _distance(SampledColor left, SampledColor right) {
    final red = left.red - right.red;
    final green = left.green - right.green;
    final blue = left.blue - right.blue;
    return red * red + green * green + blue * blue;
  }
}

class ColorCatalogEntry {
  const ColorCatalogEntry({required this.name, required this.color});

  final String name;
  final SampledColor color;
}
