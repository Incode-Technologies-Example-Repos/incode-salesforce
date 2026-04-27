const BASE_URL = import.meta.env.VITE_INCODE_API_URL;
const API_KEY = import.meta.env.VITE_INCODE_API_KEY;
const CONFIGURATION_ID = import.meta.env.VITE_INCODE_CONFIGURATION_ID;

const baseHeaders = {
  'Content-Type': 'application/json',
  'api-version': '1.0',
  'x-api-key': API_KEY,
};

async function request(path, options = {}) {
  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: { ...baseHeaders, ...options.headers },
  });
  const body = await res.json();
  if (!res.ok) {
    throw new Error(body?.message || `Request failed: ${res.status} ${path}`);
  }
  return body;
}

export async function startSession() {
  return request('/omni/start', {
    method: 'POST',
    body: JSON.stringify({ language: 'en-US', configurationId: CONFIGURATION_ID }),
  });
}

export async function submitEkyb(sessionToken, payload) {
  return request('/omni/externalVerification/ekyb', {
    method: 'POST',
    headers: { 'X-Incode-Hardware-Id': sessionToken },
    body: JSON.stringify({ plugins: ['ekyb'], ...payload }),
  });
}

export async function finishSession(sessionToken) {
  return request('/omni/finish-status', {
    method: 'GET',
    headers: { 'X-Incode-Hardware-Id': sessionToken },
  });
}
