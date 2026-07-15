<script setup>
import { onMounted, reactive, ref } from 'vue'
import api from '../api'
import MapaSelector from '../components/MapaSelector.vue'
import { obtenerPosicionGPS } from '../gps'

/**
 * Registro (Requisito 1): la "direccion geografica" es el punto PostGIS.
 * Flujo: al entrar se pide permiso de GPS; si se concede, el punto queda
 * pre-marcado y el mapa centrado ahi para ajustarlo con un clic; si se
 * rechaza, el mapa queda centrado en Santiago y el punto se marca a mano.
 */
const form = reactive({ nombreUsuario: '', contrasena: '' })
const punto = ref(null)
const estadoGPS = ref('pidiendo') // pidiendo | ok | denegado
const error = ref('')
const exito = ref(false)
const cargando = ref(false)

async function intentarGPS() {
  estadoGPS.value = 'pidiendo'
  try {
    punto.value = await obtenerPosicionGPS()
    estadoGPS.value = 'ok'
  } catch {
    estadoGPS.value = 'denegado'
  }
}

onMounted(intentarGPS)

async function registrar() {
  error.value = ''
  if (!form.nombreUsuario.trim() || !form.contrasena) {
    error.value = 'Completa nombre de usuario y contraseña.'
    return
  }
  if (!punto.value) {
    error.value = 'Marca tu ubicación en el mapa (un clic sobre el punto).'
    return
  }
  cargando.value = true
  try {
    await api.post('/auth/register', {
      nombreUsuario: form.nombreUsuario.trim(),
      contrasena: form.contrasena,
      latitud: punto.value.lat,
      longitud: punto.value.lng,
    })
    exito.value = true
  } catch (e) {
    error.value = e.response?.data?.error || 'No se pudo completar el registro.'
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="acceso">
    <div class="acceso-panel acceso-panel-grande">
      <p class="eyebrow">Crear cuenta</p>
      <h1 class="acceso-titulo">Registro</h1>

      <template v-if="!exito">
        <form @submit.prevent="registrar">
          <div class="fila">
            <label>
              Nombre de usuario
              <input v-model="form.nombreUsuario" autocomplete="username" />
            </label>
            <label>
              Contraseña
              <input type="password" v-model="form.contrasena" autocomplete="new-password" />
            </label>
          </div>

          <label>
            Tu ubicación
            <span v-if="estadoGPS === 'pidiendo'" class="ayuda">
              Solicitando tu ubicación GPS…
            </span>
            <span v-else-if="estadoGPS === 'ok'" class="ayuda">
              Punto GPS cargado. Ajústalo con un clic en el mapa si es necesario.
            </span>
            <span v-else class="ayuda">
              GPS no disponible o rechazado: marca tu punto con un clic
              (mapa centrado en Santiago).
            </span>
          </label>
          <button
            v-if="estadoGPS === 'denegado'"
            type="button"
            class="boton boton-secundario"
            @click="intentarGPS"
          >
            Reintentar GPS
          </button>
          <MapaSelector v-model="punto" />
          <p v-if="punto" class="coordenadas">
            Punto seleccionado: {{ punto.lat }}, {{ punto.lng }}
          </p>

          <p v-if="error" class="mensaje-error">{{ error }}</p>
          <button class="boton boton-primario ancho" :disabled="cargando">
            {{ cargando ? 'Registrando…' : 'Crear cuenta' }}
          </button>
        </form>
        <p class="acceso-alt">
          ¿Ya tienes cuenta? <router-link to="/login">Inicia sesión</router-link>
        </p>
      </template>

      <template v-else>
        <p class="mensaje-exito">
          Cuenta creada. Tu ubicación quedó registrada como punto geoespacial.
        </p>
        <router-link class="boton boton-primario ancho centrado" to="/login">
          Ir a iniciar sesión
        </router-link>
      </template>
    </div>
  </div>
</template>
