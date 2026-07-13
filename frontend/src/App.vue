<script setup lang="ts">
import { ref } from 'vue';
import LoginView from './views/LoginView.vue';
import TasksView from './views/TasksView.vue';
import NotificationsView from './views/NotificationsView.vue';
import StatsView from './views/StatsView.vue';

const logged = ref(!!localStorage.getItem('auth_token'));
const username = ref(localStorage.getItem('username') || '');

const currentView = ref<'tasks' | 'notifications' | 'stats'>('tasks');

const onLogin = (data: { token: string; user: string; id?: number }) => {
  localStorage.setItem('auth_token', data.token || '');
  localStorage.setItem('username', data.user || '');
  username.value = data.user;
  logged.value = true;
  currentView.value = 'tasks';
};

const onLogout = () => {
  localStorage.removeItem('auth_token');
  localStorage.removeItem('username');
  username.value = '';
  logged.value = false;
};
</script>

<template>
  <div id="app-wrapper">
    <LoginView v-if="!logged" @auth-success="onLogin" />
    
    <div v-else class="dashboard-layout">
      <!-- Sidebar -->
      <aside class="sidebar">
        <div class="sidebar-header">
          <div class="logo">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="feather feather-check-square"><polyline points="9 11 12 14 22 4"></polyline><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"></path></svg>
          </div>
          <h2>TaskMaster</h2>
        </div>
        
        <nav class="sidebar-nav">
          <button :class="{ active: currentView === 'tasks' }" @click="currentView = 'tasks'">Mis Tareas</button>
          <button :class="{ active: currentView === 'notifications' }" @click="currentView = 'notifications'">Notificaciones</button>
          <button :class="{ active: currentView === 'stats' }" @click="currentView = 'stats'">Estadísticas</button>
        </nav>

        <div class="sidebar-footer">
          <div class="user-info">
            <span>{{ username }}</span>
          </div>
          <button class="btn-logout" @click="onLogout">Cerrar Sesión</button>
        </div>
      </aside>

      <!-- Main Content -->
      <main class="main-content">
        <TasksView v-if="currentView === 'tasks'" />
        <NotificationsView v-else-if="currentView === 'notifications'" />
        <StatsView v-else-if="currentView === 'stats'" />
      </main>
    </div>
  </div>
</template>

<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

:root {
  --primary: #6366f1;
  --primary-hover: #4f46e5;
  --bg-dark: #0f172a;
  --bg-card: rgba(30, 41, 59, 0.7);
  --border: rgba(255, 255, 255, 0.1);
  --text: #f8fafc;
  --text-dim: #94a3b8;
  --red: #ef4444;
  --green: #10b981;
  --blue: #3b82f6;
  --radius: 12px;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body { 
  background: var(--bg-dark); 
  color: var(--text); 
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; 
  -webkit-font-smoothing: antialiased;
  height: 100vh;
  overflow: hidden;
}

h1, h2, h3 { font-weight: 700; color: var(--text); letter-spacing: -0.025em; }

::-webkit-scrollbar { width: 8px; }
::-webkit-scrollbar-track { background: var(--bg-dark); }
::-webkit-scrollbar-thumb { background: #334155; border-radius: 4px; }

#app-wrapper { height: 100vh; }

.dashboard-layout {
  display: flex;
  height: 100vh;
  background: radial-gradient(circle at 100% 0%, #1e293b 0%, #0f172a 100%);
}

.sidebar {
  width: 260px;
  background: rgba(15, 23, 42, 0.8);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  backdrop-filter: blur(10px);
}

.sidebar-header {
  padding: 24px;
  display: flex;
  align-items: center;
  gap: 12px;
  border-bottom: 1px solid var(--border);
}

.sidebar-header .logo {
  background: linear-gradient(135deg, var(--primary), #bc8cff);
  width: 32px; height: 32px; border-radius: 8px;
  display: flex; align-items: center; justify-content: center; color: white;
}
.sidebar-header h2 { font-size: 20px; }

.sidebar-nav {
  padding: 24px 16px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex-grow: 1;
}

.sidebar-nav button {
  background: transparent;
  color: var(--text-dim);
  border: none;
  padding: 12px 16px;
  border-radius: 8px;
  text-align: left;
  font-size: 15px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.sidebar-nav button:hover:not(.active) { background: rgba(255,255,255,0.05); color: var(--text); }
.sidebar-nav button.active { background: var(--primary); color: white; box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3); }

.sidebar-footer {
  padding: 24px 16px;
  border-top: 1px solid var(--border);
}

.user-info { margin-bottom: 12px; font-size: 14px; color: var(--text-dim); text-align: center; }

.btn-logout {
  width: 100%;
  background: rgba(239, 68, 68, 0.1);
  color: #fca5a5;
  border: 1px solid rgba(239, 68, 68, 0.2);
  padding: 10px;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}
.btn-logout:hover { background: rgba(239, 68, 68, 0.2); }

.main-content {
  flex-grow: 1;
  overflow-y: auto;
  padding: 0;
}
</style>
