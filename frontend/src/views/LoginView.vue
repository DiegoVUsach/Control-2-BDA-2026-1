<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import api from '../api'
import { guardarSesion } from '../auth'

const router = useRouter()
const form = reactive({ nombreUsuario: '', contrasena: '' })
const error = ref('')
const cargando = ref(false)

async function entrar() {
  error.value = ''
  cargando.value = true
  try {
    const { data } = await api.post('/auth/login', form)
    guardarSesion(data)
    router.push('/tareas')
  } catch (e) {
    error.value = e.response?.data?.error || 'No se pudo iniciar sesión. Revisa tus datos.'
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="acceso">
    <div class="acceso-panel">
      <h1 class="acceso-titulo">Gestión de tareas</h1>
      <p class="acceso-sub">Tareas georreferenciadas por zonas de operación</p>

      <form @submit.prevent="entrar">
        <label>
          Nombre de usuario
          <input v-model="form.nombreUsuario" autocomplete="username" />
        </label>
        <label>
          Contraseña
          <input type="password" v-model="form.contrasena" autocomplete="current-password" />
        </label>
        <p v-if="error" class="mensaje-error">{{ error }}</p>
        <button class="boton boton-primario ancho" :disabled="cargando">
          {{ cargando ? 'Entrando…' : 'Iniciar sesión' }}
        </button>
      </form>

      <p class="acceso-alt">
        ¿No tienes cuenta? <router-link to="/registro">Regístrate aquí</router-link>
      </p>
      <p class="acceso-demo">Datos de prueba: admin / admin123</p>
    </div>
  </div>
</template>
