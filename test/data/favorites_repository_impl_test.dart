import 'package:flutter_test/flutter_test.dart';
import 'package:jianpu_study_app/src/data/favorites_store.dart';
import 'package:jianpu_study_app/src/data/repositories/favorites_repository_impl.dart';
import 'package:jianpu_study_app/src/domain/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'restores Yuepu dynamic metadata needed by favorite navigation',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = FavoritesStore();
      final repository = FavoritesRepositoryImpl(store);
      const score = MusicSummary(
        id: 0,
        title: '悦谱测试',
        singer: '演唱者',
        arranger: '编曲者',
        times: 12,
        level: 3,
        source: ResourceSource.yuepu,
        externalId: 'resource-7',
        category: '流行',
        previewVideoUrl: 'https://example.com/preview.mp4',
        tracks: [
          AudioTrackItem(
            id: 'track-1',
            name: '伴奏',
            mp3Url: 'https://example.com/track.mp3',
          ),
        ],
      );

      final items = await repository.toggleDynamicScore(score);
      final target = repository.resolve(items.single);

      expect(target, isA<DynamicFavoriteTarget>());
      final restored = (target as DynamicFavoriteTarget).score;
      expect(restored.externalId, 'resource-7');
      expect(restored.previewVideoUrl, score.previewVideoUrl);
      expect(restored.tracks.single.mp3Url, score.tracks.single.mp3Url);
    },
  );
}
