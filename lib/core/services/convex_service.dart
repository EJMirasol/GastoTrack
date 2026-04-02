import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env.dart';

class ConvexService {
  final String apiUrl;
  final String siteUrl;

  ConvexService({String? apiUrl, String? siteUrl})
    : apiUrl = apiUrl ?? Env.convexUrl,
      siteUrl = siteUrl ?? Env.convexSiteUrl;

  String? _sessionToken;
  String? _convexJwt;

  void setSessionCookie(String? cookie) {
    _sessionToken = cookie;
  }

  String? get sessionCookie => _sessionToken;

  String? get convexJwt => _convexJwt;

  void setConvexJwt(String? jwt) {
    _convexJwt = jwt;
  }

  Map<String, String> get _authHeaders {
    if (_sessionToken == null) return {};
    return {'Cookie': '__Secure-better-auth.session_token=$_sessionToken'};
  }

  Map<String, String> get _convexHeaders {
    if (_convexJwt == null) return {};
    return {'Authorization': 'Bearer $_convexJwt'};
  }

  static const _jwtCookiePrefix = '__Secure-better-auth.convex_jwt=';

  String? _extractConvexJwt(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) return null;
    for (final part in setCookie.split(',')) {
      final trimmed = part.trim();
      if (trimmed.startsWith(_jwtCookiePrefix)) {
        final semiIdx = trimmed.indexOf(';');
        if (semiIdx == -1) return trimmed.substring(_jwtCookiePrefix.length);
        return trimmed.substring(_jwtCookiePrefix.length, semiIdx);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _authRequest(
    String endpoint,
    Map<String, dynamic> body, {
    bool isGet = false,
  }) async {
    final url = '$siteUrl/api/auth/$endpoint';
    final response = isGet
        ? await http.get(
            Uri.parse(url),
            headers: {..._authHeaders, 'Origin': siteUrl},
          )
        : await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Origin': siteUrl,
              ..._authHeaders,
            },
            body: jsonEncode(body),
          );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      throw ConvexApiException(
        message:
            body['message'] as String? ??
            body['error'] as String? ??
            'Auth request failed',
        statusCode: response.statusCode,
      );
    }

    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final token = result['token'] as String?;
    if (token != null) {
      _sessionToken = token;
    }

    final jwt = _extractConvexJwt(response);
    if (jwt != null) {
      _convexJwt = jwt;
    }

    return result;
  }

  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    String? name,
  }) {
    return _authRequest('sign-up/email', {
      'email': email,
      'password': password,
      // ignore: use_null_aware_elements
      if (name != null) 'name': name,
    });
  }

  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) {
    return _authRequest('sign-in/email', {
      'email': email,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> signOut() async {
    final url = '$siteUrl/api/auth/sign-out';
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Origin': siteUrl,
        ..._authHeaders,
      },
      body: jsonEncode({}),
    );

    _sessionToken = null;
    _convexJwt = null;

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      throw ConvexApiException(
        message: body['message'] as String? ?? 'Sign out failed',
        statusCode: response.statusCode,
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSession() {
    return _authRequest('get-session', {}, isGet: true);
  }

  Future<Map<String, dynamic>> requestPasswordReset({required String email}) {
    return _authRequest('request-password-reset', {'email': email});
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _authRequest('change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> query(
    String path,
    Map<String, dynamic> args,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/api/query'),
      headers: {'Content-Type': 'application/json', ..._convexHeaders},
      body: jsonEncode({'path': path, 'args': args, 'format': 'json'}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw ConvexApiException(
        message: body['message'] as String? ?? 'Query failed',
        statusCode: response.statusCode,
      );
    }

    return body;
  }

  Future<Map<String, dynamic>> mutation(
    String path,
    Map<String, dynamic> args,
  ) async {
    final response = await http.post(
      Uri.parse('$apiUrl/api/mutation'),
      headers: {'Content-Type': 'application/json', ..._convexHeaders},
      body: jsonEncode({'path': path, 'args': args, 'format': 'json'}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw ConvexApiException(
        message: body['message'] as String? ?? 'Mutation failed',
        statusCode: response.statusCode,
      );
    }

    return body;
  }
}

class ConvexApiException implements Exception {
  final String message;
  final int statusCode;

  const ConvexApiException({required this.message, required this.statusCode});

  @override
  String toString() => 'ConvexApiException($statusCode): $message';
}

final convexServiceProvider = Provider<ConvexService>((ref) {
  return ConvexService();
});
