import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiResponse {
  const ApiResponse({required this.statusCode, required this.body});

  final int statusCode;
  final Object? body;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static final ApiClient shared = ApiClient();

  final http.Client _client;

  Future<ApiResponse> get(
    String path, {
    String? baseUrl,
    Map<String, String>? queryParameters,
    bool authenticated = false,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _request(
      'GET',
      path,
      baseUrl: baseUrl,
      queryParameters: queryParameters,
      authenticated: authenticated,
      timeout: timeout,
    );
  }

  Future<ApiResponse> post(
    String path, {
    String? baseUrl,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    bool authenticated = false,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _request(
      'POST',
      path,
      baseUrl: baseUrl,
      queryParameters: queryParameters,
      body: body,
      authenticated: authenticated,
      timeout: timeout,
    );
  }

  Future<ApiResponse> _request(
    String method,
    String path, {
    String? baseUrl,
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    required bool authenticated,
    required Duration timeout,
  }) async {
    final rootUrl = (baseUrl ?? AppConfig.apiBaseUrl).trim();
    if (rootUrl.isEmpty) {
      throw const ApiException('The API endpoint is not configured.');
    }

    final root = rootUrl.replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse(
      '$root/${path.replaceFirst(RegExp(r'^/+'), '')}',
    ).replace(queryParameters: queryParameters);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';

    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    if (authenticated) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw const ApiException('Please log in first.');
      }
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) {
        throw const ApiException('Unable to authenticate this request.');
      }
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamedResponse = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(
      streamedResponse,
    ).timeout(timeout);

    Object? decodedBody;
    if (response.bodyBytes.isNotEmpty) {
      final responseText = utf8.decode(response.bodyBytes);
      try {
        decodedBody = jsonDecode(responseText);
      } on FormatException {
        if (response.statusCode >= 400) {
          throw ApiException(
            responseText.isNotEmpty
                ? responseText
                : 'Request failed (${response.statusCode}).',
            statusCode: response.statusCode,
          );
        }
        rethrow;
      }
    }

    if (response.statusCode >= 400) {
      final errorMessage = decodedBody is Map<String, dynamic>
          ? (decodedBody['error'] ?? decodedBody['message'])?.toString()
          : null;
      throw ApiException(
        errorMessage ?? 'Request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    return ApiResponse(statusCode: response.statusCode, body: decodedBody);
  }
}
