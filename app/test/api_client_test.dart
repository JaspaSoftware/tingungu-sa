import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:tingungu_app/services/api_client.dart';

void main() {
  test('builds a JSON request and decodes its response', () async {
    final client = _FakeClient((request) {
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://api.example.test/v1/items?q=one');
      expect(request.headers['Accept'], 'application/json');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(request.body), {'name': 'Tingungu'});
      return _jsonResponse(201, '{"id":7}');
    });

    final response = await ApiClient(client: client).post(
      'items',
      baseUrl: 'https://api.example.test/v1',
      queryParameters: {'q': 'one'},
      body: {'name': 'Tingungu'},
    );

    expect(response.statusCode, 201);
    expect(response.body, {'id': 7});
  });

  test('surfaces API errors with their status code and message', () async {
    final client = _FakeClient(
      (_) => _jsonResponse(403, '{"error":"Forbidden"}'),
    );

    await expectLater(
      ApiClient(
        client: client,
      ).get('admin', baseUrl: 'https://api.example.test'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 403)
            .having((error) => error.message, 'message', 'Forbidden'),
      ),
    );
  });

  test('fails clearly when an endpoint is not configured', () async {
    await expectLater(
      ApiClient(
        client: _FakeClient((_) => _jsonResponse(200, '{}')),
      ).get('communities', baseUrl: ''),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'The API endpoint is not configured.',
        ),
      ),
    );
  });
}

class _FakeClient extends http.BaseClient {
  _FakeClient(this.respond);

  final http.StreamedResponse Function(http.Request request) respond;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return respond(request as http.Request);
  }
}

http.StreamedResponse _jsonResponse(int statusCode, String body) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
