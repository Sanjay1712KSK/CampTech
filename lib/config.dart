class Config {
  // Override with --dart-define=API_BASE_URL=https://your-backend.example.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
}
