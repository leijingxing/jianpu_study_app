import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 只负责本地乐谱 JSON 的 SharedPreferences 边界。
final class LocalScoreService {
  const LocalScoreService();

  static const storageKey = 'local_jianpu_scores_v1';

  Future<List<Map<String, dynamic>>> readAll() async {
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    return (jsonDecode(raw) as List)
        .whereType<Map>()
        .map((value) => value.cast<String, dynamic>())
        .toList(growable: false);
  }

  Future<void> writeAll(List<Map<String, dynamic>> values) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(storageKey, jsonEncode(values));
  }
}
