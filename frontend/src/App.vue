<script setup lang="ts">
import { ref } from 'vue';
import LoginView from './views/LoginView.vue';

const logged = ref(!!localStorage.getItem('auth_token'));
const username = ref('');

const onLogin = (data: { token: string; user: string; id?: number }) => {
  localStorage.setItem('auth_token', data.token || '');
  username.value = data.user;
  logged.value = true;
};

const onLogout = () => {
  localStorage.removeItem('auth_token');
  username.value = '';
  logged.value = false;
};
</script>

<template>
  <div id="app-wrapper">
    <LoginView v-if="!logged" @auth-success="onLogin" />
    <div v-else class="welcome-container">
      <div class="welcome-card">
        <h1>Bienvenido, {{ username }}</h1>
        <p>Has iniciado sesión correctamente. Aquí podrás gestionar tus tareas pronto.</p>
        <button class="btn-primary" @click="onLogout">Cerrar sesión</button>
      </div>
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
}

h1, h2, h3 { 
  font-weight: 700; 
  color: var(--text); 
  letter-spacing: -0.025em;
}

::-webkit-scrollbar { width: 8px; }
::-webkit-scrollbar-track { background: var(--bg-dark); }
::-webkit-scrollbar-thumb { background: #334155; border-radius: 4px; }

.welcome-container {
  height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: radial-gradient(circle at 50% 0%, #1e293b 0%, #0f172a 100%);
}

.welcome-card {
  background: var(--bg-card);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  padding: 48px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
  text-align: center;
  max-width: 400px;
}

.welcome-card h1 {
  font-size: 24px;
  margin-bottom: 8px;
}

.welcome-card p {
  color: var(--text-dim);
  font-size: 14px;
  margin-bottom: 24px;
}

.btn-primary {
  background: var(--primary);
  color: #fff;
  border: none;
  padding: 12px 24px;
  border-radius: 8px;
  font-weight: 600;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s ease;
  width: 100%;
}

.btn-primary:hover {
  background: var(--primary-hover);
  transform: translateY(-1px);
}
</style>
