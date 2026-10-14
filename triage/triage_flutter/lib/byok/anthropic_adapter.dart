import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider_adapter.dart';

class AnthropicAdapter implements LlmProviderAdapter {
  @override
  LlmProviderType get providerType => LlmProviderType.anthropic;

  @override
  Stream<String> streamChatCompletion(
    String prompt, {
    required LlmProviderConfig config,
    http.Client? client,
  }) async* {
    final httpClient = client ?? http.Client();
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    final requestBody = jsonEncode({
      'model': config.effectiveModel,
      'max_tokens': config.maxTokens,
      'temperature': config.temperature,
      'stream': true,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
    });

    final request = http.Request('POST', url)
      ..headers['content-type'] = 'application/json'
      ..headers['x-api-key'] = config.apiKey
      ..headers['anthropic-version'] = '2023-06-01'
      ..body = requestBody;

    http.StreamedResponse response;
    try {
      response = await httpClient.send(request);
    } catch (e) {
      throw StateError('Anthropic connection error: $e');
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      try {
        final parsed = jsonDecode(errorBody);
        final msg = parsed['error']?['message'] ?? errorBody;
        throw StateError('Anthropic API error (${response.statusCode}): $msg');
      } catch (_) {
        throw StateError('Anthropic API error (${response.statusCode}): $errorBody');
      }
    }

    final lineStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payload = trimmed.substring(5).trim();
      if (payload.isEmpty || payload == '[DONE]') continue;

      try {
        final decoded = jsonDecode(payload) as Map<String, dynamic>;
        final delta = decoded['delta'] as Map<String, dynamic>?;
        if (delta != null && delta['type'] == 'text_delta') {
          final text = delta['text'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        }
      } catch (_) {}
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
    final url = Uri.parse('https://api.anthropic.com/v1/messages');

    try {
      final res = await httpClient.post(
        url,
        headers: {
          'content-type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': effectiveModel,
          'max_tokens': 5,
          'messages': [
            {'role': 'user', 'content': 'ping'}
          ],
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
