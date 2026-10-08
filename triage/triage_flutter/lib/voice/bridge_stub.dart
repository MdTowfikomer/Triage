Future<String> invoke(String request) => Future.error(
  UnsupportedError(
    'Voice capture is verified on Flutter Web only. Use typed capture on this platform.',
  ),
);
