// src/services/api.ts — simplified for single-login frontend

const API_URL = 'https://localhost:8080/api';

export interface Usuario {
  idUsuario?: number;
  username: string;
}

export interface AuthResponse {
  token: string;
}

async function apiRequest<T>(endpoint: string, method: string = 'GET', body?: any): Promise<T> {
  const token = localStorage.getItem('auth_token');
  const headers: HeadersInit = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  const response = await fetch(`${API_URL}${endpoint}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!response.ok) {
    if (response.status === 401) localStorage.removeItem('auth_token');
    const errorText = await response.text();
    throw new Error(errorText || 'Error en el servidor');
  }

  const contentType = response.headers.get('content-type');
  if (contentType && contentType.includes('application/json')) {
    return response.json();
  } else {
    return response.text() as unknown as T;
  }
}

export const authService = {
  async login(username: string, password: string) {
    const data = await apiRequest<AuthResponse>('/auth/login', 'POST', { username, password });
    localStorage.setItem('auth_token', data.token);
    return data;
  },
  register(data: { username: string; password: string; latitude?: number; longitude?: number }) {
    return apiRequest<string>('/auth/register', 'POST', data);
  },
  getMe() {
    return apiRequest<Usuario>('/usuarios/me');
  },
};

