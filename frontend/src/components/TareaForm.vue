<script setup>
import { computed, reactive, ref } from 'vue'
import MapaSelector from './MapaSelector.vue'
import { obtenerPosicionGPS } from '../gps'

/**
 * Formulario de tarea en modal (crear con prop tarea=null, editar con datos).
 * Incluye creacion de sector en linea: mismo flujo que el registro
 * (intento de GPS -> mapa para ajustar o marcar el punto).
 */
const props = defineProps({
  tarea: { type: Object, default: null },
  sectores: { type: Array, default: () => [] },
})
const emit = defineEmits(['guardar', 'cerrar'])

const form = reactive({
  titulo: props.tarea?.titulo || '',
  descripcion: props.tarea?.descripcion || '',
  fechaVencimiento: props.tarea?.fechaVencimiento || '',
  idSector: props.tarea?.idSector || props.sectores[0]?.idSector || null,
})

const modoNuevoSector = ref(false)
const nuevoSector = reactive({ nombre: '', punto: null })
const estadoGPS = ref('') // '' | pidiendo | ok | denegado

async function toggleNuevoSector() {
  modoNuevoSector.value = !modoNuevoSector.value
  if (modoNuevoSector.value && !nuevoSector.punto) {
    estadoGPS.value = 'pidiendo'
    try {
      nuevoSector.punto = await obtenerPosicionGPS()
      estadoGPS.value = 'ok'
    } catch {
      estadoGPS.value = 'denegado'
    }
  }
}

const tituloModal = computed(() => (props.tarea ? 'Editar tarea' : 'Nueva tarea'))
const valido = computed(() => {
  if (!form.titulo.trim() || !form.fechaVencimiento) return false
  if (modoNuevoSector.value) return nuevoSector.nombre.trim() && nuevoSector.punto
  return !!form.idSector
})

function enviar() {
  if (!valido.value) return
  emit('guardar', {
    titulo: form.titulo.trim(),
    descripcion: form.descripcion,
    fechaVencimiento: form.fechaVencimiento,
    idSector: form.idSector,
    nuevoSector: modoNuevoSector.value
      ? {
          nombre: nuevoSector.nombre.trim(),
          latitud: nuevoSector.punto.lat,
          longitud: nuevoSector.punto.lng,
        }
      : null,
  })
}
</script>

<template>
  <div class="modal-fondo" @click.self="emit('cerrar')">
    <div class="modal">
      <h2>{{ tituloModal }}</h2>
      <label>
        Título
        <input v-model="form.titulo" placeholder="Ej: Reparar semáforo en cruce principal" />
      </label>
      <label>
        Descripción
        <textarea v-model="form.descripcion" rows="3" placeholder="Detalle del trabajo a realizar"></textarea>
      </label>
      <div class="fila">
        <label>
          Fecha de vencimiento
          <input type="date" v-model="form.fechaVencimiento" />
        </label>
        <label v-if="!modoNuevoSector">
          Sector
          <select v-model="form.idSector">
            <option v-for="s in sectores" :key="s.idSector" :value="s.idSector">
              {{ s.nombre }}
            </option>
          </select>
        </label>
      </div>

      <button type="button" class="enlace" @click="toggleNuevoSector">
        {{ modoNuevoSector ? '← Usar un sector existente' : '¿Falta un sector? Créalo aquí' }}
      </button>

      <template v-if="modoNuevoSector">
        <label style="margin-top: 12px">
          Nombre del nuevo sector
          <input v-model="nuevoSector.nombre" placeholder="Ej: Bacheo, Áreas verdes, Maipú…" />
        </label>
        <label>
          Ubicación del sector
          <span v-if="estadoGPS === 'pidiendo'" class="ayuda">Solicitando GPS…</span>
          <span v-else-if="estadoGPS === 'ok'" class="ayuda">
            Punto GPS cargado: ajústalo con un clic si es necesario.
          </span>
          <span v-else class="ayuda">
            GPS rechazado o sin señal: marca el punto con un clic (mapa en Santiago).
          </span>
        </label>
        <MapaSelector v-model="nuevoSector.punto" />
        <p v-if="nuevoSector.punto" class="coordenadas">
          Punto: {{ nuevoSector.punto.lat }}, {{ nuevoSector.punto.lng }}
        </p>
      </template>

      <div class="modal-acciones">
        <button class="boton boton-secundario" @click="emit('cerrar')">Cancelar</button>
        <button class="boton boton-primario" :disabled="!valido" @click="enviar">
          Guardar tarea
        </button>
      </div>
    </div>
  </div>
</template>
