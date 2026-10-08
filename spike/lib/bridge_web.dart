import 'dart:js_interop';

@JS('triageSpike')
external JSPromise<JSString> _invoke(JSString request);

Future<String> invokeSpike(String request) async =>
    (await _invoke(request.toJS).toDart).toDart;
