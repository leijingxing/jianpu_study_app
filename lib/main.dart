import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const JianpuStudyApp());
}

const _brand = Color(0xFF5EA9A3);
const _ink = Color(0xFF17212B);
const _paper = Color(0xFFF7F8F5);
const _accent = Color(0xFFE97D5F);

class JianpuStudyApp extends StatelessWidget {
  const JianpuStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '简谱学习',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _brand,
          primary: _brand,
          secondary: _accent,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: _paper,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: _paper,
          foregroundColor: _ink,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

enum ScoreKind { dynamic, image }

class MusicSummary {
  MusicSummary({
    required this.id,
    required this.title,
    required this.singer,
    required this.arranger,
    required this.times,
    required this.level,
  });

  final int id;
  final String title;
  final String singer;
  final String arranger;
  final int times;
  final int level;

  String get subtitle {
    final names = [
      if (singer.trim().isNotEmpty && singer != 'null') singer,
      if (arranger.trim().isNotEmpty && arranger != 'null') '编: $arranger',
    ];
    return names.isEmpty ? '动态简谱' : names.join(' · ');
  }

  factory MusicSummary.fromJson(Map<String, dynamic> json) {
    return MusicSummary(
      id: _asInt(json['id']),
      title: _clean(json['song_name']),
      singer: _clean(json['singer']),
      arranger: _clean(json['arranger']),
      times: _asInt(json['times']),
      level: _asInt(json['deerjs']),
    );
  }
}

class MusicDetail {
  MusicDetail({
    required this.id,
    required this.title,
    required this.originalKey,
    required this.selectedKey,
    required this.timeSignature,
    required this.bpm,
    required this.singer,
    required this.arranger,
    required this.composer,
    required this.lyricist,
    required this.scorePath,
    required this.coverPath,
    required this.times,
  });

  final int id;
  final String title;
  final String originalKey;
  final String selectedKey;
  final String timeSignature;
  final int bpm;
  final String singer;
  final String arranger;
  final String composer;
  final String lyricist;
  final String scorePath;
  final String coverPath;
  final int times;

  factory MusicDetail.fromJson(Map<String, dynamic> json) {
    return MusicDetail(
      id: _asInt(json['id']),
      title: _clean(json['song_name']),
      originalKey: _clean(json['o_signature']),
      selectedKey: _clean(json['key_signature']),
      timeSignature: _clean(json['time_signature']),
      bpm: _asInt(json['beats_per_minute']),
      singer: _clean(json['singer']),
      arranger: _clean(json['arranger']),
      composer: _clean(json['composer']),
      lyricist: _clean(json['lyricist']),
      scorePath: _clean(json['xml_filename']),
      coverPath: _clean(json['cover_img']),
      times: _asInt(json['times']),
    );
  }
}

class ImageScoreItem {
  ImageScoreItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.pic,
    required this.views,
    required this.hasVideo,
    required this.date,
  });

  final String id;
  final String title;
  final String summary;
  final String pic;
  final int views;
  final bool hasVideo;
  final String date;

  String get imageUrl {
    if (pic.isEmpty) return '';
    if (pic.startsWith('http')) return pic;
    return 'http://www.jita666.com/$pic';
  }

  factory ImageScoreItem.fromJson(Map<String, dynamic> json) {
    return ImageScoreItem(
      id: _clean(json['aid']),
      title: _clean(json['title']),
      summary: _clean(json['summary']),
      pic: _clean(json['pic']),
      views: _asInt(json['viewnum']),
      hasVideo: _asInt(json['hasmp4']) == 1,
      date: _clean(json['dateline']),
    );
  }
}

class FavoriteItem {
  FavoriteItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.subtitle,
    this.scorePath = '',
    this.imageUrl = '',
  });

  final ScoreKind kind;
  final String id;
  final String title;
  final String subtitle;
  final String scorePath;
  final String imageUrl;

  String get key => '${kind.name}:$id';

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'scorePath': scorePath,
    'imageUrl': imageUrl,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      kind: json['kind'] == ScoreKind.image.name
          ? ScoreKind.image
          : ScoreKind.dynamic,
      id: _clean(json['id']),
      title: _clean(json['title']),
      subtitle: _clean(json['subtitle']),
      scorePath: _clean(json['scorePath']),
      imageUrl: _clean(json['imageUrl']),
    );
  }
}

class ScoreDocument {
  ScoreDocument({
    required this.title,
    required this.composer,
    required this.lyricist,
    required this.notation,
    required this.lyrics,
  });

  final String title;
  final String composer;
  final String lyricist;
  final List<String> notation;
  final List<String> lyrics;

  factory ScoreDocument.parse(String raw) {
    var title = '';
    var composer = '';
    var lyricist = '';
    final notationLines = <String>[];
    final lyricChars = <String>[];

    for (final sourceLine in const LineSplitter().convert(raw)) {
      final line = sourceLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('title:')) {
        title = line.substring(6).trim();
      } else if (line.startsWith('composer:')) {
        composer = line.substring(9).trim();
      } else if (line.startsWith('lyricist:')) {
        lyricist = line.substring(9).trim();
      } else if (line.startsWith('lyrics:')) {
        final text = line.substring(7).trim();
        lyricChars.addAll(_extractLyricUnits(text));
      } else if (RegExp(r'[0-7]').hasMatch(line)) {
        notationLines.add(line);
      }
    }

    return ScoreDocument(
      title: title,
      composer: composer,
      lyricist: lyricist,
      notation: notationLines,
      lyrics: lyricChars,
    );
  }
}

class JianpuApi {
  JianpuApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _musicBase = 'http://guji666.com';
  static const _forumBase = 'http://www.jita666.com';

  Future<List<MusicSummary>> fetchDynamicList({
    int page = 1,
    int limit = 30,
  }) async {
    final uri = Uri.parse(
      '$_musicBase/home/music/collect_sort',
    ).replace(queryParameters: {'limit': '$limit', 'page': '$page'});
    final json = await _getJson(uri);
    final list = (json['data']?['data'] as List? ?? const []);
    return list
        .whereType<Map>()
        .map((item) => MusicSummary.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<MusicSummary>> searchDynamic(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return fetchDynamicList();
    final pages = await Future.wait([
      for (var page = 1; page <= 8; page++)
        fetchDynamicList(page: page, limit: 50),
    ]);
    final all = pages.expand((page) => page).toList();
    return all.where((song) {
      return '${song.title} ${song.singer} ${song.arranger}'
          .toLowerCase()
          .contains(normalized);
    }).toList();
  }

  Future<MusicDetail> fetchDynamicDetail(int id) async {
    final uri = Uri.parse(
      '$_musicBase/home/music/detail',
    ).replace(queryParameters: {'id': '$id'});
    final json = await _getJson(uri);
    return MusicDetail.fromJson(
      (json['data'] as Map? ?? const {}).cast<String, dynamic>(),
    );
  }

  Future<String> fetchScoreText(String path) async {
    final normalized = path.startsWith('http') ? path : '$_musicBase$path';
    final response = await _client.get(Uri.parse(normalized));
    if (response.statusCode != 200) {
      throw Exception('谱面加载失败: ${response.statusCode}');
    }
    return utf8.decode(response.bodyBytes);
  }

  Future<List<ImageScoreItem>> fetchImageList({
    int page = 1,
    String orderBy = 'viewnum',
  }) async {
    final uri = Uri.parse('$_forumBase/plugin.php').replace(
      queryParameters: {
        'id': 'jnpar_discuzapi',
        'apiid': '4',
        'orderby': orderBy,
        'ascdesc': 'desc',
        'page': '$page',
        'catid': '19',
      },
    );
    final json = await _getJson(uri);
    final list = (json['lists'] as List? ?? const []);
    return list
        .whereType<Map>()
        .map((item) => ImageScoreItem.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<ImageScoreItem>> searchImages(String query) async {
    final normalized = query.trim().toLowerCase();
    final pages = await Future.wait([
      for (var page = 1; page <= 5; page++) fetchImageList(page: page),
    ]);
    final all = pages.expand((page) => page).toList();
    if (normalized.isEmpty) return all;
    return all.where((item) {
      return '${item.title} ${item.summary}'.toLowerCase().contains(normalized);
    }).toList();
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('接口请求失败: ${response.statusCode}');
    }
    final text = utf8.decode(response.bodyBytes);
    return (jsonDecode(text) as Map).cast<String, dynamic>();
  }
}

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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _api = JianpuApi();
  final _favorites = FavoritesStore();
  final _searchController = TextEditingController();
  var _tab = 0;
  var _query = '';
  var _dynamicPage = 1;
  var _imagePage = 1;
  var _dynamicSongs = <MusicSummary>[];
  var _imageScores = <ImageScoreItem>[];
  var _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _favorites.load();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _favorites.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = true}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _dynamicPage = 1;
        _imagePage = 1;
      }
    });

    try {
      if (_tab == 0) {
        _dynamicSongs = _query.trim().isEmpty
            ? await _api.fetchDynamicList(page: _dynamicPage)
            : await _api.searchDynamic(_query);
      } else if (_tab == 1) {
        _imageScores = _query.trim().isEmpty
            ? await _api.fetchImageList(page: _imagePage)
            : await _api.searchImages(_query);
      }
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_query.trim().isNotEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      if (_tab == 0) {
        _dynamicPage++;
        _dynamicSongs.addAll(await _api.fetchDynamicList(page: _dynamicPage));
      } else if (_tab == 1) {
        _imagePage++;
        _imageScores.addAll(await _api.fetchImageList(page: _imagePage));
      }
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _favorites,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _HomeHeader(
                  controller: _searchController,
                  tab: _tab,
                  onTabChanged: (index) {
                    setState(() {
                      _tab = index;
                      _query = '';
                      _searchController.clear();
                    });
                    _load();
                  },
                  onSearch: (value) {
                    _query = value;
                    _load();
                  },
                ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_tab == 2) return _buildFavorites();
    if (_error != null && (_dynamicSongs.isEmpty && _imageScores.isEmpty)) {
      return _StateView(
        icon: Icons.wifi_off_rounded,
        title: '接口暂时不可用',
        message: '$_error',
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      );
    }

    if (_loading && (_dynamicSongs.isEmpty && _imageScores.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tab == 0) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _dynamicSongs.length + 1,
          itemBuilder: (context, index) {
            if (index == _dynamicSongs.length) {
              return _LoadMoreButton(loading: _loading, onPressed: _loadMore);
            }
            final song = _dynamicSongs[index];
            final favorite = _favorites.contains(
              ScoreKind.dynamic,
              '${song.id}',
            );
            return _MusicCard(
              title: song.title,
              subtitle: song.subtitle,
              metric: '${song.times} 次练习',
              badge: 'Lv.${song.level}',
              favorite: favorite,
              onFavorite: () => _favorites.toggle(
                FavoriteItem(
                  kind: ScoreKind.dynamic,
                  id: '${song.id}',
                  title: song.title,
                  subtitle: song.subtitle,
                ),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DynamicDetailPage(
                    api: _api,
                    song: song,
                    favorites: _favorites,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _imageScores.length + 1,
        itemBuilder: (context, index) {
          if (index == _imageScores.length) {
            return _LoadMoreButton(loading: _loading, onPressed: _loadMore);
          }
          final item = _imageScores[index];
          final favorite = _favorites.contains(ScoreKind.image, item.id);
          return _MusicCard(
            title: item.title,
            subtitle: item.summary.isEmpty ? item.date : item.summary,
            metric: '${item.views} 浏览',
            badge: item.hasVideo ? '视频' : '图片',
            favorite: favorite,
            imageUrl: item.imageUrl,
            onFavorite: () => _favorites.toggle(
              FavoriteItem(
                kind: ScoreKind.image,
                id: item.id,
                title: item.title,
                subtitle: item.summary,
                imageUrl: item.imageUrl,
              ),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ImageDetailPage(item: item, favorites: _favorites),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFavorites() {
    final items = _favorites.items;
    if (items.isEmpty) {
      return const _StateView(
        icon: Icons.bookmark_add_outlined,
        title: '还没有收藏',
        message: '喜欢的动态谱和图片谱都会放在这里。',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _MusicCard(
          title: item.title,
          subtitle: item.subtitle.isEmpty
              ? (item.kind == ScoreKind.dynamic ? '动态简谱' : '图片简谱')
              : item.subtitle,
          metric: item.kind == ScoreKind.dynamic ? '动态简谱' : '图片简谱',
          badge: '已收藏',
          favorite: true,
          imageUrl: item.imageUrl,
          onFavorite: () => _favorites.toggle(item),
          onTap: () {
            if (item.kind == ScoreKind.dynamic) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DynamicDetailPage(
                    api: _api,
                    song: MusicSummary(
                      id: int.tryParse(item.id) ?? 0,
                      title: item.title,
                      singer: '',
                      arranger: '',
                      times: 0,
                      level: 0,
                    ),
                    favorites: _favorites,
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.controller,
    required this.tab,
    required this.onTabChanged,
    required this.onSearch,
  });

  final TextEditingController controller;
  final int tab;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '简谱学习',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '动态谱 · 图片谱 · 本地收藏',
                      style: TextStyle(color: Color(0xFF69737B), fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: onSearch,
            decoration: InputDecoration(
              hintText: tab == 1 ? '搜索图片谱标题' : '搜索歌名、歌手、编配',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onSearch('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.graphic_eq_rounded),
                label: Text('动态谱'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.image_outlined),
                label: Text('图片谱'),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.bookmark_border_rounded),
                label: Text('收藏'),
              ),
            ],
            selected: {tab},
            onSelectionChanged: (value) => onTabChanged(value.first),
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard({
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.badge,
    required this.favorite,
    required this.onTap,
    required this.onFavorite,
    this.imageUrl = '',
  });

  final String title;
  final String subtitle;
  final String metric;
  final String badge;
  final bool favorite;
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _CoverThumb(title: title, imageUrl: imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF69737B),
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Pill(label: badge, color: _brand),
                        _Pill(label: metric, color: const Color(0xFF7C6E5E)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: favorite ? '取消收藏' : '收藏',
                onPressed: onFavorite,
                icon: Icon(
                  favorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: favorite ? _accent : const Color(0xFF8B969C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.title, this.imageUrl = ''});

  final String title;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 62,
        height: 72,
        color: const Color(0xFFE9F0EC),
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final letter = title.characters.isEmpty ? '谱' : title.characters.first;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: _brand.withValues(alpha: 0.18)),
        Center(
          child: Text(
            letter,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: _brand,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                label: const Text('加载更多'),
              ),
      ),
    );
  }
}

class DynamicDetailPage extends StatefulWidget {
  const DynamicDetailPage({
    super.key,
    required this.api,
    required this.song,
    required this.favorites,
  });

  final JianpuApi api;
  final MusicSummary song;
  final FavoritesStore favorites;

  @override
  State<DynamicDetailPage> createState() => _DynamicDetailPageState();
}

class _DynamicDetailPageState extends State<DynamicDetailPage> {
  final _scrollController = ScrollController();
  Timer? _scrollTimer;
  MusicDetail? _detail;
  ScoreDocument? _document;
  Object? _error;
  var _loading = true;
  var _zoom = 1.0;
  var _playing = false;
  var _speed = 1.0;

  @override
  void initState() {
    super.initState();
    widget.favorites.addListener(_onFavoriteChanged);
    _load();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    widget.favorites.removeListener(_onFavoriteChanged);
    super.dispose();
  }

  void _onFavoriteChanged() => setState(() {});

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.api.fetchDynamicDetail(widget.song.id);
      final text = await widget.api.fetchScoreText(detail.scorePath);
      _detail = detail;
      _document = ScoreDocument.parse(text);
    } catch (error) {
      _error = error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _togglePlay() {
    setState(() => _playing = !_playing);
    _scrollTimer?.cancel();
    if (!_playing) return;
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 48), (_) {
      if (!_scrollController.hasClients) return;
      final next = math.min(
        _scrollController.position.maxScrollExtent,
        _scrollController.offset + _speed,
      );
      _scrollController.jumpTo(next);
      if (next >= _scrollController.position.maxScrollExtent) {
        _scrollTimer?.cancel();
        if (mounted) setState(() => _playing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final favorite = widget.favorites.contains(
      ScoreKind.dynamic,
      '${widget.song.id}',
    );
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        title: Text(
          widget.song.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '缩小',
            onPressed: () =>
                setState(() => _zoom = math.max(0.72, _zoom - 0.08)),
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          IconButton(
            tooltip: _playing ? '暂停滚动' : '自动滚动',
            onPressed: _togglePlay,
            icon: Icon(
              _playing ? Icons.pause_circle_outline : Icons.play_circle_outline,
            ),
          ),
          IconButton(
            tooltip: '放大',
            onPressed: () =>
                setState(() => _zoom = math.min(1.65, _zoom + 0.08)),
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          IconButton(
            tooltip: favorite ? '取消收藏' : '收藏',
            onPressed: detail == null
                ? null
                : () => widget.favorites.toggle(
                    FavoriteItem(
                      kind: ScoreKind.dynamic,
                      id: '${detail.id}',
                      title: detail.title,
                      subtitle: [
                        if (detail.singer.isNotEmpty) detail.singer,
                        if (detail.arranger.isNotEmpty) '编: ${detail.arranger}',
                      ].join(' · '),
                      scorePath: detail.scorePath,
                    ),
                  ),
            icon: Icon(
              favorite ? Icons.bookmark_rounded : Icons.bookmark_border,
            ),
          ),
        ],
      ),
      body: _buildDetailBody(),
    );
  }

  Widget _buildDetailBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _StateView(
        icon: Icons.error_outline_rounded,
        title: '谱面加载失败',
        message: '$_error',
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      );
    }

    final detail = _detail!;
    final document = _document!;
    return Column(
      children: [
        _ScoreMetaPanel(
          detail: detail,
          speed: _speed,
          onSpeedChanged: (value) => setState(() => _speed = value),
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 36),
              child: InteractiveViewer(
                minScale: 0.75,
                maxScale: 2.2,
                boundaryMargin: const EdgeInsets.all(80),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: JianpuScoreView(
                    document: document,
                    detail: detail,
                    zoom: _zoom,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreMetaPanel extends StatelessWidget {
  const _ScoreMetaPanel({
    required this.detail,
    required this.speed,
    required this.onSpeedChanged,
  });

  final MusicDetail detail;
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7FBFA),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetaLine(label: '节奏', value: detail.timeSignature),
              ),
              Expanded(
                child: _MetaLine(label: '速度', value: '${detail.bpm}'),
              ),
              Expanded(
                child: _MetaLine(label: '原调', value: detail.originalKey),
              ),
              Expanded(
                child: _MetaLine(label: '选调', value: detail.selectedKey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.speed_rounded,
                size: 18,
                color: Color(0xFF69737B),
              ),
              Expanded(
                child: Slider(
                  min: 0.4,
                  max: 3,
                  divisions: 13,
                  value: speed,
                  label: speed.toStringAsFixed(1),
                  onChanged: onSpeedChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label ',
        style: const TextStyle(color: Color(0xFF69737B), fontSize: 12),
        children: [
          TextSpan(
            text: value.isEmpty ? '-' : value,
            style: const TextStyle(
              color: _brand,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class JianpuScoreView extends StatelessWidget {
  const JianpuScoreView({
    super.key,
    required this.document,
    required this.detail,
    required this.zoom,
  });

  final ScoreDocument document;
  final MusicDetail detail;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final width = math.max(360.0, MediaQuery.sizeOf(context).width - 24);
    final layout = _ScoreLayout.from(document, width / zoom);
    return CustomPaint(
      size: Size(width, layout.height * zoom),
      painter: _JianpuPainter(
        document: document,
        detail: detail,
        layout: layout,
        zoom: zoom,
      ),
    );
  }
}

class _ScoreToken {
  _ScoreToken({required this.text, required this.bar});

  final String text;
  final bool bar;
}

class _ScoreRow {
  _ScoreRow(this.tokens, this.lyrics);

  final List<_ScoreToken> tokens;
  final List<String> lyrics;
}

class _ScoreLayout {
  _ScoreLayout({required this.rows, required this.width, required this.height});

  final List<_ScoreRow> rows;
  final double width;
  final double height;

  factory _ScoreLayout.from(ScoreDocument document, double width) {
    final tokens = <_ScoreToken>[];
    for (final line in document.notation) {
      final matches = RegExp(r'\||[^\s|]+').allMatches(line);
      for (final match in matches) {
        final raw = match.group(0)!.trim();
        if (raw.isEmpty) continue;
        tokens.add(_ScoreToken(text: raw, bar: raw == '|'));
      }
    }

    final usableWidth = math.max(320.0, width - 32);
    final estimatedTokenWidth = 48.0;
    final tokensPerRow = math.max(
      7,
      (usableWidth / estimatedTokenWidth).floor(),
    );
    final rows = <_ScoreRow>[];
    var lyricIndex = 0;

    for (var index = 0; index < tokens.length;) {
      final rowTokens = <_ScoreToken>[];
      var noteCount = 0;
      while (index < tokens.length && noteCount < tokensPerRow) {
        final token = tokens[index++];
        rowTokens.add(token);
        if (!token.bar) noteCount++;
        if (noteCount >= tokensPerRow && token.bar) break;
      }

      final rowLyrics = <String>[];
      for (final token in rowTokens) {
        if (token.bar) continue;
        rowLyrics.add(
          lyricIndex < document.lyrics.length
              ? document.lyrics[lyricIndex++]
              : '',
        );
      }
      rows.add(_ScoreRow(rowTokens, rowLyrics));
    }

    final height = 136.0 + rows.length * 92.0;
    return _ScoreLayout(rows: rows, width: width, height: height);
  }
}

class _JianpuPainter extends CustomPainter {
  _JianpuPainter({
    required this.document,
    required this.detail,
    required this.layout,
    required this.zoom,
  });

  final ScoreDocument document;
  final MusicDetail detail;
  final _ScoreLayout layout;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(zoom);
    final width = size.width / zoom;
    final black = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    _drawHeader(canvas, width);

    var y = 132.0;
    for (final row in layout.rows) {
      _drawRow(canvas, row, y, width, black);
      y += 92;
    }
    canvas.restore();
  }

  void _drawHeader(Canvas canvas, double width) {
    _paintText(
      canvas,
      detail.title.isNotEmpty ? detail.title : document.title,
      Offset(width / 2, 22),
      fontSize: 28,
      weight: FontWeight.w800,
      align: TextAlign.center,
      anchor: _Anchor.topCenter,
    );
    _paintText(
      canvas,
      '歌手:${detail.singer.isEmpty ? '-' : detail.singer}',
      Offset(width - 16, 30),
      fontSize: 15,
      weight: FontWeight.w700,
      align: TextAlign.right,
      anchor: _Anchor.topRight,
    );
    _paintText(
      canvas,
      '曲:${detail.composer.isEmpty ? document.composer : detail.composer}',
      Offset(width - 16, 64),
      fontSize: 15,
      weight: FontWeight.w700,
      align: TextAlign.right,
      anchor: _Anchor.topRight,
    );
    _paintText(
      canvas,
      '词:${detail.lyricist.isEmpty ? document.lyricist : detail.lyricist}',
      Offset(width - 16, 92),
      fontSize: 15,
      weight: FontWeight.w700,
      align: TextAlign.right,
      anchor: _Anchor.topRight,
    );
    _paintText(
      canvas,
      '节奏:${detail.timeSignature}',
      const Offset(16, 52),
      fontSize: 17,
      weight: FontWeight.w700,
    );
    _paintText(
      canvas,
      '速度:${detail.bpm}',
      const Offset(16, 84),
      fontSize: 17,
      weight: FontWeight.w700,
    );
    _paintText(
      canvas,
      '原调:${detail.originalKey}  选调:${detail.selectedKey}',
      const Offset(122, 68),
      fontSize: 15,
      color: _brand,
      weight: FontWeight.w800,
    );
  }

  void _drawRow(
    Canvas canvas,
    _ScoreRow row,
    double y,
    double width,
    Paint linePaint,
  ) {
    final notes = row.tokens.where((token) => !token.bar).length;
    final step = (width - 32) / math.max(notes + 0.5, 1);
    var x = 16.0;
    var lyricIndex = 0;
    Offset? slurStart;

    for (final token in row.tokens) {
      if (token.bar) {
        canvas.drawLine(Offset(x - 6, y + 4), Offset(x - 6, y + 42), linePaint);
        continue;
      }

      final display = _displayNote(token.text);
      final isSlurStart = token.text.startsWith('(');
      final isSlurEnd = token.text.endsWith(')');
      if (isSlurStart) slurStart = Offset(x, y - 8);

      _paintText(
        canvas,
        display,
        Offset(x, y),
        fontSize: 26,
        weight: FontWeight.w800,
        anchor: _Anchor.topCenter,
        align: TextAlign.center,
      );

      if (token.text.contains('_') || token.text.contains('=')) {
        canvas.drawLine(
          Offset(x - 14, y + 40),
          Offset(x + 18, y + 40),
          linePaint..strokeWidth = token.text.contains('=') ? 1.5 : 2.2,
        );
      }
      if (token.text.contains('.')) {
        canvas.drawCircle(
          Offset(x, y + 52),
          2.6,
          Paint()..color = Colors.black,
        );
      }
      if (isSlurEnd && slurStart != null) {
        final path = Path()
          ..moveTo(slurStart.dx - 8, slurStart.dy + 8)
          ..quadraticBezierTo((slurStart.dx + x) / 2, y - 28, x + 8, y);
        canvas.drawPath(path, linePaint..strokeWidth = 1.8);
        slurStart = null;
      }

      final lyric = lyricIndex < row.lyrics.length
          ? row.lyrics[lyricIndex]
          : '';
      if (lyric.isNotEmpty) {
        _paintText(
          canvas,
          lyric,
          Offset(x, y + 54),
          fontSize: 20,
          weight: FontWeight.w700,
          anchor: _Anchor.topCenter,
          align: TextAlign.center,
        );
      }

      lyricIndex++;
      x += step;
    }
  }

  String _displayNote(String raw) {
    return raw
        .replaceAll(RegExp(r'[()_=]'), '')
        .replaceAll(',', '̣')
        .replaceAll("'", '̇')
        .trim();
  }

  @override
  bool shouldRepaint(covariant _JianpuPainter oldDelegate) {
    return oldDelegate.document != document ||
        oldDelegate.detail != detail ||
        oldDelegate.zoom != zoom;
  }
}

enum _Anchor { topLeft, topCenter, topRight }

void _paintText(
  Canvas canvas,
  String text,
  Offset offset, {
  double fontSize = 14,
  Color color = Colors.black,
  FontWeight weight = FontWeight.normal,
  TextAlign align = TextAlign.left,
  _Anchor anchor = _Anchor.topLeft,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        height: 1.1,
      ),
    ),
    textAlign: align,
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout(maxWidth: 420);
  final dx = switch (anchor) {
    _Anchor.topLeft => offset.dx,
    _Anchor.topCenter => offset.dx - painter.width / 2,
    _Anchor.topRight => offset.dx - painter.width,
  };
  painter.paint(canvas, Offset(dx, offset.dy));
}

class ImageDetailPage extends StatelessWidget {
  const ImageDetailPage({
    super.key,
    required this.item,
    required this.favorites,
  });

  final ImageScoreItem item;
  final FavoritesStore favorites;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: favorites,
      builder: (context, _) {
        final favorite = favorites.contains(ScoreKind.image, item.id);
        return Scaffold(
          appBar: AppBar(
            title: Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: favorite ? '取消收藏' : '收藏',
                onPressed: () => favorites.toggle(
                  FavoriteItem(
                    kind: ScoreKind.image,
                    id: item.id,
                    title: item.title,
                    subtitle: item.summary,
                    imageUrl: item.imageUrl,
                  ),
                ),
                icon: Icon(
                  favorite ? Icons.bookmark_rounded : Icons.bookmark_border,
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.summary.isEmpty ? '图片谱' : item.summary,
                style: const TextStyle(color: Color(0xFF69737B), height: 1.35),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _Pill(label: '${item.views} 浏览', color: _brand),
                  _Pill(label: item.date, color: const Color(0xFF7C6E5E)),
                ],
              ),
              const SizedBox(height: 18),
              if (item.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const _StateView(
                        icon: Icons.broken_image_outlined,
                        title: '图片加载失败',
                        message: '这个条目没有可用图片，可能需要进入原帖页面查看。',
                      ),
                    ),
                  ),
                )
              else
                const _StateView(
                  icon: Icons.image_not_supported_outlined,
                  title: '没有图片',
                  message: '接口里这个条目的 pic 为空，先作为资料卡展示。',
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: _brand),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF69737B), height: 1.35),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

String _clean(Object? value) {
  final text = (value ?? '').toString().trim();
  return text == 'null' ? '' : text;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse((value ?? '0').toString()) ?? 0;
}

List<String> _extractLyricUnits(String text) {
  final result = <String>[];
  for (final part in text.split(RegExp(r'\s+'))) {
    if (part.isEmpty || part.startsWith('+')) continue;
    result.add(part);
  }
  return result;
}
