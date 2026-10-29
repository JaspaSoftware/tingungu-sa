import { auth } from './firebase';

export async function apiFetch(url, options = {}) {
  const user = auth.currentUser;
  if (!user) {
    throw new Error('Authentication required. Please sign in again.');
  }

  const token = await user.getIdToken();
  const headers = new Headers(options.headers);
  headers.set('Authorization', `Bearer ${token}`);

  const isFormData = typeof FormData !== 'undefined' && options.body instanceof FormData;
  if (options.body && !isFormData && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json');
  }

  const response = await fetch(url, { ...options, headers });

  if (response.status === 401) {
    throw new Error('Your session has expired. Please sign in again.');
  }

  if (response.status === 403) {
    throw new Error('Administrator access is required to perform this action.');
  }

  return response;
}
