<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import L from '../leafletBase'

/**
 * Mapa de visualizacion, con dos modos.
 *
 * En los dos modos vale la misma regla de lectura:
 *   - Una BURBUJA con numero = una zona donde TU tienes tareas. El numero es
 *     cuantas. Una zona puede tener varias tareas, por eso los numeros de las
 *     burbujas suman mas que la cantidad de burbujas.
 *   - Un PUNTO GRIS CHICO sin numero = una zona del sistema donde no tienes
 *     tareas de ese tipo. Esta ahi solo como referencia del territorio.
 *
 * MODO "pendientes" (pregunta 5):
 *   Cada COLOR es un grupo de ST_ClusterKMeans. Las burbujas del mismo color
 *   son del mismo grupo, y el circulo de ese color es la zona que abarca.
 *   El color manda, no la posicion: hay casos donde el circulo de un grupo
 *   encierra por geometria zonas que no son suyas.
 *
 * MODO "completadas" (preguntas 3 y 7):
 *   Anillos punteados de 2 km y 5 km desde el usuario. Cada burbuja se pinta
 *   segun en que radio cae.
 */
const props = defineProps({
  sectores: { type: Array, default: () => [] },
  usuario: { type: Object, default: null },
  clusters: { type: Array, default: () => [] },
  pendientesPorZona: { type: Array, default: () => [] },
  completadas: { type: Array, default: () => [] },
  modo: { type: String, default: 'pendientes' },
})

// Un color por grupo. El grupo 1 es el que tiene mas pendientes.
const COLORES_GRUPO = ['#1d4ed8', '#b91c1c', '#7c3aed', '#c2410c', '#0f766e', '#a21caf']
const GRIS = '#9ca3af'
const RADIO_MINIMO_VISIBLE = 250

const contenedor = ref(null)
let mapa = null
let capa = null

/** Burbuja con numero: una zona donde el usuario tiene tareas. */
function burbuja(lat, lon, cantidad, color, popup) {
  L.circleMarker([lat, lon], {
    radius: 8 + Math.min(cantidad, 7) * 1.4,
    color,
    fillColor: color,
    fillOpacity: 0.6,
    weight: 2,
  })
    .addTo(capa)
    .bindTooltip(String(cantidad), {
      permanent: true,
      direction: 'center',
      className: 'etiqueta-mapa',
    })
    .bindPopup(popup)
}

/** Punto gris chico: zona sin tareas del usuario en este modo. */
function puntoDeReferencia(s, texto) {
  L.circleMarker([s.latitud, s.longitud], {
    radius: 4,
    color: GRIS,
    fillColor: GRIS,
    fillOpacity: 0.5,
    weight: 1,
  })
    .addTo(capa)
    .bindPopup('<b>' + s.nombre + '</b><br>' + texto)
}

function dibujarUsuario() {
  if (!props.usuario) return
  L.circleMarker([props.usuario.latitud, props.usuario.longitud], {
    radius: 7,
    color: '#111827',
    fillColor: '#facc15',
    fillOpacity: 1,
    weight: 3,
  })
    .addTo(capa)
    .bindPopup('<b>Tu ubicación registrada</b>')
    .bringToFront()
}

function dibujarPendientes() {
  // El orden de props.clusters viene por cantidad descendente: el primero es
  // el grupo 1. Con eso se decide el color de cada cluster_id.
  const rango = new Map()
  props.clusters.forEach((c, i) => rango.set(Number(c.cluster_id), i))
  const colorDe = (cid) => COLORES_GRUPO[(rango.get(Number(cid)) ?? 0) % COLORES_GRUPO.length]
  const numeroDe = (cid) => (rango.get(Number(cid)) ?? 0) + 1

  // Ojo: /api/sectores devuelve idSector (record de Java) y los endpoints de
  // estadisticas devuelven id_sector (etiqueta de la columna SQL).
  const conPendientes = new Set(props.pendientesPorZona.map((z) => z.id_sector))
  props.sectores
    .filter((s) => !conPendientes.has(s.idSector))
    .forEach((s) => puntoDeReferencia(s, 'No tienes tareas pendientes aquí'))

  // Primero los circulos, para que queden debajo de las burbujas
  props.clusters.forEach((c) => {
    const color = colorDe(c.cluster_id)
    const extension = Number(c.radio_metros)
    const zonas = c.sectores ? c.sectores.split(' | ').length : 1

    L.circle([c.latitud_centro, c.longitud_centro], {
      radius: Math.max(extension, RADIO_MINIMO_VISIBLE),
      color,
      fillColor: color,
      fillOpacity: 0.07,
      weight: 1.5,
      dashArray: '5 5',
    })
      .addTo(capa)
      .bindPopup(
        '<b>Grupo ' + numeroDe(c.cluster_id) + '</b><br>' +
          c.tareas_pendientes + ' tareas pendientes en ' + zonas +
          (zonas === 1 ? ' zona' : ' zonas') + '<br>' +
          'Alcance del grupo: ' +
          (extension > 0
            ? Number(extension).toLocaleString('es-CL') + ' m'
            : 'una sola zona') +
          '<br>' + c.sectores
      )
  })

  props.pendientesPorZona.forEach((z) => {
    const n = Number(z.pendientes)
    burbuja(
      z.latitud,
      z.longitud,
      n,
      colorDe(z.cluster_id),
      '<b>' + z.nombre + '</b><br>' +
        n + (n === 1 ? ' tarea pendiente tuya' : ' tareas pendientes tuyas') + '<br>' +
        'Grupo ' + numeroDe(z.cluster_id)
    )
  })
}

function dibujarCompletadas() {
  const conCompletadas = new Set(props.completadas.map((z) => z.id_sector))
  props.sectores
    .filter((s) => !conCompletadas.has(s.idSector))
    .forEach((s) => puntoDeReferencia(s, 'No has completado tareas aquí'))

  if (props.usuario) {
    const centro = [props.usuario.latitud, props.usuario.longitud]
    const anillos = [
      { metros: 2000, color: '#059669', texto: 'Radio 2 km' },
      { metros: 5000, color: '#d97706', texto: 'Radio 5 km' },
    ]
    anillos.forEach((a) => {
      L.circle(centro, {
        radius: a.metros,
        color: a.color,
        fill: false,
        weight: 2,
        dashArray: '6 6',
      })
        .addTo(capa)
        .bindPopup('<b>' + a.texto + '</b> desde tu ubicación')
    })
  }

  props.completadas.forEach((z) => {
    const n = Number(z.tareas_completadas)
    const color = z.dentro_2km ? '#059669' : z.dentro_5km ? '#d97706' : '#475569'
    burbuja(
      z.latitud,
      z.longitud,
      n,
      color,
      '<b>' + z.nombre + '</b><br>' +
        n + ' tareas completadas por ti<br>' +
        'A ' + Number(z.distancia_metros).toLocaleString('es-CL') + ' m<br>' +
        (z.dentro_2km
          ? 'Entra en el radio de 2 km y en el de 5 km'
          : z.dentro_5km
            ? 'Entra solo en el radio de 5 km'
            : 'Queda fuera de los dos radios')
    )
  })
}

function dibujar() {
  if (!mapa) return
  if (capa) capa.remove()
  capa = L.layerGroup().addTo(mapa)

  if (props.modo === 'completadas') dibujarCompletadas()
  else dibujarPendientes()

  dibujarUsuario()
}

onMounted(() => {
  mapa = L.map(contenedor.value).setView([-33.46, -70.65], 11)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap',
  }).addTo(mapa)
  dibujar()
  setTimeout(() => mapa.invalidateSize(), 150)
})

watch(
  () => [
    props.sectores, props.usuario, props.clusters,
    props.pendientesPorZona, props.completadas, props.modo,
  ],
  dibujar,
  { deep: true }
)

onBeforeUnmount(() => {
  if (mapa) mapa.remove()
})
</script>

<template>
  <div>
    <div ref="contenedor" class="mapa mapa-grande"></div>

    <div class="mapa-leyenda">
      <p>
        <b>Punto amarillo:</b> tu ubicación registrada.
        <b>Burbuja con número:</b> una zona donde tienes tareas, y cuántas.
        <b>Punto gris chico:</b> zona sin tareas tuyas, solo de referencia.
      </p>

      <p v-if="modo === 'pendientes'">
        <b>Cada color es un grupo</b> de <code>ST_ClusterKMeans</code>: las
        burbujas del mismo color están en el mismo grupo, y el círculo punteado
        de ese color muestra hasta dónde llega. Guíate por el color y no por si
        una burbuja cae dentro de un círculo: los círculos se pisan.
      </p>
      <p v-else>
        <b>Anillos punteados:</b> los radios de 2 km y 5 km desde tu ubicación
        (<code>ST_DWithin</code>).
        <b class="c-verde">Verde</b>: la zona entra en los 2 km.
        <b class="c-naranjo">Naranjo</b>: entra solo en los 5 km.
        <b class="c-fuera">Gris oscuro</b>: queda fuera de los dos.
      </p>
    </div>
  </div>
</template>

<style scoped>
.mapa-leyenda {
  margin-top: 0.6rem;
  font-size: 0.85rem;
  line-height: 1.55;
  opacity: 0.85;
}
.mapa-leyenda p { margin: 0.35rem 0; }
.c-verde { color: #059669; }
.c-naranjo { color: #d97706; }
.c-fuera { color: #475569; }
</style>

<style>
/* Sin scoped: Leaflet monta los tooltips fuera del arbol del componente */
.etiqueta-mapa {
  background: transparent;
  border: none;
  box-shadow: none;
  color: #fff;
  font-weight: 700;
  font-size: 0.78rem;
  text-shadow: 0 0 2px #000, 0 0 3px #000;
}
.etiqueta-mapa::before {
  display: none;
}
</style>
