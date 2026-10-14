import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider_adapter.dart';

class GeminiAdapter implements LlmProviderAdapter {
  @override
  LlmProviderType get providerType => LlmProviderType.gemini;

  @override
  Stream<String> streamChatCompletion(
    String prompt, {
    required LlmProviderConfig config,
    http.Client? client,
  }) async* {
    final httpClient = client ?? http.Client();
    final model = config.effectiveModel;
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:streamGenerateContent?alt=sse&key=${config.apiKey}',
    );

    final requestBody = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': config.temperature,
        'maxOutputTokens': config.maxTokens,
      },
    });

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..body = requestBody;

    http.StreamedResponse response;
    try {
      response = await httpClient
          .send(request)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'Gemini $model: no HTTP response headers after 15s',
            ),
          );
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw StateError('Gemini $model connection error: $e');
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      String message = errorBody;
      try {
        final parsed = jsonDecode(errorBody);
        if (parsed is Map && parsed['error'] is Map) {
          message = parsed['error']['message']?.toString() ?? errorBody;
        }
      } on FormatException {
        // Preserve the raw response when Google does not return JSON.
      }
      throw StateError('Gemini $model HTTP ${response.statusCode}: $message');
    }

    final lineStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(
          const Duration(seconds: 20),
          onTimeout: (sink) {
            sink.addError(
              TimeoutException('Gemini $model HTTP 200: no SSE data for 20s'),
            );
            sink.close();
          },
        );

    await for (final line in lineStream) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;

      try {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates[0]['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts[0]['text'] as String?;
            if (text != null && text.isNotEmpty) {
              yield text;
            }
          }
        }
      } catch (_) {
        // Silently skip malformed intermediate stream fragments
      }
    }
  }

  @override
  Future<bool> testConnectivity(
    String apiKey, {
    String? model,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final effectiveModel = model ?? providerType.defaultModel;
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$effectiveModel:generateContent?key=$apiKey',
    );

    try {
      final res = await httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'ping'},
              ],
            },
          ],
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
