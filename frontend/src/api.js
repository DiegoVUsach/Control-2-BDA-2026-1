import axios from 'axios'

/**
 * Cliente HTTP unico de la aplicacion.
 * - baseURL '/api': en desarrollo Vite lo redirige al backend (proxy),
 *   en produccion nginx hace lo mismo. Asi el codigo no cambia.
 * - Interceptor de peticion: adjunta el JWT en el header Authorization.
 * - Interceptor de respuesta: si el backend responde 401 (token invalido
 *   o expirado) se cierra la sesion y se vuelve al login.
 */
const api = axios.create({ baseURL: '/api' })

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  (respuesta) => respuesta,
  (error) => {
    const enLogin = window.location.pathname.startsWith('/login')
    if (error.response && error.response.status === 401 && !enLogin) {
      localStorage.removeItem('token')
      localStorage.removeItem('usuario')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default api
