import 'dart:async';
import 'package:http/http.dart' as http;
import 'anthropic_adapter.dart';
import 'byok_key_store.dart';
import 'byok_routing_firewall.dart';
import 'gemini_adapter.dart';
import 'llm_provider_adapter.dart';
import 'openai_compatible_adapter.dart';

class ByokStreamSession {
  final String providerName;
  final String modelName;
  final Stream<String> tokenStream;
  final void Function() cancel;

  const ByokStreamSession({
    required this.providerName,
    required this.modelName,
    required this.tokenStream,
    required this.cancel,
  });
}

class ByokGateway {
  final ByokKeyStore keyStore;
  final ByokRoutingFirewall firewall;
  final Map<LlmProviderType, LlmProviderAdapter> _adapters;

  ByokGateway({
    required this.keyStore,
    ByokRoutingFirewall? firewall,
    Map<LlmProviderType, LlmProviderAdapter>? adapters,
  }) : firewall = firewall ?? ByokRoutingFirewall(keyStore: keyStore),
       _adapters = adapters ?? _createDefaultAdapters();

  static Map<LlmProviderType, LlmProviderAdapter> _createDefaultAdapters() {
    return {
      LlmProviderType.gemini: GeminiAdapter(),
      LlmProviderType.openai: OpenAiCompatibleAdapter(LlmProviderType.openai),
      LlmProviderType.groq: OpenAiCompatibleAdapter(LlmProviderType.groq),
      LlmProviderType.anthropic: AnthropicAdapter(),
      LlmProviderType.openrouter: OpenAiCompatibleAdapter(
        LlmProviderType.openrouter,
      ),
      LlmProviderType.deepseek: OpenAiCompatibleAdapter(
        LlmProviderType.deepseek,
      ),
    };
  }

  LlmProviderAdapter getAdapter(LlmProviderType type) {
    final adapter = _adapters[type];
    if (adapter == null) {
      throw UnsupportedError('No adapter registered for ${type.displayName}');
    }
    return adapter;
  }

  /// Evaluates query against the routing firewall
  Future<ByokRoutingDecision> evaluateQuery(
    String query, {
    bool? overrideIsOnline,
    LlmProviderConfig? overrideConfig,
  }) => firewall.evaluate(
    query,
    overrideIsOnline: overrideIsOnline,
    overrideConfig: overrideConfig,
  );

  /// Initiates a cancellable streaming chat session
  Future<ByokStreamSession> streamConversationalQuery(
    String query, {
    LlmProviderConfig? overrideConfig,
    bool? overrideIsOnline,
    http.Client? client,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // Enforce Routing Firewall: reject local system queries and verify connectivity
    final decision = await evaluateQuery(
      query,
      overrideIsOnline: overrideIsOnline,
      overrideConfig: overrideConfig,
    );
    if (decision.isLocal ||
        decision.destination == RoutingDestination.localSystemAction) {
      throw StateError(
        'Routing Firewall Violation: Local command "$query" cannot be streamed to cloud LLM.',
      );
    }
    if (decision.destination == RoutingDestination.offlineError) {
      throw StateError(
        decision.errorMessage ??
            'Internet connection required for conversational AI.',
      );
    }

    final config = overrideConfig ?? await keyStore.getActiveConfig();
    if (config == null || config.apiKey.isEmpty) {
      throw StateError('No API key configured for active provider');
    }

    final adapter = getAdapter(config.provider);
    final controller = StreamController<String>.broadcast();
    final effectiveClient = client ?? http.Client();
    bool isCancelled = false;
    StreamSubscription<String>? sub;

    void cancel() {
      if (isCancelled) return;
      isCancelled = true;
      sub?.cancel();
      if (!controller.isClosed) {
        controller.close();
      }
    }

    try {
      final rawStream = adapter
          .streamChatCompletion(query, config: config, client: effectiveClient)
          .timeout(
            timeout,
            onTimeout: (sink) {
              sink.addError(
                TimeoutException(
                  '${config.provider.displayName} ${config.effectiveModel}: no stream token for ${timeout.inSeconds}s',
                ),
              );
              sink.close();
            },
          );

      sub = rawStream.listen(
        (chunk) {
          if (!isCancelled && !controller.isClosed) {
            controller.add(chunk);
          }
        },
        onError: (err) {
          if (!isCancelled && !controller.isClosed) {
            controller.addError(err);
            controller.close();
          }
        },
        onDone: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
        cancelOnError: true,
      );
    } catch (e) {
      controller.addError(e);
      controller.close();
    }

    return ByokStreamSession(
      providerName: config.provider.displayName,
      modelName: config.effectiveModel,
      tokenStream: controller.stream,
      cancel: cancel,
    );
  }

  /// Tests connectivity for a given provider and API key
  Future<bool> testProviderKey(
    LlmProviderType provider,
    String apiKey, {
    String? model,
    http.Client? client,
  }) {
    final adapter = getAdapter(provider);
    return adapter.testConnectivity(apiKey, model: model, client: client);
  }
}
