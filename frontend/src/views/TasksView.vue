<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { tareaService, sectorService, type Tarea, type Sector } from '../services/api';

const tareas = ref<Tarea[]>([]);
const sectores = ref<Sector[]>([]);
const filterStatus = ref('');
const searchQuery = ref('');
const loading = ref(false);

const isModalOpen = ref(false);
const editingTareaId = ref<number | null>(null);

const form = ref({
  titulo: '',
  descripcion: '',
  fechaVencimiento: '',
  idSector: '' as number | ''
});

const loadTareas = async () => {
  loading.value = true;
  try {
    tareas.value = await tareaService.listar(filterStatus.value, searchQuery.value);
  } catch (error) {
    console.error('Error cargando tareas:', error);
  } finally {
    loading.value = false;
  }
};

const loadSectores = async () => {
  try {
    sectores.value = await sectorService.listar();
  } catch (error) {
    console.error('Error cargando sectores:', error);
  }
};

onMounted(() => {
  loadSectores();
  loadTareas();
});

const handleSearch = () => {
  loadTareas();
};

const openModal = (tarea?: Tarea) => {
  if (tarea) {
    editingTareaId.value = tarea.idTarea;
    form.value = {
      titulo: tarea.titulo,
      descripcion: tarea.descripcion,
      fechaVencimiento: tarea.fechaVencimiento,
      idSector: tarea.idSector
    };
  } else {
    editingTareaId.value = null;
    form.value = { titulo: '', descripcion: '', fechaVencimiento: '', idSector: '' };
  }
  isModalOpen.value = true;
};

const closeModal = () => {
  isModalOpen.value = false;
};

const saveTarea = async () => {
  if (!form.value.titulo || !form.value.fechaVencimiento || form.value.idSector === '') return;
  
  const payload = {
    titulo: form.value.titulo,
    descripcion: form.value.descripcion,
    fechaVencimiento: form.value.fechaVencimiento,
    idSector: Number(form.value.idSector)
  };

  try {
    if (editingTareaId.value) {
      await tareaService.editar(editingTareaId.value, payload);
    } else {
      await tareaService.crear(payload);
    }
    closeModal();
    loadTareas();
  } catch (error) {
    console.error('Error guardando tarea', error);
  }
};

const deleteTarea = async (id: number) => {
  if (!confirm('¿Seguro que deseas eliminar esta tarea?')) return;
  try {
    await tareaService.eliminar(id);
    loadTareas();
  } catch (error) {
    console.error('Error eliminando tarea', error);
  }
};

const completeTarea = async (id: number) => {
  try {
    await tareaService.completar(id);
    loadTareas();
  } catch (error) {
    console.error('Error completando tarea', error);
  }
};
</script>

<template>
  <div class="tasks-view">
    <div class="header">
      <h2>Mis Tareas</h2>
      <button class="btn-primary" @click="openModal()">+ Nueva Tarea</button>
    </div>

    <div class="filters">
      <input type="text" v-model="searchQuery" placeholder="Buscar por título o descripción..." @keyup.enter="handleSearch" class="search-input">
      
      <select v-model="filterStatus" @change="handleSearch" class="status-select">
        <option value="">Todos los estados</option>
        <option value="pendiente">Pendientes</option>
        <option value="completada">Completadas</option>
      </select>

      <button class="btn-secondary" @click="handleSearch">Buscar</button>
    </div>

    <div v-if="loading" class="loading">Cargando tareas...</div>
    
    <div v-else-if="tareas.length === 0" class="empty-state">
      <p>No se encontraron tareas.</p>
    </div>

    <div v-else class="tasks-list">
      <div v-for="tarea in tareas" :key="tarea.idTarea" class="task-card" :class="{ completed: tarea.completada }">
        <div class="task-header">
          <h3>{{ tarea.titulo }}</h3>
          <span class="badge" :class="tarea.completada ? 'badge-green' : 'badge-orange'">
            {{ tarea.completada ? 'Completada' : 'Pendiente' }}
          </span>
        </div>
        <p class="desc">{{ tarea.descripcion || 'Sin descripción' }}</p>
        <div class="task-meta">
          <span><strong>Vence:</strong> {{ tarea.fechaVencimiento }}</span>
          <span><strong>Sector:</strong> {{ tarea.nombreSector }}</span>
        </div>
        
        <div class="task-actions">
          <button v-if="!tarea.completada" class="btn-sm btn-success" @click="completeTarea(tarea.idTarea)">✓ Completar</button>
          <button class="btn-sm btn-edit" @click="openModal(tarea)">Editar</button>
          <button class="btn-sm btn-danger" @click="deleteTarea(tarea.idTarea)">Eliminar</button>
        </div>
      </div>
    </div>

    <!-- Modal -->
    <div v-if="isModalOpen" class="modal-backdrop">
      <div class="modal">
        <h3>{{ editingTareaId ? 'Editar Tarea' : 'Nueva Tarea' }}</h3>
        
        <label>Título</label>
        <input type="text" v-model="form.titulo" placeholder="Ej. Reparar semáforo">
        
        <label>Descripción</label>
        <textarea v-model="form.descripcion" placeholder="Detalles de la tarea..."></textarea>
        
        <label>Fecha Vencimiento</label>
        <input type="date" v-model="form.fechaVencimiento">
        
        <label>Sector Geográfico</label>
        <select v-model="form.idSector">
          <option value="" disabled>Seleccione un sector...</option>
          <option v-for="s in sectores" :key="s.idSector" :value="s.idSector">{{ s.nombre }}</option>
        </select>

        <div class="modal-actions">
          <button class="btn-secondary" @click="closeModal">Cancelar</button>
          <button class="btn-primary" @click="saveTarea">Guardar</button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tasks-view { padding: 24px; color: var(--text); }
.header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; }
.header h2 { font-size: 28px; margin: 0; }

.filters { display: flex; gap: 12px; margin-bottom: 24px; flex-wrap: wrap; }
.search-input, .status-select { 
  background: var(--bg-card); border: 1px solid var(--border); color: var(--text);
  padding: 10px 14px; border-radius: 8px; outline: none;
}
.search-input { flex: 1; min-width: 200px; }
.search-input:focus, .status-select:focus { border-color: var(--primary); }

.tasks-list { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 16px; }
.task-card { 
  background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px;
  padding: 20px; display: flex; flex-direction: column; gap: 12px;
  transition: transform 0.2s;
}
.task-card:hover { transform: translateY(-2px); box-shadow: 0 10px 15px -3px rgba(0,0,0,0.3); }
.task-card.completed { opacity: 0.7; }
.task-header { display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; }
.task-header h3 { font-size: 18px; margin: 0; line-height: 1.3; }
.badge { font-size: 11px; padding: 4px 8px; border-radius: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
.badge-green { background: rgba(16,185,129,0.2); color: #86efac; border: 1px solid rgba(16,185,129,0.3); }
.badge-orange { background: rgba(245,158,11,0.2); color: #fcd34d; border: 1px solid rgba(245,158,11,0.3); }

.desc { font-size: 14px; color: var(--text-dim); margin: 0; line-height: 1.5; flex-grow: 1; }
.task-meta { display: flex; flex-direction: column; gap: 4px; font-size: 13px; color: var(--text-dim); background: rgba(0,0,0,0.2); padding: 10px; border-radius: 8px; }
.task-meta strong { color: var(--text); }

.task-actions { display: flex; gap: 8px; margin-top: auto; }
.btn-sm { padding: 8px 12px; border-radius: 6px; font-size: 12px; font-weight: 600; border: none; cursor: pointer; color: white; transition: opacity 0.2s; flex: 1; }
.btn-sm:hover { opacity: 0.8; }
.btn-success { background: var(--green); }
.btn-edit { background: var(--blue); }
.btn-danger { background: var(--red); }

.btn-primary { background: var(--primary); color: white; border: none; padding: 10px 20px; border-radius: 8px; font-weight: 600; cursor: pointer; transition: background 0.2s; }
.btn-primary:hover { background: var(--primary-hover); }
.btn-secondary { background: rgba(255,255,255,0.1); color: white; border: 1px solid var(--border); padding: 10px 20px; border-radius: 8px; font-weight: 600; cursor: pointer; transition: background 0.2s; }
.btn-secondary:hover { background: rgba(255,255,255,0.15); }

.modal-backdrop { position: fixed; inset: 0; background: rgba(0,0,0,0.7); backdrop-filter: blur(4px); display: flex; align-items: center; justify-content: center; z-index: 50; }
.modal { background: var(--bg-dark); border: 1px solid var(--border); padding: 32px; border-radius: 16px; width: 100%; max-width: 450px; display: flex; flex-direction: column; gap: 12px; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); }
.modal h3 { margin-bottom: 8px; font-size: 20px; }
.modal label { font-size: 13px; font-weight: 600; color: var(--text-dim); }
.modal input, .modal select, .modal textarea { background: var(--bg-card); border: 1px solid var(--border); color: var(--text); padding: 12px; border-radius: 8px; font-family: inherit; font-size: 14px; outline: none; }
.modal input:focus, .modal select:focus, .modal textarea:focus { border-color: var(--primary); }
.modal textarea { resize: vertical; min-height: 80px; }
.modal-actions { display: flex; justify-content: flex-end; gap: 12px; margin-top: 16px; }

.empty-state { text-align: center; padding: 60px 20px; color: var(--text-dim); font-size: 16px; background: var(--bg-card); border-radius: 12px; border: 1px dashed var(--border); }
.loading { text-align: center; padding: 40px; color: var(--primary); font-weight: 600; }
</style>
