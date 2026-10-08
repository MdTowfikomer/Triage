import 'dart:async';

Future<String> invokeSpike(String request) => Future.error(
      UnsupportedError(
        'This runner uses the verified Web WASM runtime. Run with Chrome or a web server.',
      ),
    );
