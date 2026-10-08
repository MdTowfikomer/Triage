import 'dart:js_interop';

@JS('triageRedact.redactMany')
external JSPromise<JSArray<JSString>> _redactMany(JSArray<JSString> inputs);

Future<List<String>> redactAll(List<String> inputs) async => (await _redactMany(
  inputs.map((text) => text.toJS).toList().toJS,
).toDart).toDart.map((text) => text.toDart).toList();
