<script setup>
import { useRouter } from 'vue-router'
import { sesion, cerrarSesion } from '../auth'

const router = useRouter()

function salir() {
  cerrarSesion()
  router.push('/login')
}
</script>

<template>
  <header class="nav">
    <span class="nav-titulo">Gestión de tareas</span>
    <nav class="nav-enlaces">
      <router-link to="/tareas">Mis tareas</router-link>
      <router-link to="/estadisticas">Estadísticas</router-link>
      <router-link to="/mapa">Mapa</router-link>
    </nav>
    <div class="nav-usuario">
      <span class="nav-nombre">{{ sesion.usuario?.nombreUsuario }}</span>
      <button class="boton boton-secundario" @click="salir">Cerrar sesión</button>
    </div>
  </header>
</template>
