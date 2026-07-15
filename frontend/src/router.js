import { createRouter, createWebHistory } from 'vue-router'
import { sesion } from './auth'
import LoginView from './views/LoginView.vue'
import RegistroView from './views/RegistroView.vue'
import TareasView from './views/TareasView.vue'
import EstadisticasView from './views/EstadisticasView.vue'
import MapaView from './views/MapaView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/tareas' },
    { path: '/login', component: LoginView, meta: { publica: true } },
    { path: '/registro', component: RegistroView, meta: { publica: true } },
    { path: '/tareas', component: TareasView },
    { path: '/estadisticas', component: EstadisticasView },
    { path: '/mapa', component: MapaView },
  ],
})

/**
 * Guardia de navegacion (usabilidad; la seguridad real es el 401 del backend).
 */
router.beforeEach((to) => {
  if (!to.meta.publica && !sesion.token) return '/login'
  if (to.meta.publica && sesion.token) return '/tareas'
})

export default router
