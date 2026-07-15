<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import L from '../leafletBase'

/**
 * Mapa de visualizacion:
 * - Marcadores: zonas de operaciones (puntos PostGIS de la tabla sector)
 * - Punto de color: ubicacion registrada del usuario
 * - Circulos: agrupaciones de tareas pendientes. El radio viene de la BD
 *   (distancia maxima del centro a sus puntos + 25%, minimo 400 m), asi el
 *   circulo ENCIERRA de verdad las zonas de su grupo.
 */
const props = defineProps({
  sectores: { type: Array, default: () => [] },
  usuario: { type: Object, default: null },
  clusters: { type: Array, default: () => [] },
})

const contenedor = ref(null)
let mapa = null
let capa = null

function dibujar() {
  if (!mapa) return
  if (capa) capa.remove()
  capa = L.layerGroup().addTo(mapa)

  props.sectores.forEach((s) => {
    L.marker([s.latitud, s.longitud])
      .addTo(capa)
      .bindPopup('<b>' + s.nombre + '</b><br>Zona de operaciones')
  })

  if (props.usuario) {
    L.circleMarker([props.usuario.latitud, props.usuario.longitud], {
      radius: 9,
      color: '#2563eb',
      fillColor: '#2563eb',
      fillOpacity: 0.9,
    })
      .addTo(capa)
      .bindPopup('<b>Tu ubicación registrada</b>')
  }

  props.clusters.forEach((c) => {
    L.circle([c.latitud_centro, c.longitud_centro], {
      radius: Number(c.radio_metros),
      color: '#1d4ed8',
      fillColor: '#1d4ed8',
      fillOpacity: 0.1,
      weight: 1.5,
    })
      .addTo(capa)
      .bindPopup(
        '<b>Concentración de pendientes</b><br>' +
          c.tareas_pendientes + ' tareas<br>' + c.sectores
      )
  })
}

onMounted(() => {
  mapa = L.map(contenedor.value).setView([-33.46, -70.65], 11)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap',
  }).addTo(mapa)
  dibujar()
  setTimeout(() => mapa.invalidateSize(), 150)
})

watch(() => [props.sectores, props.usuario, props.clusters], dibujar, { deep: true })

onBeforeUnmount(() => {
  if (mapa) mapa.remove()
})
</script>

<template>
  <div ref="contenedor" class="mapa mapa-grande"></div>
</template>
