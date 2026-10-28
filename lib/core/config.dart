const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

const webClientPort = int.fromEnvironment('WEB_PORT', defaultValue: 5555);
