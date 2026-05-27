<script setup lang="ts">
import { ref } from 'vue';
import LoginView from './views/LoginView.vue';

const logged = ref(false);
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
    <div v-else class="welcome">
      <h1>Bienvenido, {{ username }}</h1>
      <p>Has iniciado sesión correctamente.</p>
      <button @click="onLogout">Cerrar sesión</button>
    </div>
  </div>
</template>

<style>
@import url('https://fonts.googleapis.com/css2?family=Cinzel:wght@400;700&family=Nunito:wght@400;600;700&display=swap');
:root {
  --gold: #d4a843;
  --gold-dim: #a07d2e;
  --bg-dark: #0d1117;
  --bg-card: #161b22;
  --border: #30363d;
  --text: #e6edf3;
  --text-dim: #8b949e;
  --purple: #bc8cff;
  --red: #f85149;
  --green: #3fb950;
  --blue: #58a6ff;
  --legendary: #ff8000;
  --epic: #a335ee;
  --rare: #0070dd;
  --common: #9d9d9d;
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: var(--bg-dark); color: var(--text); font-family: 'Nunito', sans-serif; }
h1, h2, h3 { font-family: 'Cinzel', serif; color: var(--gold); }
::-webkit-scrollbar { width: 6px; }
::-webkit-scrollbar-track { background: var(--bg-dark); }
::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
</style>
