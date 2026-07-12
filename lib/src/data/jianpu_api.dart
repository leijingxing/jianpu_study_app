import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/network/network_client.dart';
import '../domain/models/score.dart';
import 'mappers/score_mapper.dart';

class JianpuApi {
  JianpuApi({NetworkClient? networkClient})
    : _networkClient = networkClient ?? NetworkClient();

  final NetworkClient _networkClient;
  var _disposed = false;

  /// Releases the owned HTTP client.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _networkClient.close();
  }

  static const musicBase = 'http://guji666.com';
  static const forumBase = 'http://www.jita666.com';
  static const yuepuBase = 'http://xp.yuepuvip.com:8100/one';
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Mobile Safari/537.36',
  };

  Future<List<MusicSummary>> fetchDynamicList({
    int page = 1,
    int limit = 30,
  }) async {
    final uri = Uri.parse(
      '$musicBase/home/music/collect_sort',
    ).replace(queryParameters: {'limit': '$limit', 'page': '$page'});
    final json = await _getJson(uri);
    final list = (json['data']?['data'] as List? ?? const []);
    return list
        .whereType<Map>()
        .map((item) => ScoreMapper.gujiSummary(item.cast<String, dynamic>()))
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

  Future<List<MusicSummary>> fetchYuepuDynamicList({
    int page = 1,
    int limit = 30,
    String query = '',
  }) async {
    final params = {
      'offset': '$page',
      'limit': '$limit',
      if (query.trim().isNotEmpty) 'specNames': query.trim(),
    };
    final uri = Uri.parse(
      '$yuepuBase/oper/queryDynAppList',
    ).replace(queryParameters: params);
    final json = await _getJson(uri, headers: _headers);
    final list = (json['rows'] as List? ?? const []);
    return list
        .whereType<Map>()
        .map((item) => ScoreMapper.yuepuSummary(item.cast<String, dynamic>()))
        .where((item) => item.externalId.isNotEmpty && item.title.isNotEmpty)
        .toList();
  }

  Future<MusicDetail> fetchDynamicDetail(int id) async {
    final uri = Uri.parse(
      '$musicBase/home/music/detail',
    ).replace(queryParameters: {'id': '$id'});
    final json = await _getJson(uri);
    return ScoreMapper.gujiDetail(
      (json['data'] as Map? ?? const {}).cast<String, dynamic>(),
    );
  }

  Future<String> fetchScoreText(String path) async {
    final normalized = path.startsWith('http') ? path : '$musicBase$path';
    final response = await _networkClient.get(Uri.parse(normalized));
    return utf8.decode(response.bodyBytes);
  }

  Future<List<ImageScoreItem>> fetchImageList({
    int page = 1,
    String orderBy = 'viewnum',
  }) async {
    final uri = Uri.parse('$forumBase/plugin.php').replace(
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
    final items = list
        .whereType<Map>()
        .map((item) => ScoreMapper.forumImage(item.cast<String, dynamic>()))
        .toList();
    _logImageList(page: page, orderBy: orderBy, items: items);
    return items;
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

  Future<List<ImageScoreItem>> fetchYuepuSheetList({
    int page = 1,
    int limit = 30,
    String query = '',
  }) async {
    final params = {
      'offset': '$page',
      'limit': '$limit',
      if (query.trim().isNotEmpty) 'musTitle': query.trim(),
      if (query.trim().isNotEmpty) 'type': 'musscore',
      'versionNo': '66',
    };
    final uri = Uri.parse(
      '$yuepuBase/musscore/list',
    ).replace(queryParameters: params);
    final json = await _getJson(uri, headers: _headers);
    final list = (json['rows'] as List? ?? const []);
    return list
        .whereType<Map>()
        .map((item) => ScoreMapper.yuepuImage(item.cast<String, dynamic>()))
        .where((item) => item.id != 'yuepu-mus:' && item.title.isNotEmpty)
        .toList();
  }

  Future<List<AccompanimentItem>> fetchYuepuAccompanimentList({
    int page = 1,
    int limit = 30,
    String query = '',
  }) async {
    final params = {
      'offset': '$page',
      'limit': '$limit',
      if (query.trim().isNotEmpty) 'accNames': query.trim(),
      if (query.trim().isNotEmpty) 'type': 'accompany',
      'versionNo': '66',
    };
    final uri = Uri.parse(
      '$yuepuBase/accompany/list',
    ).replace(queryParameters: params);
    final json = await _getJson(uri, headers: _headers);
    final list = (json['rows'] as List? ?? const []);
    return list
        .whereType<Map>()
        .map(
          (item) =>
              ScoreMapper.yuepuAccompaniment(item.cast<String, dynamic>()),
        )
        .where((item) => item.id.isNotEmpty && item.title.isNotEmpty)
        .toList();
  }

  Future<ImageScoreDetail> fetchImageDetail(ImageScoreItem item) async {
    if (item.isYuepu) {
      final imageUrls = item.fileUrls.where(_looksLikeImageUrl).toList();
      return ImageScoreDetail(
        item: item,
        imageUrls: imageUrls,
        videoUrls: const [],
      );
    }
    final uri = Uri.parse('$forumBase/article-${item.id}-1.html');
    final response = await _networkClient.get(uri);
    final html = utf8.decode(response.bodyBytes);
    final content = _articleContent(html);
    final source = content.isEmpty ? html : content;
    final imageUrls = _extractImageUrls(source);
    final videoUrls = _extractVideoUrls(source);
    if (imageUrls.isEmpty && item.imageUrl.isNotEmpty) {
      imageUrls.add(item.imageUrl);
    }
    _logImageDetail(item: item, imageUrls: imageUrls, videoUrls: videoUrls);
    return ImageScoreDetail(
      item: item,
      imageUrls: imageUrls,
      videoUrls: videoUrls,
    );
  }

  Future<Map<String, dynamic>> _getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    return _networkClient.getJson(uri, headers: headers);
  }

  Future<List<T>> mergeLists<T>(
    List<Future<List<T>> Function()> loaders,
  ) async {
    final result = <T>[];
    Object? firstError;
    for (final loader in loaders) {
      try {
        result.addAll(await loader());
      } catch (error) {
        firstError ??= error;
        if (kDebugMode) debugPrint('[接口聚合] $error');
      }
    }
    if (result.isEmpty && firstError != null) throw firstError;
    return result;
  }

  String _articleContent(String html) {
    final match = RegExp(
      r"""<td[^>]+id=["']article_content["'][\s\S]*?</td>""",
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(0) ?? '';
  }

  List<String> _extractImageUrls(String html) {
    final urls = <String>[];
    final seen = <String>{};
    final matches = RegExp(
      r'<img[^>]+(?:src|data-original|zoomfile|file)=["'
      ']([^"'
      ']+)["'
      ']',
      caseSensitive: false,
    ).allMatches(html);

    for (final match in matches) {
      final src = match.group(1) ?? '';
      final url = _normalizeForumUrl(_decodeHtmlAttribute(src));
      if (_looksLikeImageUrl(url) && seen.add(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  bool _looksLikeImageUrl(String url) {
    final lower = url.toLowerCase();
    return RegExp(r'\.(jpg|jpeg|png|gif|webp)(\?|$)').hasMatch(lower);
  }

  List<String> _extractVideoUrls(String html) {
    final urls = <String>[];
    final seen = <String>{};
    final matches = RegExp(
      r'<(?:video|source)[^>]+src=["'
      ']([^"'
      ']+)["'
      '][^>]*',
      caseSensitive: false,
    ).allMatches(html);

    for (final match in matches) {
      final src = match.group(1) ?? '';
      final tag = match.group(0)?.toLowerCase() ?? '';
      final url = _normalizeForumUrl(_decodeHtmlAttribute(src));
      final lower = url.toLowerCase();
      final looksLikeVideo =
          tag.contains('video/') ||
          lower.contains('.mp4') ||
          lower.endsWith('.attach');
      if (looksLikeVideo && seen.add(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  String _decodeHtmlAttribute(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  String _normalizeForumUrl(String path) {
    final text = textValue(path);
    if (text.isEmpty ||
        text.startsWith('http://') ||
        text.startsWith('https://')) {
      return text;
    }
    if (text.startsWith('//')) return 'http:$text';
    if (text.startsWith('data/')) return '$forumBase/$text';
    if (text.startsWith('/')) return '$forumBase$text';
    if (text.startsWith('portal/')) {
      return '$forumBase/data/attachment/$text';
    }
    return '$forumBase/$text';
  }

  void _logImageList({
    required int page,
    required String orderBy,
    required List<ImageScoreItem> items,
  }) {
    if (!kDebugMode) return;
    debugPrint('[图片谱列表] page=$page orderBy=$orderBy count=${items.length}');
    for (final item in items.take(12)) {
      debugPrint(
        '[图片谱列表] aid=${item.id} title=${item.title} '
        'hasVideo=${item.hasVideo} pic=${item.pic} imageUrl=${item.imageUrl}',
      );
    }
  }

  void _logImageDetail({
    required ImageScoreItem item,
    required List<String> imageUrls,
    required List<String> videoUrls,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[图片谱详情] aid=${item.id} title=${item.title} '
      'images=${imageUrls.length} videos=${videoUrls.length}',
    );
    for (final url in videoUrls) {
      debugPrint('[图片谱详情][video] $url');
    }
    for (final url in imageUrls) {
      debugPrint('[图片谱详情][image] $url');
    }
  }
}
