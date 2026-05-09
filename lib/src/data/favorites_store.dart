import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class FavoritesStore extends ChangeNotifier {
  static const _storageKey = 'favorite_scores_v1';
  final Map<String, FavoriteItem> _items = {};

  List<FavoriteItem> get items => _items.values.toList().reversed.toList();

  bool contains(ScoreKind kind, String id) =>
      _items.containsKey('${kind.name}:$id');

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw) as List;
    _items
      ..clear()
      ..addEntries(
        decoded
            .whereType<Map>()
            .map((item) => FavoriteItem.fromJson(item.cast<String, dynamic>()))
            .map((item) => MapEntry(item.key, item)),
      );
    notifyListeners();
  }

  Future<void> toggle(FavoriteItem item) async {
    if (_items.containsKey(item.key)) {
      _items.remove(item.key);
    } else {
      _items[item.key] = item;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_items.values.map((item) => item.toJson()).toList()),
    );
  }
}
