import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'llm_provider_adapter.dart';

class OpenAiCompatibleAdapter implements LlmProviderAdapter {
  final LlmProviderType _type;

  OpenAiCompatibleAdapter(this._type);

  @override
  LlmProviderType get providerType => _type;

  Uri _getEndpoint(LlmProviderConfig config) {
    if (config.customBaseUrl != null && config.customBaseUrl!.isNotEmpty) {
      final base = config.customBaseUrl!.replaceAll(RegExp(r'/+$'), '');
      return Uri.parse('$base/chat/completions');
    }

    switch (_type) {
      case LlmProviderType.groq:
        return Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      case LlmProviderType.openrouter:
        return Uri.parse('https://openrouter.ai/api/v1/chat/completions');
      case LlmProviderType.deepseek:
        return Uri.parse('https://api.deepseek.com/chat/completions');
      case LlmProviderType.openai:
      default:
        return Uri.parse('https://api.openai.com/v1/chat/completions');
    }
  }

  @override
  Stream<String> streamChatCompletion(
    String prompt, {
    required LlmProviderConfig config,
    http.Client? client,
  }) async* {
    final httpClient = client ?? http.Client();
    final url = _getEndpoint(config);

    final requestBody = jsonEncode({
      'model': config.effectiveModel,
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': config.temperature,
      'max_tokens': config.maxTokens,
      'stream': true,
    });

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer ${config.apiKey}'
      ..body = requestBody;

    if (_type == LlmProviderType.openrouter) {
      request.headers['HTTP-Referer'] = 'https://github.com/triage-assistant';
      request.headers['X-Title'] = 'Triage Offline Assistant';
    }

    http.StreamedResponse response;
    try {
      response = await httpClient.send(request);
    } catch (e) {
      throw StateError('${_type.displayName} connection error: $e');
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      try {
        final parsed = jsonDecode(errorBody);
        final msg = parsed['error']?['message'] ?? errorBody;
        throw StateError('${_type.displayName} API error (${response.statusCode}): $msg');
      } catch (_) {
        throw StateError('${_type.displayName} API error (${response.statusCode}): $errorBody');
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
        final choices = decoded['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          final content = delta?['content'] as String?;
          if (content != null && content.isNotEmpty) {
            yield content;
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
    final config = LlmProviderConfig(
      provider: _type,
      apiKey: apiKey,
      model: model,
      maxTokens: 5,
    );
    final url = _getEndpoint(config);

    try {
      final res = await httpClient.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': config.effectiveModel,
          'messages': [
            {'role': 'user', 'content': 'ping'}
          ],
          'max_tokens': 5,
        }),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
