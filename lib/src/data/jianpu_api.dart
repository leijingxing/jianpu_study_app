import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class JianpuApi {
  JianpuApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const musicBase = 'http://guji666.com';
  static const forumBase = 'http://www.jita666.com';

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
      '$musicBase/home/music/detail',
    ).replace(queryParameters: {'id': '$id'});
    final json = await _getJson(uri);
    return MusicDetail.fromJson(
      (json['data'] as Map? ?? const {}).cast<String, dynamic>(),
    );
  }

  Future<String> fetchScoreText(String path) async {
    final normalized = path.startsWith('http') ? path : '$musicBase$path';
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
        .map((item) => ImageScoreItem.fromJson(item.cast<String, dynamic>()))
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

  Future<ImageScoreDetail> fetchImageDetail(ImageScoreItem item) async {
    final uri = Uri.parse('$forumBase/article-${item.id}-1.html');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('图片谱页面加载失败: ${response.statusCode}');
    }
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

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('接口请求失败: ${response.statusCode}');
    }
    final text = utf8.decode(response.bodyBytes);
    return (jsonDecode(text) as Map).cast<String, dynamic>();
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
      final url = normalizeForumUrl(_decodeHtmlAttribute(src));
      final lower = url.toLowerCase();
      final looksLikeScoreImage = RegExp(
        r'\.(jpg|jpeg|png|gif|webp)(\?|$)',
      ).hasMatch(lower);
      if (looksLikeScoreImage && seen.add(url)) {
        urls.add(url);
      }
    }
    return urls;
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
      final url = normalizeForumUrl(_decodeHtmlAttribute(src));
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
