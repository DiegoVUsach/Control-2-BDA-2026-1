import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// En desarrollo, las llamadas a /api se redirigen al backend Spring
// (evita problemas de CORS y permite usar la misma baseURL que en produccion)
export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:8080',
    },
  },
})
