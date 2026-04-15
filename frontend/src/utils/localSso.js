const LOCAL_SSO_KEY = 'authvault.localSso';

const safeParseJson = (rawValue) => {
  try {
    return JSON.parse(rawValue);
  } catch {
    return null;
  }
};

const decodeJwtPayload = (token) => {
  if (!token || typeof token !== 'string') {
    return null;
  }

  const parts = token.split('.');
  if (parts.length < 2) {
    return null;
  }

  try {
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(base64.length + ((4 - (base64.length % 4)) % 4), '=');
    const json = atob(padded);
    return JSON.parse(json);
  } catch {
    return null;
  }
};

const isExpired = (expiresAt) => {
  if (!expiresAt) {
    return false;
  }

  return Date.now() >= expiresAt;
};

export const saveLocalSsoSession = ({ token, user }) => {
  if (!token || !user) {
    return;
  }

  const payload = decodeJwtPayload(token);
  const expiresAt = payload?.exp ? payload.exp * 1000 : null;

  const data = {
    token,
    user,
    savedAt: Date.now(),
    expiresAt,
  };

  localStorage.setItem(LOCAL_SSO_KEY, JSON.stringify(data));
};

export const getLocalSsoSession = () => {
  const raw = localStorage.getItem(LOCAL_SSO_KEY);

  if (!raw) {
    return null;
  }

  const parsed = safeParseJson(raw);

  if (!parsed || !parsed.token || !parsed.user) {
    localStorage.removeItem(LOCAL_SSO_KEY);
    return null;
  }

  if (isExpired(parsed.expiresAt)) {
    localStorage.removeItem(LOCAL_SSO_KEY);
    return null;
  }

  return parsed;
};

export const clearLocalSsoSession = () => {
  localStorage.removeItem(LOCAL_SSO_KEY);
};
