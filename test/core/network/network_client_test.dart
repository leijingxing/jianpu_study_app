import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jianpu_study_app/src/core/error/failure.dart';
import 'package:jianpu_study_app/src/core/network/network_client.dart';

void main() {
  test('decodes a successful JSON object', () async {
    final client = NetworkClient(
      client: MockClient((request) async => http.Response('{"value":1}', 200)),
    );
    addTearDown(client.close);

    final result = await client.getJson(Uri.parse('https://example.test'));

    expect(result['value'], 1);
  });

  test('converts non-success status to NetworkFailure', () async {
    final client = NetworkClient(
      client: MockClient((request) async => http.Response('no', 503)),
    );
    addTearDown(client.close);

    expect(
      () => client.getJson(Uri.parse('https://example.test')),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('converts malformed JSON to NetworkFailure', () async {
    final client = NetworkClient(
      client: MockClient((request) async => http.Response('{', 200)),
    );
    addTearDown(client.close);

    expect(
      () => client.getJson(Uri.parse('https://example.test')),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('converts timeout to NetworkFailure', () async {
    final client = NetworkClient(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((request) async {
        await Completer<void>().future;
        return http.Response('{}', 200);
      }),
    );
    addTearDown(client.close);

    expect(
      () => client.getJson(Uri.parse('https://example.test')),
      throwsA(isA<NetworkFailure>()),
    );
  });
}
