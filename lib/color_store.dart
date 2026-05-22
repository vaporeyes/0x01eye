// ABOUTME: Persists saved swatches and named color sets for the app.
// ABOUTME: Stores compact JSON documents through shared preferences.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'color_workspace.dart';

class ColorStore {
  static const _swatchesKey = 'saved_swatches';
  static const _setsKey = 'saved_color_sets';

  Future<List<SavedSwatch>> loadSwatches() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences
            .getStringList(_swatchesKey)
            ?.map(_decodeSwatch)
            .toList() ??
        <SavedSwatch>[];
  }

  Future<List<ColorSet>> loadColorSets() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(_setsKey)?.map(_decodeColorSet).toList() ??
        <ColorSet>[];
  }

  Future<void> saveSwatches(List<SavedSwatch> swatches) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _swatchesKey,
      swatches.map((swatch) => jsonEncode(swatch.toJson())).toList(),
    );
  }

  Future<void> saveColorSets(List<ColorSet> colorSets) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _setsKey,
      colorSets.map((set) => set.encode()).toList(),
    );
  }

  SavedSwatch _decodeSwatch(String value) {
    return SavedSwatch.fromJson(jsonDecode(value) as Map<String, Object?>);
  }

  ColorSet _decodeColorSet(String value) {
    return ColorSet.fromJson(jsonDecode(value) as Map<String, Object?>);
  }
}
