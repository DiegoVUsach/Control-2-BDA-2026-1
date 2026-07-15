<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import BarraNavegacion from './components/BarraNavegacion.vue'
import { sesion } from './auth'

const route = useRoute()
const mostrarNav = computed(() => !route.meta.publica && !!sesion.token)
</script>

<template>
  <BarraNavegacion v-if="mostrarNav" />
  <main class="contenido">
    <router-view />
  </main>
</template>
