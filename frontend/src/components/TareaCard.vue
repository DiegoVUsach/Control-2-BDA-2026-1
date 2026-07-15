<script setup>
import { computed } from 'vue'

/**
 * Componente reutilizable: tarjeta de una tarea.
 * Recibe la tarea por props y comunica las acciones al padre por eventos
 * (el componente no llama a la API directamente: separacion de responsabilidades).
 */
const props = defineProps({ tarea: { type: Object, required: true } })
const emit = defineEmits(['editar', 'eliminar', 'completar'])

const diasRestantes = computed(() => {
  const hoy = new Date()
  hoy.setHours(0, 0, 0, 0)
  const vencimiento = new Date(props.tarea.fechaVencimiento + 'T00:00:00')
  return Math.round((vencimiento - hoy) / 86400000)
})

const avisoVencimiento = computed(() => {
  if (props.tarea.completada) return null
  if (diasRestantes.value < 0) return { clase: 'chip-vencida', texto: 'Vencida' }
  if (diasRestantes.value === 0) return { clase: 'chip-porvencer', texto: 'Vence hoy' }
  if (diasRestantes.value <= 3)
    return { clase: 'chip-porvencer', texto: 'Vence en ' + diasRestantes.value + ' día(s)' }
  return null
})

function formatearFecha(f) {
  return new Date(f + 'T00:00:00').toLocaleDateString('es-CL')
}
</script>

<template>
  <article class="tarjeta" :class="{ 'tarjeta-completada': tarea.completada }">
    <div class="tarjeta-cabecera">
      <h3>{{ tarea.titulo }}</h3>
      <span class="chip chip-sector">{{ tarea.nombreSector }}</span>
    </div>
    <p class="tarjeta-descripcion">{{ tarea.descripcion || 'Sin descripción' }}</p>
    <div class="tarjeta-pie">
      <span class="tarjeta-fecha">Vence: {{ formatearFecha(tarea.fechaVencimiento) }}</span>
      <span v-if="avisoVencimiento" class="chip" :class="avisoVencimiento.clase">
        {{ avisoVencimiento.texto }}
      </span>
    </div>
    <div class="tarjeta-acciones">
      <template v-if="!tarea.completada">
        <button class="boton boton-primario" @click="emit('completar', tarea)">Completar</button>
        <button class="boton boton-secundario" @click="emit('editar', tarea)">Editar</button>
      </template>
      <button class="boton boton-peligro" @click="emit('eliminar', tarea)">Eliminar</button>
    </div>
    <div v-if="tarea.completada" class="sello">COMPLETADA</div>
  </article>
</template>
