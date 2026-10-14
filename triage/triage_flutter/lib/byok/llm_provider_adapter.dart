import 'dart:async';
import 'package:http/http.dart' as http;

enum LlmProviderType {
  gemini,
  openai,
  groq,
  anthropic,
  openrouter,
  deepseek;

  String get displayName {
    switch (this) {
      case LlmProviderType.gemini:
        return 'Google Gemini';
      case LlmProviderType.openai:
        return 'OpenAI';
      case LlmProviderType.groq:
        return 'Groq (Low Latency)';
      case LlmProviderType.anthropic:
        return 'Anthropic Claude';
      case LlmProviderType.openrouter:
        return 'OpenRouter';
      case LlmProviderType.deepseek:
        return 'DeepSeek';
    }
  }

  String get defaultModel {
    switch (this) {
      case LlmProviderType.gemini:
        return 'gemini-2.5-flash';
      case LlmProviderType.openai:
        return 'gpt-4o-mini';
      case LlmProviderType.groq:
        return 'llama-3.3-70b-versatile';
      case LlmProviderType.anthropic:
        return 'claude-3-5-sonnet-20241022';
      case LlmProviderType.openrouter:
        return 'meta-llama/llama-3.3-70b-instruct';
      case LlmProviderType.deepseek:
        return 'deepseek-chat';
    }
  }

  List<String> get popularModels {
    switch (this) {
      case LlmProviderType.gemini:
        return [
          'gemini-2.5-flash',
          'gemini-3.8-flash',
          'gemini-3.6-flash',
          'gemini-3.5-flash-lite',
          'gemini-3.1-flash-lite',
        ];
      case LlmProviderType.openai:
        return ['gpt-4o-mini', 'gpt-4o', 'o1-mini'];
      case LlmProviderType.groq:
        return [
          'llama-3.3-70b-versatile',
          'llama-3.1-8b-instant',
          'mixtral-8x7b-32768',
        ];
      case LlmProviderType.anthropic:
        return ['claude-3-5-sonnet-20241022', 'claude-3-5-haiku-20241022'];
      case LlmProviderType.openrouter:
        return [
          'meta-llama/llama-3.3-70b-instruct',
          'google/gemini-2.0-flash-001',
          'deepseek/deepseek-chat',
        ];
      case LlmProviderType.deepseek:
        return ['deepseek-chat', 'deepseek-reasoner'];
    }
  }

  static LlmProviderType fromString(String? val) {
    if (val == null) return LlmProviderType.gemini;
    return LlmProviderType.values.firstWhere(
      (p) => p.name == val.toLowerCase(),
      orElse: () => LlmProviderType.gemini,
    );
  }
}

class LlmProviderConfig {
  final LlmProviderType provider;
  final String apiKey;
  final String? model;
  final double temperature;
  final int maxTokens;
  final String? customBaseUrl;

  const LlmProviderConfig({
    required this.provider,
    required this.apiKey,
    this.model,
    this.temperature = 0.7,
    this.maxTokens = 1024,
    this.customBaseUrl,
  });

  String get effectiveModel => model ?? provider.defaultModel;
}

/// Abstract contract for streaming LLM provider integrations
abstract class LlmProviderAdapter {
  LlmProviderType get providerType;

  /// Streams token deltas from the provider over Server-Sent Events (SSE)
  Stream<String> streamChatCompletion(
    String prompt, {
    required LlmProviderConfig config,
    http.Client? client,
  });

  /// Tests whether the API key and model connectivity succeed
  Future<bool> testConnectivity(
    String apiKey, {
    String? model,
    http.Client? client,
  });
}
