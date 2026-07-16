<script setup>
import { onMounted, ref } from 'vue'
import api from '../api'
import MapaSectores from '../components/MapaSectores.vue'

/**
 * Mapa territorial con dos vistas:
 * - Pendientes: agrupacion espacial de tus tareas pendientes (pregunta 5).
 * - Completadas: los radios de 2 y 5 km y cuantas tareas completaste en cada
 *   zona, que es lo que responden las preguntas 3 y 7.
 */
const sectores = ref([])
const perfil = ref(null)
const clusters = ref([])
const pendientesPorZona = ref([])
const completadas = ref([])
const modo = ref('pendientes')
const cargando = ref(true)
const error = ref('')

onMounted(async () => {
  const rutas = [
    '/sectores',
    '/usuarios/me',
    '/estadisticas/clusters-pendientes',
    '/estadisticas/pendientes-por-zona',
    '/estadisticas/completadas-por-zona',
  ]
  const res = await Promise.allSettled(rutas.map((r) => api.get(r)))
  const dato = (i) => (res[i].status === 'fulfilled' ? res[i].value.data : null)

  sectores.value = dato(0) || []
  perfil.value = dato(1)
  clusters.value = dato(2) || []
  pendientesPorZona.value = dato(3) || []
  completadas.value = dato(4) || []

  if (res.some((r) => r.status === 'rejected')) {
    error.value = 'Parte del mapa no se pudo cargar.'
  }
  cargando.value = false
})
</script>

<template>
  <section>
    <div class="pagina-cabecera">
      <div>
        <h1>Mapa</h1>
        <p class="eyebrow">
          Marcadores: zonas de operaciones · Punto azul: tu ubicación registrada
        </p>
      </div>
    </div>

    <p v-if="cargando" class="vacio">Cargando mapa…</p>

    <div v-else class="panel">
      <p v-if="error" class="vacio">{{ error }}</p>

      <div class="stat-radios">
        <button
          class="filtro-boton"
          :class="{ activo: modo === 'pendientes' }"
          @click="modo = 'pendientes'"
        >
          Tareas pendientes
        </button>
        <button
          class="filtro-boton"
          :class="{ activo: modo === 'completadas' }"
          @click="modo = 'completadas'"
        >
          Tareas completadas
        </button>
      </div>

      <MapaSectores
        :sectores="sectores"
        :usuario="perfil"
        :clusters="clusters"
        :pendientes-por-zona="pendientesPorZona"
        :completadas="completadas"
        :modo="modo"
      />
    </div>
  </section>
</template>
