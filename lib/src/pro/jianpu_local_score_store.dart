import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jianpu_maker_model.dart';

class LocalJianpuScore {
  const LocalJianpuScore({
    required this.id,
    required this.draft,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final JianpuMakerDraft draft;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get title => draft.title.trim().isEmpty ? '未命名简谱' : draft.title;

  String get subtitle {
    final parts = [
      if (draft.keyName.trim().isNotEmpty) '1=${draft.keyName}',
      draft.timeSignature,
      '${draft.bpm} BPM',
    ];
    return parts.join(' · ');
  }

  LocalJianpuScore copyWith({JianpuMakerDraft? draft, DateTime? updatedAt}) {
    return LocalJianpuScore(
      id: id,
      draft: draft ?? this.draft,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'draft': draft.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LocalJianpuScore.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return LocalJianpuScore(
      id: (json['id'] ?? '').toString(),
      draft: JianpuMakerDraft.fromJson(
        (json['draft'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? now,
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ?? now,
    );
  }
}

class JianpuLocalScoreStore extends ChangeNotifier {
  static const _storageKey = 'local_jianpu_scores_v1';

  final Map<String, LocalJianpuScore> _items = {};

  List<LocalJianpuScore> get items {
    final result = _items.values.toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

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
            .map(
              (item) => LocalJianpuScore.fromJson(item.cast<String, dynamic>()),
            )
            .where((item) => item.id.isNotEmpty)
            .map((item) => MapEntry(item.id, item)),
      );
    notifyListeners();
  }

  Future<LocalJianpuScore> saveDraft({
    required JianpuMakerDraft draft,
    String? existingId,
  }) async {
    final now = DateTime.now();
    final id = existingId?.trim().isNotEmpty == true
        ? existingId!.trim()
        : 'local_${now.microsecondsSinceEpoch}';
    final current = _items[id];
    final item = current == null
        ? LocalJianpuScore(id: id, draft: draft, createdAt: now, updatedAt: now)
        : current.copyWith(draft: draft, updatedAt: now);
    _items[id] = item;
    await _persist();
    notifyListeners();
    return item;
  }

  Future<void> delete(String id) async {
    if (!_items.containsKey(id)) return;
    _items.remove(id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }
}
