<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { estadisticaService } from '../services/api';

const p1 = ref<any[]>([]);
const p2 = ref<any[]>([]);
const p3 = ref<any[]>([]);
const p4 = ref<any[]>([]);
const p5 = ref<any[]>([]);
const p6 = ref<any[]>([]);
const p7 = ref<any[]>([]);
const p8 = ref<any[]>([]);
const loading = ref(true);

const loadStats = async () => {
  loading.value = true;
  try {
    const [r1, r2, r3, r4, r5, r6, r7, r8] = await Promise.all([
      estadisticaService.tareasPorSector(),
      estadisticaService.tareaMasCercana(),
      estadisticaService.sectorMasCompletadas(2),
      estadisticaService.promedioDistancia(),
      estadisticaService.clustersPendientes(3),
      estadisticaService.tareasPorUsuarioYSector(),
      estadisticaService.sectorMasCompletadas(5),
      estadisticaService.promedioDistanciaUsuarios()
    ]);
    p1.value = r1; p2.value = r2; p3.value = r3; p4.value = r4; 
    p5.value = r5; p6.value = r6; p7.value = r7; p8.value = r8;
  } catch (error) {
    console.error('Error cargando estadísticas', error);
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  loadStats();
});
</script>

<template>
  <div class="stats-view">
    <div class="header">
      <h2>Estadísticas Espaciales (PostGIS)</h2>
      <button class="btn-secondary" @click="loadStats">Refrescar Datos</button>
    </div>

    <div v-if="loading" class="loading">Cargando consultas espaciales...</div>

    <div v-else class="grid">
      <!-- P1 -->
      <div class="stat-card">
        <h3>1. Mis tareas por sector</h3>
        <ul v-if="p1.length">
          <li v-for="(row, idx) in p1" :key="idx">
            Sector <strong>{{ row.nombre_sector }}</strong>: {{ row.total_tareas }} tarea(s)
          </li>
        </ul>
        <p v-else class="empty">No hay datos.</p>
      </div>

      <!-- P2 -->
      <div class="stat-card">
        <h3>2. Mi tarea pendiente más cercana</h3>
        <div v-if="p2.length">
          <p><strong>Tarea:</strong> {{ p2[0].titulo }}</p>
          <p><strong>Distancia:</strong> {{ Number(p2[0].distancia_metros).toFixed(2) }} metros</p>
        </div>
        <p v-else class="empty">No tienes tareas pendientes georreferenciadas.</p>
      </div>

      <!-- P3 -->
      <div class="stat-card">
        <h3>3. Sector con más completadas (2 km)</h3>
        <div v-if="p3.length">
          <p><strong>Sector:</strong> {{ p3[0].nombre_sector }}</p>
          <p><strong>Total Completadas:</strong> {{ p3[0].total_completadas }}</p>
        </div>
        <p v-else class="empty">Ningún sector a menos de 2 km tiene tareas completadas.</p>
      </div>

      <!-- P4 -->
      <div class="stat-card">
        <h3>4. Promedio de distancia (Mis Completadas)</h3>
        <div v-if="p4.length && p4[0].promedio_metros !== null">
          <p><strong>Promedio:</strong> {{ Number(p4[0].promedio_metros).toFixed(2) }} metros</p>
        </div>
        <p v-else class="empty">No tienes tareas completadas para calcular el promedio.</p>
      </div>

      <!-- P5 -->
      <div class="stat-card">
        <h3>5. Clusters de tareas pendientes</h3>
        <ul v-if="p5.length">
          <li v-for="(row, idx) in p5" :key="idx">
            <strong>Cluster {{ row.cluster_id }}:</strong> {{ row.cantidad_tareas }} tarea(s)
          </li>
        </ul>
        <p v-else class="empty">No hay datos suficientes para agrupar.</p>
      </div>

      <!-- P6 -->
      <div class="stat-card">
        <h3>6. Tareas globales por usuario y sector</h3>
        <div class="scroll-box" v-if="p6.length">
          <div v-for="(row, idx) in p6" :key="idx" class="row-item">
            Usuario <strong>{{ row.nombre_usuario }}</strong> en <strong>{{ row.nombre_sector }}</strong>: {{ row.total_tareas }}
          </div>
        </div>
        <p v-else class="empty">No hay datos.</p>
      </div>

      <!-- P7 -->
      <div class="stat-card">
        <h3>7. Sector con más completadas (5 km)</h3>
        <div v-if="p7.length">
          <p><strong>Sector:</strong> {{ p7[0].nombre_sector }}</p>
          <p><strong>Total Completadas:</strong> {{ p7[0].total_completadas }}</p>
        </div>
        <p v-else class="empty">Ningún sector a menos de 5 km tiene tareas completadas.</p>
      </div>

      <!-- P8 -->
      <div class="stat-card">
        <h3>8. Promedio distancia usuarios-tareas globales</h3>
        <div class="scroll-box" v-if="p8.length">
          <div v-for="(row, idx) in p8" :key="idx" class="row-item">
            <strong>{{ row.nombre_usuario }}</strong>: 
            {{ row.promedio_metros !== null ? Number(row.promedio_metros).toFixed(2) + ' m' : 'Sin datos' }}
          </div>
        </div>
        <p v-else class="empty">No hay datos.</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.stats-view { padding: 24px; color: var(--text); }
.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
.header h2 { font-size: 28px; margin: 0; }

.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 16px; }

.stat-card { 
  background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px;
  padding: 20px; display: flex; flex-direction: column; gap: 12px;
}
.stat-card h3 { font-size: 16px; color: var(--primary); margin: 0 0 8px 0; }
.stat-card p { margin: 0; font-size: 14px; }
.stat-card ul { margin: 0; padding-left: 20px; font-size: 14px; }
.stat-card li { margin-bottom: 4px; }

.empty { color: var(--text-dim); font-style: italic; }
.scroll-box { max-height: 120px; overflow-y: auto; font-size: 14px; display: flex; flex-direction: column; gap: 4px; }
.row-item { background: rgba(255,255,255,0.05); padding: 6px; border-radius: 6px; }

.btn-secondary { background: rgba(255,255,255,0.1); color: white; border: 1px solid var(--border); padding: 8px 16px; border-radius: 8px; font-weight: 600; cursor: pointer; transition: background 0.2s; }
.btn-secondary:hover { background: rgba(255,255,255,0.15); }
.loading { text-align: center; padding: 40px; color: var(--primary); font-weight: 600; }
</style>
