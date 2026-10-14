import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:triage_flutter/byok/anthropic_adapter.dart';
import 'package:triage_flutter/byok/byok_gateway.dart';
import 'package:triage_flutter/byok/byok_key_store.dart';
import 'package:triage_flutter/byok/byok_routing_firewall.dart';
import 'package:triage_flutter/byok/gemini_adapter.dart';
import 'package:triage_flutter/byok/llm_provider_adapter.dart';
import 'package:triage_flutter/byok/openai_compatible_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final mockStorage = <String, String>{};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (MethodCall call) async {
      switch (call.method) {
        case 'write':
          final key = call.arguments['key'] as String;
          final value = call.arguments['value'] as String?;
          if (value != null) mockStorage[key] = value;
          return null;
        case 'read':
          final key = call.arguments['key'] as String;
          return mockStorage[key];
        case 'delete':
          final key = call.arguments['key'] as String;
          mockStorage.remove(key);
          return null;
        case 'deleteAll':
          mockStorage.clear();
          return null;
        default:
          return null;
      }
    },
  );

  group('BYOK Routing Firewall Tests (Ticket 06 & 11)', () {
    late ByokKeyStore keyStore;
    late ByokRoutingFirewall firewall;

    setUp(() {
      mockStorage.clear();
      keyStore = ByokKeyStore();
      firewall = ByokRoutingFirewall(keyStore: keyStore);
    });

    test('strictly routes local volume command to localSystemAction with zero network', () async {
      final decision = await firewall.evaluate('set volume to 50 percent', overrideIsOnline: true);
      expect(decision.isLocal, isTrue);
      expect(decision.destination, equals(RoutingDestination.localSystemAction));
      expect(decision.localIntent?.targetPercent, equals(50));
    });

    test('strictly routes local brightness command to localSystemAction', () async {
      final decision = await firewall.evaluate('turn brightness to 80%', overrideIsOnline: true);
      expect(decision.isLocal, isTrue);
      expect(decision.destination, equals(RoutingDestination.localSystemAction));
      expect(decision.localIntent?.brightnessPercent, equals(80));
    });

    test('strictly routes local DND command to localSystemAction', () async {
      final decision = await firewall.evaluate('turn on do not disturb', overrideIsOnline: true);
      expect(decision.isLocal, isTrue);
      expect(decision.destination, equals(RoutingDestination.localSystemAction));
      expect(decision.localIntent?.dndEnabled, isTrue);
    });

    test('strictly routes timer, alarm, app, and media commands locally', () async {
      for (final utterance in [
        'set a timer for 5 minutes',
        'set alarm for 7:30 am',
        'open camera',
        'next track'
      ]) {
        final decision = await firewall.evaluate(utterance, overrideIsOnline: true);
        expect(decision.isLocal, isTrue, reason: 'Utterance "$utterance" must route locally');
      }
    });

    test('routes conversational query to offlineError when disconnected', () async {
      final decision = await firewall.evaluate('Explain quantum computing', overrideIsOnline: false);
      expect(decision.destination, equals(RoutingDestination.offlineError));
      expect(decision.errorMessage, contains('Internet connection required for conversational AI'));
    });

    test('routes conversational query to unconfiguredError when API key is missing', () async {
      final decision = await firewall.evaluate('What is the speed of light?', overrideIsOnline: true);
      expect(decision.destination, equals(RoutingDestination.unconfiguredError));
      expect(decision.errorMessage, contains('Please configure your Google Gemini API key'));
    });

    test('routes conversational query to cloudLlmStream when online with configured key', () async {
      await keyStore.saveApiKey(LlmProviderType.gemini, 'AIzaSyFakeGeminiKey123');
      final decision = await firewall.evaluate('What is the capital of France?', overrideIsOnline: true);
      expect(decision.isCloud, isTrue);
      expect(decision.destination, equals(RoutingDestination.cloudLlmStream));
      expect(decision.activeConfig?.apiKey, equals('AIzaSyFakeGeminiKey123'));
    });

    test('security firewall mandates explicit user confirmation if LLM suggests device actions', () {
      expect(ByokRoutingFirewall.requiresExplicitConfirmation('Sure, setting volume to 20% now'), isTrue);
      expect(ByokRoutingFirewall.requiresExplicitConfirmation('{"action": "set_volume", "value": 50}'), isTrue);
      expect(ByokRoutingFirewall.requiresExplicitConfirmation('Paris is the capital of France.'), isFalse);
    });
  });

  group('BYOK Multi-Provider Adapters Streaming Tests (Ticket 06 & 11)', () {
    test('GeminiAdapter correctly parses SSE stream chunks', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final sseData = 'data: {"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}\n\n'
            'data: {"candidates":[{"content":{"parts":[{"text":" world!"}]}}]}\n\n'
            'data: [DONE]\n\n';
        final stream = Stream.value(utf8.encode(sseData));
        return http.StreamedResponse(stream, 200);
      });

      final adapter = GeminiAdapter();
      final config = const LlmProviderConfig(
        provider: LlmProviderType.gemini,
        apiKey: 'test_gemini_key',
      );

      final tokens = <String>[];
      await for (final token in adapter.streamChatCompletion('Hello', config: config, client: mockClient)) {
        tokens.add(token);
      }

      expect(tokens.join(), equals('Hello world!'));
    });

    test('OpenAiCompatibleAdapter (Groq/OpenAI/DeepSeek) parses SSE stream chunks', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final sseData = 'data: {"choices":[{"delta":{"content":"Fast"}}]}\n\n'
            'data: {"choices":[{"delta":{"content":" streaming"}}]}\n\n'
            'data: [DONE]\n\n';
        final stream = Stream.value(utf8.encode(sseData));
        return http.StreamedResponse(stream, 200);
      });

      final adapter = OpenAiCompatibleAdapter(LlmProviderType.groq);
      final config = const LlmProviderConfig(
        provider: LlmProviderType.groq,
        apiKey: 'gsk_testGroqKey',
      );

      final tokens = <String>[];
      await for (final token in adapter.streamChatCompletion('Test', config: config, client: mockClient)) {
        tokens.add(token);
      }

      expect(tokens.join(), equals('Fast streaming'));
    });

    test('AnthropicAdapter parses SSE stream chunks', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final sseData = 'event: content_block_delta\n'
            'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Claude"}}\n\n'
            'event: content_block_delta\n'
            'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" here"}}\n\n';
        final stream = Stream.value(utf8.encode(sseData));
        return http.StreamedResponse(stream, 200);
      });

      final adapter = AnthropicAdapter();
      final config = const LlmProviderConfig(
        provider: LlmProviderType.anthropic,
        apiKey: 'sk-ant-testKey',
      );

      final tokens = <String>[];
      await for (final token in adapter.streamChatCompletion('Hi', config: config, client: mockClient)) {
        tokens.add(token);
      }

      expect(tokens.join(), equals('Claude here'));
    });

    test('ByokGateway supports stream cancellation', () async {
      final mockClient = MockClient.streaming((request, bodyStream) async {
        final stream = Stream.periodic(
          const Duration(milliseconds: 50),
          (i) => utf8.encode('data: {"choices":[{"delta":{"content":"chunk$i "}}]}\n\n'),
        );
        return http.StreamedResponse(stream, 200);
      });

      final keyStore = ByokKeyStore();
      await keyStore.setActiveProvider(LlmProviderType.openai);
      await keyStore.saveApiKey(LlmProviderType.openai, 'sk-test');

      final gateway = ByokGateway(keyStore: keyStore);
      final session = await gateway.streamConversationalQuery(
        'Stream me',
        overrideIsOnline: true,
        client: mockClient,
      );

      final received = <String>[];
      final sub = session.tokenStream.listen((chunk) {
        received.add(chunk);
        if (received.length >= 2) {
          session.cancel();
        }
      });

      await Future.delayed(const Duration(milliseconds: 200));
      await sub.cancel();

      expect(received.length, equals(2));
    });

    test('switching active provider routes without restart', () async {
      final keyStore = ByokKeyStore();
      await keyStore.saveApiKey(LlmProviderType.gemini, 'gemini_k');
      await keyStore.saveApiKey(LlmProviderType.anthropic, 'anthropic_k');

      await keyStore.setActiveProvider(LlmProviderType.gemini);
      var config = await keyStore.getActiveConfig();
      expect(config?.provider, equals(LlmProviderType.gemini));
      expect(config?.apiKey, equals('gemini_k'));

      await keyStore.setActiveProvider(LlmProviderType.anthropic);
      config = await keyStore.getActiveConfig();
      expect(config?.provider, equals(LlmProviderType.anthropic));
      expect(config?.apiKey, equals('anthropic_k'));
    });
  });
}
