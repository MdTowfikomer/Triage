import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:triage_decision/action_funnel.dart';
import 'package:triage_server/src/services/action_router_service.dart';

Map<String, dynamic> call(String name, Map<String, dynamic> arguments) => {
  'choices': [
    {
      'message': {
        'tool_calls': [
          {
            'function': {'name': name, 'arguments': jsonEncode(arguments)},
          },
        ],
      },
    },
  ],
};

void main() {
  test(
    'broad speech uses Laya domain probability after a valid model call',
    () async {
      const text = 'The customer accepted our terms';
      final action = await ActionRouterService(
        layaUrl: Uri.parse('http://localhost/v1/systemone'),
        toolBaseUrl: Uri.parse('http://localhost/v1'),
        model: 'test',
        post: (uri, payload, key, timeout) async =>
            uri.path.endsWith('systemone')
            ? {
                'answers': {
                  'domain': {
                    'choice': 'inbox_item',
                    'answer_confidence': .97,
                    'confidence': .81,
                  },
                },
              }
            : call('add_note', {
                'title': 'Customer terms accepted',
                'body': text,
              }),
      ).route(text);
      expect(action.title, 'Customer terms accepted');
      expect(action.confidence, .97);
      expect(action.reviewReason, isNull);
      expect(action.routingSource, 'laya+tool_model');
    },
  );
  test(
    'an unconfident domain cannot clear uncertainty despite valid slots',
    () async {
      const text = 'The customer accepted our terms';
      final action = await ActionRouterService(
        layaUrl: Uri.parse('http://localhost/v1/systemone'),
        toolBaseUrl: Uri.parse('http://localhost/v1'),
        model: 'test',
        post: (uri, payload, key, timeout) async =>
            uri.path.endsWith('systemone')
            ? {
                'answers': {
                  'domain': {
                    'choice': 'inbox_item',
                    'answer_confidence': .6,
                    'low_confidence': true,
                  },
                },
              }
            : call('add_note', {
                'title': 'Customer terms accepted',
                'body': text,
              }),
      ).route(text);
      expect(action.title, 'Customer terms accepted');
      expect(action.confidence, .05);
      expect(action.reviewReason, isNotEmpty);
    },
  );
  test('multiple model calls retain the full capture for review', () async {
    final response = call('add_task', {'title': 'Email Sarah'});
    (response['choices'][0]['message']['tool_calls'] as List).add({
      'function': {'name': 'add_shopping_item', 'arguments': '{"item":"milk"}'},
    });
    final action = await ActionRouterService(
      toolBaseUrl: Uri.parse('http://localhost/v1'),
      model: 'test',
      post: (uri, payload, key, timeout) async => response,
    ).route('Email Sarah');
    expect(action.title, 'Email Sarah');
    expect(action.reviewReason, contains('Multiple requests'));
    expect(action.confidence, .05);
  });
  final fixtures = [
    (
      'Remind me to call the dentist tomorrow at 3pm',
      'add_reminder',
      'Call the dentist',
      'tomorrow at 3pm',
    ),
    (
      'Buy eggs, milk, and bread from Whole Foods',
      'add_shopping_item',
      'Eggs, milk, and bread',
      null,
    ),
    (
      'The client meeting went well, they approved the Q4 budget',
      'add_note',
      'The client meeting went well, they approved the Q4 budget',
      null,
    ),
    (
      'Fix the login bug by Friday, high priority',
      'add_task',
      'Fix the login bug',
      'Friday',
    ),
    (
      'What if we made the onboarding a game?',
      'log_idea',
      'What if we made the onboarding a game',
      null,
    ),
    (
      'Um, so, email Sarah about the proposal, and oh, grab milk',
      'add_shopping_item',
      'Um, so, email Sarah about the proposal, and oh, grab milk',
      null,
    ),
  ];
  for (final fixture in fixtures) {
    test('daily utterance: ${fixture.$1}', () async {
      final action = await ActionRouterService().route(fixture.$1);
      expect(action.actionType, 'inbox_item');
      expect(action.tool, fixture.$2);
      expect(action.title, fixture.$3);
      expect(action.dateText, fixture.$4);
      expect(action.routingSource, 'deterministic');
      if (fixture.$1.startsWith('Um')) {
        expect(action.reviewReason, contains('Multiple requests'));
        expect(action.confidence, lessThan(.1));
        expect(action.body, fixture.$1);
      } else {
        expect(action.reviewReason, isNull);
        expect(action.confidence, greaterThanOrEqualTo(.1));
      }
      if (fixture.$1.startsWith('Fix')) expect(action.priority, 'high');
      if (fixture.$1.startsWith('Buy')) {
        expect(action.body, 'Store: Whole Foods');
      }
    });
  }
  test('app launches require a whole explicit, allowlisted command', () async {
    for (final app in supportedApps) {
      final action = await ActionRouterService().route('Open $app');
      expect(action.actionType, 'device_action');
      expect(action.appName, app);
      expect(action.tool, 'open_app');
    }
    for (final text in [
      "Don't open WhatsApp",
      'Note that I opened WhatsApp',
      'Open WhatsApp and email Sarah',
      'Open Netflix',
    ]) {
      expect(
        (await ActionRouterService().route(text)).actionType,
        'inbox_item',
      );
    }
  });
  test(
    'empty, unrelated and overlong captures stay nonempty and reviewable',
    () async {
      for (final text in ['', 'What is the weather?', 'x' * 17000]) {
        final action = await ActionRouterService().route(text);
        expect(action.title, isNotEmpty);
        expect(action.title.length, lessThanOrEqualTo(500));
        expect(action.reviewReason, isNotEmpty);
        expect(action.confidence, lessThan(.1));
      }
    },
  );
  test(
    'quantity, dates, recurrence and nonurgent priority survive extraction',
    () async {
      final shopping = await ActionRouterService().route(
        'Buy 3 bananas from Whole Foods',
      );
      expect(shopping.title, 'Bananas');
      expect(shopping.body, 'Quantity: 3 · Store: Whole Foods');
      final task = await ActionRouterService().route(
        'Fix the login bug tomorrow 15:00, not urgent',
      );
      expect(task.tool, 'add_task');
      expect(task.priority, 'low');
      expect(task.dateText, 'tomorrow 15:00');
      final reminder = await ActionRouterService().route(
        'Remind me to stretch tomorrow 9am daily',
      );
      expect(reminder.recurring, 'daily');
      expect(reminder.title, 'Stretch');
      expect(reminder.dateText, 'tomorrow 9am');
    },
  );
  test('Laya domain narrows the tool schema before extraction', () async {
    final urls = <String>[];
    final service = ActionRouterService(
      layaUrl: Uri.parse('http://localhost/v1/systemone'),
      toolBaseUrl: Uri.parse('http://localhost/v1'),
      model: 'test-lfm',
      post: (uri, payload, key, timeout) async {
        urls.add(uri.path);
        if (uri.path.endsWith('systemone')) {
          expect(payload['questions'], contains('domain'));
          return {
            'answers': {
              'domain': {'choice': 'device_action', 'answer_confidence': .96},
            },
          };
        }
        expect((payload['tools'] as List).length, 1);
        expect(payload['tool_choice'], 'required');
        return call('open_app', {'appName': 'whatsapp'});
      },
    );
    final action = await service.route('Open WhatsApp');
    expect(action.routingSource, 'laya+tool_model');
    expect(action.appName, 'whatsapp');
    expect(urls, ['/v1/systemone', '/v1/chat/completions']);
  });
  test(
    'native OpenAI tool calls populate slots and preserve device-relative dates',
    () async {
      final action = await ActionRouterService(
        toolBaseUrl: Uri.parse('http://localhost/v1'),
        model: 'test-lfm',
        post: (uri, payload, key, timeout) async => call('add_task', {
          'title': 'Fix login',
          'priority': 'high',
          'due_date': 'Friday',
        }),
      ).route('Fix the login bug by Friday, high priority');
      expect(action.title, 'Fix login');
      expect(action.priority, 'high');
      expect(action.dateText, 'Friday');
      expect(action.routingSource, 'deterministic+tool_model');
    },
  );
  test(
    'LFM special-token JSON format is accepted without executing text',
    () async {
      final action = ActionRouterService.decodeToolResult(
        {
          'choices': [
            {
              'message': {
                'content':
                    '<|tool_call_start|>[{"name":"add_task","arguments":{"title":"Fix login","priority":"high"}}]<|tool_call_end|>',
              },
            },
          ],
        },
        'inbox_item',
        'Fix login, high priority',
        FunnelAction.local('Fix login, high priority'),
      );
      expect(action.title, 'Fix login');
      expect(action.priority, 'high');
    },
  );
  test(
    'provider failures, malformed arguments and unknown tools fall back',
    () async {
      for (final response in [
        <String, dynamic>{},
        call('delete_everything', {}),
        call('add_task', {'title': '', 'priority': 'highest'}),
      ]) {
        final action = await ActionRouterService(
          toolBaseUrl: Uri.parse('http://localhost/v1'),
          model: 'test',
          post: (uri, payload, key, timeout) async => response,
        ).route('Fix login, high priority');
        expect(action.title, 'Fix login');
        expect(action.tool, 'add_task');
        expect(action.routingSource, 'deterministic');
      }
      final action = await ActionRouterService(
        layaUrl: Uri.parse('http://localhost/v1/systemone'),
        post: (uri, payload, key, timeout) async =>
            throw const SocketException('offline'),
      ).route('Buy milk');
      expect(action.title, 'Milk');
    },
  );
  test(
    'slow model requests time out and still return a usable action',
    () async {
      final action = await ActionRouterService(
        budgetMs: 25,
        toolBaseUrl: Uri.parse('http://localhost/v1'),
        model: 'test',
        post: (uri, payload, key, timeout) =>
            Completer<Map<String, dynamic>>().future,
      ).route('Buy milk');
      expect(action.title, 'Milk');
      expect(action.routingSource, 'deterministic');
    },
  );
  test(
    'model cannot launch an app not explicitly requested by the speaker',
    () async {
      final action = await ActionRouterService(
        layaUrl: Uri.parse('http://localhost/v1/systemone'),
        toolBaseUrl: Uri.parse('http://localhost/v1'),
        model: 'test',
        post: (uri, payload, key, timeout) async =>
            uri.path.endsWith('systemone')
            ? {
                'answers': {
                  'domain': {
                    'choice': 'device_action',
                    'answer_confidence': .99,
                  },
                },
              }
            : call('open_app', {'appName': 'whatsapp'}),
      ).route('Email Sarah about WhatsApp');
      expect(action.actionType, 'inbox_item');
      expect(action.appName, isNull);
    },
  );
  test(
    'invented dates require review and preserve the spoken anchor',
    () async {
      final action = await ActionRouterService(
        toolBaseUrl: Uri.parse('http://localhost/v1'),
        model: 'test',
        post: (uri, payload, key, timeout) async =>
            call('add_task', {'title': 'Fix login', 'due_date': '2030-10-14'}),
      ).route('Fix login by Friday');
      expect(action.dateText, 'Friday');
      expect(action.reviewReason, contains('date needs review'));
      expect(action.confidence, lessThan(.1));
    },
  );
  test(
    'HTTP adapter sends bearer and JSON, enforces response/error contracts',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-key',
        );
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'state': '[EMAIL]',
        });
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"answers":{}}');
        await request.response.close();
      });
      try {
        final response = await ActionRouterService.postJson(
          Uri.parse('http://127.0.0.1:${server.port}/v1/systemone'),
          {'state': '[EMAIL]'},
          'test-key',
          const Duration(seconds: 2),
        );
        expect(response['answers'], isEmpty);
      } finally {
        await subscription.cancel();
        await server.close(force: true);
      }
    },
  );
}
