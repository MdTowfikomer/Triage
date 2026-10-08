import 'package:flutter/services.dart';

const _redactionChannel = MethodChannel('triage.redact');

Future<List<String>> redactAll(List<String> inputs) async {
  final result = await _redactionChannel.invokeListMethod<String>('redact', {
    'texts': inputs,
  });
  if (result == null || result.length != inputs.length) {
    throw StateError('On-device PII redaction returned an invalid result.');
  }
  return result;
}
