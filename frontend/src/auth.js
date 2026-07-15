import { reactive } from 'vue'

/**
 * Estado de sesion compartido por toda la aplicacion (patron composable).
 * Se persiste en localStorage para sobrevivir recargas de pagina.
 */
export const sesion = reactive({
  token: localStorage.getItem('token'),
  usuario: JSON.parse(localStorage.getItem('usuario') || 'null'),
})

export function guardarSesion(datos) {
  sesion.token = datos.token
  sesion.usuario = { id: datos.id, nombreUsuario: datos.nombreUsuario }
  localStorage.setItem('token', datos.token)
  localStorage.setItem('usuario', JSON.stringify(sesion.usuario))
}

export function cerrarSesion() {
  sesion.token = null
  sesion.usuario = null
  localStorage.removeItem('token')
  localStorage.removeItem('usuario')
}
