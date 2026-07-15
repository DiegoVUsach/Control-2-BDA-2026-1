<script setup>
import { onMounted, ref } from 'vue'
import api from '../api'
import MapaSectores from '../components/MapaSectores.vue'

/**
 * Mapa territorial: zonas de operaciones (marcadores), tu ubicacion
 * registrada (punto de color) y los circulos que encierran las
 * concentraciones de TUS tareas pendientes (agrupacion espacial).
 */
const sectores = ref([])
const perfil = ref(null)
const clusters = ref([])
const cargando = ref(true)

onMounted(async () => {
  const [sec, per, cl] = await Promise.all([
    api.get('/sectores'),
    api.get('/usuarios/me'),
    api.get('/estadisticas/clusters-pendientes'),
  ])
  sectores.value = sec.data
  perfil.value = per.data
  clusters.value = cl.data
  cargando.value = false
})
</script>

<template>
  <section>
    <div class="pagina-cabecera">
      <div>
        <h1>Mapa</h1>
        <p class="eyebrow">
          Marcadores: zonas de operaciones · Punto de color: tu ubicación ·
          Círculos: concentración de tus tareas pendientes
        </p>
      </div>
    </div>
    <p v-if="cargando" class="vacio">Cargando mapa…</p>
    <div v-else class="panel">
      <MapaSectores :sectores="sectores" :usuario="perfil" :clusters="clusters" />
    </div>
  </section>
</template>
