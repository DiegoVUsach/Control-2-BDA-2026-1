// src/services/api.ts

const API_URL = 'http://localhost:8080/api'; // Changed from https if needed, wait, original had https://localhost:8080/api ? Let's verify

export interface Usuario {
  idUsuario: number;
  nombreUsuario: string;
}

export interface AuthResponse {
  token: string;
  id: number;
  nombreUsuario: string;
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
  async login(nombreUsuario: string, contrasena: string) {
    const data = await apiRequest<AuthResponse>('/auth/login', 'POST', { nombreUsuario, contrasena });
    if (data.token) localStorage.setItem('auth_token', data.token);
    return data;
  },
  register(data: { nombreUsuario: string; contrasena: string; direccion: string; latitud: number; longitud: number }) {
    return apiRequest<any>('/auth/register', 'POST', data);
  },
  getMe() {
    return apiRequest<Usuario>('/usuarios/me');
  },
};

