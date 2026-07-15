<script setup>
import { onMounted, reactive, ref, watch } from 'vue'
import api from '../api'
import TareaCard from '../components/TareaCard.vue'
import TareaForm from '../components/TareaForm.vue'
import FiltrosBarra from '../components/FiltrosBarra.vue'
import PanelNotificaciones from '../components/PanelNotificaciones.vue'

/**
 * Vista principal: Gestion de Tareas (Requisito Funcional 2) con
 * filtros y busqueda (RF 3) y notificaciones (RF 4).
 * El filtrado se hace EN LA BASE DE DATOS (query params -> SQL),
 * no en el navegador.
 */
const tareas = ref([])
const sectores = ref([])
const notificaciones = ref([])
const filtros = reactive({ estado: '', buscar: '' })
const mostrarForm = ref(false)
const tareaEnEdicion = ref(null)
const error = ref('')
let temporizador = null

async function cargarTareas() {
  const params = {}
  if (filtros.estado) params.estado = filtros.estado
  if (filtros.buscar) params.buscar = filtros.buscar
  const { data } = await api.get('/tareas', { params })
  tareas.value = data
}

async function cargarSectores() {
  sectores.value = (await api.get('/sectores')).data
}

async function cargarNotificaciones() {
  notificaciones.value = (await api.get('/notificaciones')).data
}

// Busqueda con retardo (debounce) para no consultar en cada tecla
watch(
  () => filtros.buscar,
  () => {
    clearTimeout(temporizador)
    temporizador = setTimeout(cargarTareas, 300)
  }
)
watch(() => filtros.estado, cargarTareas)

function abrirCrear() {
  tareaEnEdicion.value = null
  mostrarForm.value = true
}

function abrirEditar(tarea) {
  tareaEnEdicion.value = tarea
  mostrarForm.value = true
}

async function guardar(datos) {
  error.value = ''
  try {
    // Si el formulario trae un sector nuevo, se crea primero y la tarea
    // se asocia al id recien generado
    if (datos.nuevoSector) {
      const { data } = await api.post('/sectores', datos.nuevoSector)
      datos.idSector = data.idSector
    }
    delete datos.nuevoSector
    if (tareaEnEdicion.value) {
      await api.put('/tareas/' + tareaEnEdicion.value.idTarea, datos)
    } else {
      await api.post('/tareas', datos)
    }
    mostrarForm.value = false
    await Promise.all([cargarTareas(), cargarSectores(), cargarNotificaciones()])
  } catch (e) {
    error.value = e.response?.data?.error || 'No se pudo guardar la tarea.'
  }
}

async function completar(tarea) {
  await api.patch('/tareas/' + tarea.idTarea + '/completar')
  cargarTareas()
}

async function eliminar(tarea) {
  if (!confirm('¿Eliminar la tarea "' + tarea.titulo + '"?')) return
  await api.delete('/tareas/' + tarea.idTarea)
  cargarTareas()
}

async function leerNotificacion(id) {
  await api.patch('/notificaciones/' + id + '/leer')
  cargarNotificaciones()
}

onMounted(() => {
  cargarTareas()
  cargarSectores()
  cargarNotificaciones()
})
</script>

<template>
  <section>
    <div class="pagina-cabecera">
      <div>
        <p class="eyebrow">Panel de trabajo</p>
        <h1>Mis tareas</h1>
      </div>
      <div class="pagina-acciones">
        <PanelNotificaciones :notificaciones="notificaciones" @leer="leerNotificacion" />
        <button class="boton boton-primario" @click="abrirCrear">+ Nueva tarea</button>
      </div>
    </div>

    <FiltrosBarra v-model:estado="filtros.estado" v-model:buscar="filtros.buscar" />
    <p v-if="error" class="mensaje-error">{{ error }}</p>

    <div v-if="tareas.length" class="tarjetas">
      <TareaCard
        v-for="t in tareas"
        :key="t.idTarea"
        :tarea="t"
        @editar="abrirEditar"
        @eliminar="eliminar"
        @completar="completar"
      />
    </div>
    <p v-else class="vacio">
      No hay tareas para este filtro. Crea una con el botón "+ Nueva tarea".
    </p>

    <TareaForm
      v-if="mostrarForm"
      :key="tareaEnEdicion ? tareaEnEdicion.idTarea : 'nueva'"
      :tarea="tareaEnEdicion"
      :sectores="sectores"
      @guardar="guardar"
      @cerrar="mostrarForm = false"
    />
  </section>
</template>
