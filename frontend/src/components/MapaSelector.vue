<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import L from '../leafletBase'

/**
 * Componente reutilizable: mapa para SELECCIONAR un punto.
 * Se usa en el registro para capturar la direccion geografica del usuario
 * (Requisito Funcional 1): el punto elegido se guarda como GEOMETRY(Point)
 * en PostGIS. Emite { lat, lng } al hacer clic.
 */
const props = defineProps({ modelValue: { type: Object, default: null } })
const emit = defineEmits(['update:modelValue'])

const contenedor = ref(null)
let mapa = null
let marcador = null

function ponerMarcador(latlng) {
  if (marcador) marcador.setLatLng(latlng)
  else marcador = L.marker(latlng).addTo(mapa)
}

onMounted(() => {
  mapa = L.map(contenedor.value).setView([-33.4489, -70.6693], 11)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap',
  }).addTo(mapa)

  if (props.modelValue) ponerMarcador([props.modelValue.lat, props.modelValue.lng])

  mapa.on('click', (e) => {
    ponerMarcador(e.latlng)
    emit('update:modelValue', {
      lat: +e.latlng.lat.toFixed(6),
      lng: +e.latlng.lng.toFixed(6),
    })
  })

  setTimeout(() => mapa.invalidateSize(), 150)
})

// Si el padre fija el punto por otra via (boton GPS), mover marcador y centrar
watch(
  () => props.modelValue,
  (v) => {
    if (v && mapa) {
      ponerMarcador([v.lat, v.lng])
      mapa.setView([v.lat, v.lng], 15)
    }
  }
)

onBeforeUnmount(() => {
  if (mapa) mapa.remove()
})
</script>

<template>
  <div ref="contenedor" class="mapa"></div>
</template>
