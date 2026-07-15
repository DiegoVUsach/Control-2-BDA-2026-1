<script setup>
import { onMounted, ref } from 'vue'
import api from '../api'

/**
 * Estadisticas espaciales calculadas con PostGIS. Todas son PRIVADAS:
 * la API resuelve cada respuesta con el id del usuario autenticado.
 */
const porSector = ref([])
const masCercana = ref(null)
const sectorTop = ref(null)
const radioKm = ref(2)
const promedio = ref(null)
const clusters = ref([])
const cargando = ref(true)

async function cargarSectorTop() {
  const { data } = await api.get('/estadisticas/sector-mas-completadas', {
    params: { radioKm: radioKm.value },
  })
  sectorTop.value = data[0] || null
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
  const [ps, mc, pd, cl] = await Promise.all([
    api.get('/estadisticas/tareas-por-sector'),
    api.get('/estadisticas/tarea-mas-cercana'),
    api.get('/estadisticas/promedio-distancia'),
    api.get('/estadisticas/clusters-pendientes'),
  ])
  porSector.value = ps.data
  masCercana.value = mc.data[0] || null
  promedio.value = pd.data[0] ? pd.data[0].promedio_distancia_metros : null
  clusters.value = cl.data
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
            Agrupación espacial de tus tareas pendientes. Puedes verlas dibujadas
            en la pestaña Mapa.
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
    </template>
  </section>
</template>
