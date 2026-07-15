<script setup>
import { computed, ref } from 'vue'

/**
 * Componente reutilizable: campana de notificaciones (Requisito Funcional 4).
 * Muestra los avisos de tareas por vencer generados en la base de datos.
 */
const props = defineProps({ notificaciones: { type: Array, default: () => [] } })
const emit = defineEmits(['leer'])

const abierto = ref(false)
const noLeidas = computed(() => props.notificaciones.filter((n) => !n.leida).length)

function formatear(f) {
  return new Date(f).toLocaleString('es-CL')
}
</script>

<template>
  <div class="notifs">
    <button class="boton boton-secundario" @click="abierto = !abierto">
      Notificaciones
      <span v-if="noLeidas" class="notifs-contador">{{ noLeidas }}</span>
    </button>
    <div v-if="abierto" class="notifs-panel">
      <p v-if="!notificaciones.length" class="notifs-vacio">
        Sin avisos por ahora. Aquí aparecerán las tareas próximas a vencer.
      </p>
      <div
        v-for="n in notificaciones"
        :key="n.idNotificacion"
        class="notifs-item"
        :class="{ leida: n.leida }"
      >
        <p>{{ n.mensaje }}</p>
        <small>{{ formatear(n.fechaCreacion) }}</small>
        <button v-if="!n.leida" class="enlace" @click="emit('leer', n.idNotificacion)">
          Marcar leída
        </button>
      </div>
    </div>
  </div>
</template>
