import 'package:connectivity_plus/connectivity_plus.dart';
import '../parser/deterministic_action_parser.dart';
import 'byok_key_store.dart';
import 'llm_provider_adapter.dart';

enum RoutingDestination {
  localSystemAction,
  cloudLlmStream,
  offlineError,
  unconfiguredError,
}

class ByokRoutingDecision {
  final RoutingDestination destination;
  final ParsedActionIntent? localIntent;
  final LlmProviderConfig? activeConfig;
  final String? errorMessage;

  const ByokRoutingDecision({
    required this.destination,
    this.localIntent,
    this.activeConfig,
    this.errorMessage,
  });

  bool get isLocal => destination == RoutingDestination.localSystemAction;
  bool get isCloud => destination == RoutingDestination.cloudLlmStream;
  bool get isError =>
      destination == RoutingDestination.offlineError ||
      destination == RoutingDestination.unconfiguredError;
}

/// Strict routing firewall that inspects queries locally.
/// Local system commands ALWAYS execute offline and NEVER reach the cloud LLM.
/// The LLM is firewalled from directly triggering native actions.
class ByokRoutingFirewall {
  final ByokKeyStore keyStore;
  final Connectivity? connectivity;

  const ByokRoutingFirewall({
    required this.keyStore,
    this.connectivity,
  });

  /// Evaluates the input utterance against the firewall rules.
  /// Zero network calls are made for local commands.
  Future<ByokRoutingDecision> evaluate(
    String utterance, {
    bool? overrideIsOnline,
    LlmProviderConfig? overrideConfig,
  }) async {
    // 1. Strict Local Intent Gate: Run zero-network deterministic regex parser
    final localIntent = DeterministicActionParser.parse(utterance);
    if (localIntent.isMatched && localIntent.type != ActionType.unknown) {
      // Local system command! Absolutely no network request is sent to LLM.
      return ByokRoutingDecision(
        destination: RoutingDestination.localSystemAction,
        localIntent: localIntent,
      );
    }

    // 2. Connectivity Gate
    bool isOnline = overrideIsOnline ?? false;
    if (overrideIsOnline == null) {
      final conn = connectivity ?? Connectivity();
      try {
        final results = await conn.checkConnectivity();
        isOnline = results.any((r) => r != ConnectivityResult.none);
      } catch (_) {
        isOnline = false;
      }
    }

    if (!isOnline) {
      return const ByokRoutingDecision(
        destination: RoutingDestination.offlineError,
        errorMessage: 'Internet connection required for conversational AI.',
      );
    }

    // 3. Provider Configuration Gate
    final config = overrideConfig ?? await keyStore.getActiveConfig();
    if (config == null || config.apiKey.isEmpty) {
      final activeProvider = overrideConfig?.provider ?? await keyStore.getActiveProvider();
      return ByokRoutingDecision(
        destination: RoutingDestination.unconfiguredError,
        errorMessage:
            'Please configure your ${activeProvider.displayName} API key in BYOK Settings.',
      );
    }

    // 4. Approved for Cloud LLM Streaming
    return ByokRoutingDecision(
      destination: RoutingDestination.cloudLlmStream,
      activeConfig: config,
    );
  }

  /// Security Firewall: Checks whether an LLM output attempts to suggest or invoke an action.
  /// Direct hardware invocation is strictly prevented; explicit user confirmation is mandated.
  static bool requiresExplicitConfirmation(String llmOutput) {
    final lower = llmOutput.toLowerCase();
    final actionPattern = RegExp(
      r'(?:(?:set|setting|adjust|change|turn|mute|unmute)\s+(?:the\s+)?(?:volume|brightness|do not disturb|dnd)|(?:set|setting)\s+(?:a\s+)?(?:timer|alarm)|(?:open|launch)\s+[a-z]+|action:|actions:|tool_call|"action":)',
      caseSensitive: false,
    );
    return actionPattern.hasMatch(lower);
  }
}
