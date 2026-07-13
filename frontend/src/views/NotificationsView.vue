<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { notificacionService, type Notificacion } from '../services/api';

const notificaciones = ref<Notificacion[]>([]);
const loading = ref(false);

const loadNotificaciones = async () => {
  loading.value = true;
  try {
    notificaciones.value = await notificacionService.listar();
  } catch (error) {
    console.error('Error cargando notificaciones:', error);
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  loadNotificaciones();
});

const marcarLeida = async (id: number) => {
  try {
    await notificacionService.marcarLeida(id);
    // update local state to avoid refetching everything
    const noti = notificaciones.value.find(n => n.idNotificacion === id);
    if (noti) noti.leida = true;
  } catch (error) {
    console.error('Error marcando notificacion como leida', error);
  }
};
</script>

<template>
  <div class="notifications-view">
    <div class="header">
      <h2>Notificaciones</h2>
      <button class="btn-secondary" @click="loadNotificaciones">Actualizar</button>
    </div>

    <div v-if="loading" class="loading">Cargando notificaciones...</div>
    
    <div v-else-if="notificaciones.length === 0" class="empty-state">
      <p>No tienes notificaciones pendientes.</p>
    </div>

    <div v-else class="notifications-list">
      <div v-for="noti in notificaciones" :key="noti.idNotificacion" class="noti-card" :class="{ unread: !noti.leida }">
        <div class="noti-content">
          <p class="msg">{{ noti.mensaje }}</p>
          <span class="date">{{ new Date(noti.fechaCreacion).toLocaleString() }}</span>
        </div>
        <button v-if="!noti.leida" class="btn-primary btn-sm" @click="marcarLeida(noti.idNotificacion)">Marcar leída</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.notifications-view { padding: 24px; color: var(--text); max-width: 800px; margin: 0 auto; }
.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
.header h2 { font-size: 28px; margin: 0; }

.notifications-list { display: flex; flex-direction: column; gap: 12px; }
.noti-card { 
  background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px;
  padding: 16px 20px; display: flex; justify-content: space-between; align-items: center; gap: 16px;
  transition: all 0.2s;
}
.noti-card.unread { border-left: 4px solid var(--primary); background: rgba(99, 102, 241, 0.05); }

.noti-content { display: flex; flex-direction: column; gap: 4px; }
.msg { font-size: 15px; margin: 0; }
.date { font-size: 12px; color: var(--text-dim); }

.btn-primary { background: var(--primary); color: white; border: none; padding: 10px 20px; border-radius: 8px; font-weight: 600; cursor: pointer; transition: background 0.2s; }
.btn-primary:hover { background: var(--primary-hover); }
.btn-secondary { background: rgba(255,255,255,0.1); color: white; border: 1px solid var(--border); padding: 8px 16px; border-radius: 8px; font-weight: 600; cursor: pointer; transition: background 0.2s; }
.btn-secondary:hover { background: rgba(255,255,255,0.15); }
.btn-sm { padding: 8px 12px; font-size: 13px; }

.empty-state { text-align: center; padding: 60px 20px; color: var(--text-dim); font-size: 16px; background: var(--bg-card); border-radius: 12px; border: 1px dashed var(--border); }
.loading { text-align: center; padding: 40px; color: var(--primary); font-weight: 600; }
</style>
