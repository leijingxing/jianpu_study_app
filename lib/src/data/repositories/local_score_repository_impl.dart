import '../../core/error/failure.dart';
import '../../domain/models/local_score.dart';
import '../../domain/repositories/local_score_repository.dart';
import '../mappers/local_score_mapper.dart';
import '../services/local/local_score_service.dart';

final class LocalScoreRepositoryImpl implements LocalScoreRepository {
  LocalScoreRepositoryImpl(this._service);

  final LocalScoreService _service;
  final _items = <String, LocalScore>{};
  var _loaded = false;

  @override
  Future<List<LocalScore>> getAll() async {
    try {
      if (!_loaded) {
        final values = await _service.readAll();
        _items
          ..clear()
          ..addEntries(
            values
                .map(LocalScoreMapper.fromJson)
                .where((item) => item.id.isNotEmpty)
                .map((item) => MapEntry(item.id, item)),
          );
        _loaded = true;
      }
      return _sorted();
    } catch (error) {
      throw StorageFailure('本地乐谱读取失败。', cause: error);
    }
  }

  @override
  Future<LocalScore> save(JianpuMakerDraft draft, {String? existingId}) async {
    await getAll();
    final now = DateTime.now();
    final id = existingId?.trim().isNotEmpty == true
        ? existingId!.trim()
        : 'local_${now.microsecondsSinceEpoch}';
    final current = _items[id];
    final value = LocalScore(
      id: id,
      draft: draft,
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );
    _items[id] = value;
    await _persist();
    return value;
  }

  @override
  Future<List<LocalScore>> delete(String id) async {
    await getAll();
    _items.remove(id);
    await _persist();
    return _sorted();
  }

  List<LocalScore> _sorted() {
    final values = _items.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(values);
  }

  Future<void> _persist() =>
      _service.writeAll(_sorted().map(LocalScoreMapper.toJson).toList());
}
