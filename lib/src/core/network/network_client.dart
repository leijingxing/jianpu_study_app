import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../error/failure.dart';

/// Centralizes HTTP status validation, timeout handling, and JSON decoding.
final class NetworkClient {
  NetworkClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  var _closed = false;

  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final response = await get(uri, headers: headers);
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw const FormatException('JSON root is not an object.');
      }
      return decoded.cast<String, dynamic>();
    } on FormatException catch (error) {
      throw NetworkFailure('接口返回了无法解析的数据。', cause: error);
    }
  }

  Future<http.Response> get(Uri uri, {Map<String, String>? headers}) async {
    if (_closed) {
      throw const NetworkFailure('网络客户端已关闭。');
    }
    try {
      final response = await _client
          .get(uri, headers: headers)
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw NetworkFailure('接口请求失败（${response.statusCode}）。');
      }
      return response;
    } on TimeoutException catch (error) {
      throw NetworkFailure('网络请求超时。', cause: error);
    } on Failure {
      rethrow;
    } catch (error) {
      throw NetworkFailure('网络请求失败。', cause: error);
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _client.close();
  }
}
