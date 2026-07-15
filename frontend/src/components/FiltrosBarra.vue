<script setup>
/**
 * Componente reutilizable: barra de filtros (Requisito Funcional 3).
 * Estado (pendiente/completada) + busqueda por palabra clave.
 * Usa v-model multiple (update:estado / update:buscar).
 */
defineProps({ estado: String, buscar: String })
const emit = defineEmits(['update:estado', 'update:buscar'])

const opciones = [
  { valor: '', texto: 'Todas' },
  { valor: 'pendiente', texto: 'Pendientes' },
  { valor: 'completada', texto: 'Completadas' },
]
</script>

<template>
  <div class="filtros">
    <div class="filtros-estado">
      <button
        v-for="o in opciones"
        :key="o.valor"
        class="filtro-boton"
        :class="{ activo: estado === o.valor }"
        @click="emit('update:estado', o.valor)"
      >
        {{ o.texto }}
      </button>
    </div>
    <input
      class="filtros-buscar"
      :value="buscar"
      placeholder="Buscar por título o descripción…"
      @input="emit('update:buscar', $event.target.value)"
    />
  </div>
</template>
