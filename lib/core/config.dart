const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080/api',
);

const sessionTimeout = Duration(minutes: 3);
const sessionWarning = Duration(seconds: 30);
const sessionCheckDelay = Duration(seconds: 60);
