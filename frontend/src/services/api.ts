// src/services/api.ts

const API_URL = 'http://localhost:8080/api';

export interface Usuario {
  idUsuario: number;
  nombreUsuario: string;
}

export interface AuthResponse {
  token: string;
  id: number;
  nombreUsuario: string;
}

export interface Sector {
  idSector: number;
  nombre: string;
  latitud: number;
  longitud: number;
}

export interface Tarea {
  idTarea: number;
  titulo: string;
  descripcion: string;
  fechaVencimiento: string;
  completada: boolean;
  fechaCompletada: string | null;
  idSector: number;
  nombreSector: string;
  latitudSector: number;
  longitudSector: number;
}

export interface Notificacion {
  idNotificacion: number;
  mensaje: string;
  fechaCreacion: string;
  leida: boolean;
  idTarea: number;
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
    if (response.status === 401) {
      localStorage.removeItem('auth_token');
      window.location.reload(); // Force re-render to login view if token expires
    }
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

export const tareaService = {
  listar(estado?: string, buscar?: string) {
    const params = new URLSearchParams();
    if (estado) params.append('estado', estado);
    if (buscar) params.append('buscar', buscar);
    const qs = params.toString() ? `?${params.toString()}` : '';
    return apiRequest<Tarea[]>(`/tareas${qs}`);
  },
  crear(data: { titulo: string; descripcion: string; fechaVencimiento: string; idSector: number }) {
    return apiRequest<Tarea>('/tareas', 'POST', data);
  },
  editar(id: number, data: { titulo: string; descripcion: string; fechaVencimiento: string; idSector: number }) {
    return apiRequest<Tarea>(`/tareas/${id}`, 'PUT', data);
  },
  eliminar(id: number) {
    return apiRequest<void>(`/tareas/${id}`, 'DELETE');
  },
  completar(id: number) {
    return apiRequest<Tarea>(`/tareas/${id}/completar`, 'PATCH');
  }
};

export const sectorService = {
  listar() {
    return apiRequest<Sector[]>('/sectores');
  }
};

export const notificacionService = {
  listar() {
    return apiRequest<Notificacion[]>('/notificaciones');
  },
  marcarLeida(id: number) {
    return apiRequest<void>(`/notificaciones/${id}/leer`, 'PATCH');
  }
};

export const estadisticaService = {
  tareasPorSector: () => apiRequest<any[]>('/estadisticas/tareas-por-sector'),
  tareaMasCercana: () => apiRequest<any[]>('/estadisticas/tarea-mas-cercana'),
  sectorMasCompletadas: (radioKm: number = 2) => apiRequest<any[]>(`/estadisticas/sector-mas-completadas?radioKm=${radioKm}`),
  promedioDistancia: () => apiRequest<any[]>('/estadisticas/promedio-distancia'),
  clustersPendientes: (k: number = 3) => apiRequest<any[]>(`/estadisticas/clusters-pendientes?k=${k}`),
  tareasPorUsuarioYSector: () => apiRequest<any[]>('/estadisticas/tareas-por-usuario-sector'),
  promedioDistanciaUsuarios: () => apiRequest<any[]>('/estadisticas/promedio-distancia-usuarios')
};

