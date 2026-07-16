<script setup>
import { computed, onMounted, ref } from 'vue'
import api from '../api'
import { sesion } from '../auth'

/**
 * Estadisticas espaciales calculadas con PostGIS.
 * Todas las metricas personales son PRIVADAS: la API las resuelve con el
 * id del usuario autenticado. El reporte "por usuario y sector" (P6 del
 * enunciado) es un agregado global que expone solo conteos.
 *
 * Se usa Promise.allSettled (y no Promise.all) a proposito: si un endpoint
 * falla, el resto de la pagina igual se muestra en vez de quedarse colgada
 * en el estado "cargando".
 */
const porSector = ref([])
const masCercana = ref(null)
const sectorTop = ref(null)
const radioKm = ref(2)
const promedio = ref(null)
const clusters = ref([])
const porUsuario = ref([])
const soloMias = ref(false)
const cargando = ref(true)
const error = ref('')

// El filtro "solo las mías" es del lado del cliente a proposito: el reporte ya
// viene agregado y es liviano. No hay dato nuevo que pedirle al servidor.
const porUsuarioFiltrado = computed(() => {
  if (!soloMias.value) return porUsuario.value
  const yo = sesion.usuario?.nombreUsuario
  return porUsuario.value.filter((f) => f.usuario === yo)
})

async function cargarSectorTop() {
  try {
    const { data } = await api.get('/estadisticas/sector-mas-completadas', {
      params: { radioKm: radioKm.value },
    })
    sectorTop.value = data[0] || null
  } catch (e) {
    sectorTop.value = null
    error.value = 'No se pudo calcular la zona con más completadas.'
  }
}

function cambiarRadio(km) {
  radioKm.value = km
  cargarSectorTop()
}

function metros(v) {
  if (v == null) return '—'
  return Number(v).toLocaleString('es-CL') + ' m'
}

onMounted(async () => {
  const rutas = [
    '/estadisticas/tareas-por-sector',
    '/estadisticas/tarea-mas-cercana',
    '/estadisticas/promedio-distancia',
    '/estadisticas/clusters-pendientes',
    '/estadisticas/tareas-por-usuario-sector',
  ]
  const res = await Promise.allSettled(rutas.map((r) => api.get(r)))
  const dato = (i) => (res[i].status === 'fulfilled' ? res[i].value.data : null)

  porSector.value = dato(0) || []
  masCercana.value = dato(1)?.[0] || null
  promedio.value = dato(2)?.[0]?.promedio_distancia_metros ?? null
  clusters.value = dato(3) || []
  porUsuario.value = dato(4) || []

  if (res.some((r) => r.status === 'rejected')) {
    error.value = 'Algunas estadísticas no se pudieron calcular.'
  }
  await cargarSectorTop()
  cargando.value = false
})
</script>

<template>
  <section>
    <div class="pagina-cabecera">
      <div>
        <h1>Estadísticas</h1>
        <p class="eyebrow">Calculadas sobre tus propias tareas</p>
      </div>
    </div>

    <p v-if="cargando" class="vacio">Calculando estadísticas espaciales…</p>

    <template v-else>
      <p v-if="error" class="vacio">{{ error }}</p>

      <div class="stats-grilla">
        <div class="stat-carta">
          <p class="stat-etiqueta">Tu tarea pendiente más cercana</p>
          <template v-if="masCercana">
            <p class="stat-valor">{{ masCercana.titulo }}</p>
            <p class="stat-detalle">
              {{ masCercana.sector }} · a {{ metros(masCercana.distancia_metros) }}
            </p>
          </template>
          <p v-else class="stat-detalle">No tienes tareas pendientes.</p>
        </div>

        <div class="stat-carta">
          <p class="stat-etiqueta">Zona con más tareas tuyas completadas cerca de ti</p>
          <div class="stat-radios">
            <button class="filtro-boton" :class="{ activo: radioKm === 2 }" @click="cambiarRadio(2)">
              Radio 2 km
            </button>
            <button class="filtro-boton" :class="{ activo: radioKm === 5 }" @click="cambiarRadio(5)">
              Radio 5 km
            </button>
          </div>
          <template v-if="sectorTop">
            <p class="stat-valor">{{ sectorTop.sector }}</p>
            <p class="stat-detalle">
              {{ sectorTop.tareas_completadas }} completadas · a
              {{ metros(sectorTop.distancia_metros) }}
            </p>
          </template>
          <p v-else class="stat-detalle">Sin zonas con tareas completadas en ese radio.</p>
        </div>

        <div class="stat-carta">
          <p class="stat-etiqueta">Distancia promedio de tus tareas completadas</p>
          <p class="stat-valor">{{ metros(promedio) }}</p>
          <p class="stat-detalle">Metros reales (ST_Distance sobre geografía)</p>
        </div>
      </div>

      <div class="stats-columnas">
        <div class="panel">
          <h2>Tus tareas completadas por sector</h2>
          <table v-if="porSector.length">
            <thead>
              <tr><th>Sector (zona de operaciones)</th><th>Completadas</th></tr>
            </thead>
            <tbody>
              <tr v-for="f in porSector" :key="f.sector">
                <td>{{ f.sector }}</td>
                <td>{{ f.tareas_completadas }}</td>
              </tr>
            </tbody>
          </table>
          <p v-else class="vacio">Aún no completas tareas.</p>
        </div>

        <div class="panel">
          <h2>Dónde se concentran tus pendientes</h2>
          <p class="ayuda">
            Agrupación espacial (ST_ClusterKMeans) de tus tareas pendientes.
            Puedes verlas dibujadas en la pestaña Mapa.
          </p>
          <table v-if="clusters.length">
            <thead>
              <tr><th>Grupo</th><th>Pendientes</th><th>Zonas</th></tr>
            </thead>
            <tbody>
              <tr v-for="(c, i) in clusters" :key="c.cluster_id">
                <td>{{ i + 1 }}</td>
                <td>{{ c.tareas_pendientes }}</td>
                <td>{{ c.sectores }}</td>
              </tr>
            </tbody>
          </table>
          <p v-else class="vacio">No tienes tareas pendientes que agrupar.</p>
        </div>
      </div>

      <div class="panel">
        <h2>Reporte: tareas realizadas por cada usuario y sector</h2>
        <p class="ayuda">
          Único reporte global del sistema (pregunta 6 del enunciado). Muestra
          solo conteos agregados: no expone el contenido de tareas ajenas.
        </p>
        <div class="stat-radios">
          <button
            class="filtro-boton"
            :class="{ activo: !soloMias }"
            @click="soloMias = false"
          >
            Todos los usuarios
          </button>
          <button
            class="filtro-boton"
            :class="{ activo: soloMias }"
            @click="soloMias = true"
          >
            Solo las mías
          </button>
        </div>
        <table v-if="porUsuarioFiltrado.length">
          <thead>
            <tr><th>Usuario</th><th>Sector (zona de operaciones)</th><th>Completadas</th></tr>
          </thead>
          <tbody>
            <tr v-for="(f, i) in porUsuarioFiltrado" :key="i">
              <td>{{ f.usuario }}</td>
              <td>{{ f.sector }}</td>
              <td>{{ f.tareas_completadas }}</td>
            </tr>
          </tbody>
        </table>
        <p v-else class="vacio">
          {{ soloMias ? 'Aún no completas tareas.' : 'Todavía no hay tareas completadas en el sistema.' }}
        </p>
      </div>
    </template>
  </section>
</template>
