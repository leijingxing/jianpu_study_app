import '../models/local_score.dart';

/// 本地乐谱的应用层存储契约。
abstract interface class LocalScoreRepository {
  Future<List<LocalScore>> getAll();
  Future<LocalScore> save(JianpuMakerDraft draft, {String? existingId});
  Future<List<LocalScore>> delete(String id);
}
