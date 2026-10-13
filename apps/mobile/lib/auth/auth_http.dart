import 'package:http/http.dart' as http;

import 'configuration.dart';

/// SDK secrets stay at the configured origin, in POST bodies/headers.
class AuthHttpClient extends http.BaseClient {
  final Uri origin;
  final http.Client delegate;
  AuthHttpClient(this.origin, {http.Client? client})
    : delegate = client ?? http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.origin != origin.origin ||
        !request.url.path.startsWith('/auth/v1/')) {
      throw const AuthFailure('provider_response_invalid');
    }
    request.followRedirects = false;
    final response = await delegate.send(request);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      await response.stream.drain<void>();
      throw const AuthFailure('provider_response_invalid');
    }
    Stream<List<int>> bounded() async* {
      var bytes = 0;
      await for (final chunk in response.stream) {
        bytes += chunk.length;
        if (bytes > 65536) throw const AuthFailure('provider_response_invalid');
        yield chunk;
      }
    }

    return http.StreamedResponse(
      bounded(),
      response.statusCode,
      headers: response.headers,
      request: response.request,
      reasonPhrase: response.reasonPhrase,
    );
  }

  @override
  void close() => delegate.close();
}
