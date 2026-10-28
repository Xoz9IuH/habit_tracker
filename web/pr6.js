const TOKEN_KEY = 'flutter.auth_access_token';
const REFRESH_KEY = 'flutter.auth_refresh_token';
const ROLE_KEY = 'auth_role_override';

function raw(key) {
  return window.localStorage.getItem(key);
}

function token(key) {
  const value = raw(key);
  if (!value) return '';
  try {
    const parsed = JSON.parse(value);
    return typeof parsed === 'string' ? parsed : '';
  } catch (e) {
    return value.replace(/"/g, '');
  }
}

function hideSplash() {
  if (window.habitTrackerSplash) window.habitTrackerSplash.hide();
}

function showSplashError(text) {
  if (window.habitTrackerSplash) window.habitTrackerSplash.fail(text);
}

window.pr6 = {
  reload() {
    window.location.reload();
  },
  loggedIn() {
    return Boolean(token(TOKEN_KEY));
  },
  clearSession() {
    window.localStorage.removeItem(TOKEN_KEY);
    window.localStorage.removeItem(REFRESH_KEY);
    window.localStorage.removeItem(ROLE_KEY);
  },
  apiBase() {
    return window.location.origin + '/api';
  },
  async login(username, password) {
    const response = await fetch(this.apiBase() + '/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });
    if (!response.ok) return 'HTTP ' + response.status + ' ' + (await response.text());
    const data = await response.json();
    window.localStorage.setItem(TOKEN_KEY, JSON.stringify(data.accessToken));
    window.localStorage.setItem(REFRESH_KEY, JSON.stringify(data.refreshToken));
    return 'ok';
  },
  setRoleOverride(role) {
    window.localStorage.setItem(ROLE_KEY, role);
  },
  clearRoleOverride() {
    window.localStorage.removeItem(ROLE_KEY);
  },
  async deleteHabit(id) {
    const response = await fetch(this.apiBase() + '/habits/' + id, {
      method: 'DELETE',
      headers: { Authorization: 'Bearer ' + token(TOKEN_KEY) },
    });
    return response.status + ' ' + (await response.text());
  },
  async listHabits() {
    const response = await fetch(this.apiBase() + '/habits?size=3', {
      headers: { Authorization: 'Bearer ' + token(TOKEN_KEY) },
    });
    return response.status;
  },
  storage(name) {
    const value = raw(name);
    return value === null ? 'null' : value.slice(0, 80);
  },
  hideSplash,
  showSplashError,
};

window.addEventListener('error', function (event) {
  if (event && event.message) showSplashError('Ошибка: ' + event.message);
});
