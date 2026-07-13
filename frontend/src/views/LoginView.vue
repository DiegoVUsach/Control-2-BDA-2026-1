<script setup lang="ts">
import { ref } from 'vue';
import { authService } from '../services/api';

const emit = defineEmits(['auth-success']);
const mode = ref<'login' | 'register'>('login');
const username = ref('');
const password = ref('');
const address = ref('');
const errorMsg = ref('');
const successMsg = ref('');
const loading = ref(false);

const handleLogin = async () => {
  if (!username.value || !password.value) { 
    errorMsg.value = 'Completa todos los campos'; 
    return; 
  }
  loading.value = true; 
  errorMsg.value = '';
  try {
    await authService.login(username.value, password.value);
    const me = await authService.getMe();
    emit('auth-success', { token: localStorage.getItem('auth_token'), user: me.nombreUsuario, id: me.idUsuario });
  } catch (err: any) {
    errorMsg.value = err.message || 'Credenciales incorrectas';
  } finally { 
    loading.value = false; 
  }
};

const handleRegister = async () => {
  if (!username.value || !password.value || !address.value) { 
    errorMsg.value = 'Completa todos los campos, incluyendo la dirección textual'; 
    return; 
  }
  loading.value = true; 
  errorMsg.value = ''; 
  successMsg.value = '';

  try {
    const getPosition = (): Promise<GeolocationPosition> => new Promise((res, rej) => {
      if (!navigator.geolocation) return rej(new Error('Geolocalización no soportada en este navegador.'));
      navigator.geolocation.getCurrentPosition(res, rej, { timeout: 10000, enableHighAccuracy: true });
    });

    let lat: number, lon: number;
    try {
      const pos = await getPosition();
      lat = pos.coords.latitude;
      lon = pos.coords.longitude;
    } catch (e: any) {
      throw new Error('Es obligatorio permitir el acceso a tu ubicación para registrarte. ' + (e.message || ''));
    }

    await authService.register({ 
      nombreUsuario: username.value, 
      contrasena: password.value, 
      direccion: address.value,
      latitud: lat, 
      longitud: lon 
    });
    
    successMsg.value = 'Cuenta creada con éxito. Ahora puedes iniciar sesión.';
    mode.value = 'login';
    password.value = '';
    address.value = '';
  } catch (err: any) {
    errorMsg.value = err.message || 'Error al intentar registrarse.';
  } finally { 
    loading.value = false; 
  }
};

const submit = () => mode.value === 'login' ? handleLogin() : handleRegister();
</script>

<template>
  <div class="login-page">
    <div class="login-card">
      <div class="logo">
        <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" class="feather feather-check-square"><polyline points="9 11 12 14 22 4"></polyline><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"></path></svg>
      </div>
      <h1>TaskMaster</h1>
      <p class="subtitle">Gestión inteligente de tareas</p>

      <div class="tab-row">
        <button :class="{ active: mode === 'login' }" @click="mode = 'login'; errorMsg = ''; successMsg = ''">Ingresar</button>
        <button :class="{ active: mode === 'register' }" @click="mode = 'register'; errorMsg = ''; successMsg = ''">Registrarse</button>
      </div>

      <div class="form">
        <label>Usuario</label>
        <input v-model="username" type="text" placeholder="Tu nombre de usuario" @keyup.enter="submit">
        
        <label>Contraseña</label>
        <input v-model="password" type="password" placeholder="••••••••" @keyup.enter="submit">

        <template v-if="mode === 'register'">
          <label>Dirección (Texto)</label>
          <input v-model="address" type="text" placeholder="Ej: Av. Alameda 3363, Santiago" @keyup.enter="submit">
          <p class="location-note">
            <svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path><circle cx="12" cy="10" r="3"></circle></svg>
            Se te pedirá acceso a tu ubicación GPS al registrarte.
          </p>
        </template>

        <div v-if="errorMsg" class="msg error">
          {{ errorMsg }}
        </div>
        <div v-if="successMsg" class="msg success">
          {{ successMsg }}
        </div>

        <button class="btn-primary" :disabled="loading" @click="submit">
          <span v-if="loading" class="spinner"></span>
          <span v-else>{{ mode === 'login' ? 'INICIAR SESIÓN' : 'CREAR CUENTA' }}</span>
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.login-page { 
  height: 100vh; 
  display: flex; 
  align-items: center; 
  justify-content: center; 
  background: radial-gradient(circle at 50% -20%, #1e293b 0%, #0f172a 80%); 
}

.login-card { 
  background: rgba(30, 41, 59, 0.6); 
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  padding: 40px; 
  border-radius: var(--radius); 
  border: 1px solid rgba(255, 255, 255, 0.05); 
  width: 100%;
  max-width: 400px; 
  text-align: center; 
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
}

.logo { 
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 56px;
  height: 56px;
  background: linear-gradient(135deg, var(--primary), var(--purple));
  color: white;
  border-radius: 16px;
  margin-bottom: 16px;
  box-shadow: 0 10px 25px -5px rgba(99, 102, 241, 0.4);
}

h1 { 
  margin-bottom: 4px; 
  font-size: 24px; 
  font-weight: 700;
  letter-spacing: -0.5px;
}

.subtitle { 
  color: var(--text-dim); 
  font-size: 14px; 
  margin-bottom: 32px; 
}

.tab-row { 
  display: flex; 
  background: rgba(15, 23, 42, 0.6);
  padding: 4px;
  margin-bottom: 24px; 
  border-radius: 10px; 
}

.tab-row button { 
  flex: 1; 
  padding: 10px; 
  background: transparent; 
  border: none; 
  color: var(--text-dim); 
  cursor: pointer; 
  font-size: 13px; 
  font-weight: 600; 
  border-radius: 8px;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); 
}

.tab-row button:hover:not(.active) {
  color: var(--text);
}

.tab-row button.active { 
  background: var(--bg-card); 
  color: #fff; 
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}

.form { 
  display: flex; 
  flex-direction: column; 
  text-align: left; 
}

label { 
  font-size: 12px; 
  font-weight: 600;
  color: var(--text-dim); 
  margin-bottom: 6px; 
}

input { 
  background: rgba(15, 23, 42, 0.6); 
  border: 1px solid rgba(255,255,255,0.1); 
  color: var(--text); 
  padding: 12px 16px; 
  border-radius: 8px; 
  margin-bottom: 16px; 
  font-size: 14px; 
  outline: none; 
  transition: all 0.2s; 
}

input:focus { 
  border-color: var(--primary); 
  box-shadow: 0 0 0 2px rgba(99, 102, 241, 0.2);
}

.location-note {
  font-size: 12px;
  color: var(--text-dim);
  display: flex;
  align-items: center;
  gap: 6px;
  margin-top: -8px;
  margin-bottom: 16px;
}

.msg { 
  font-size: 13px; 
  text-align: left; 
  margin-bottom: 16px; 
  padding: 12px; 
  border-radius: 8px; 
  display: flex;
  align-items: center;
  gap: 8px;
}

.msg.error { 
  color: #fca5a5; 
  background: rgba(239, 68, 68, 0.1); 
  border: 1px solid rgba(239, 68, 68, 0.2);
}

.msg.success { 
  color: #86efac; 
  background: rgba(16, 185, 129, 0.1); 
  border: 1px solid rgba(16, 185, 129, 0.2);
}

.btn-primary { 
  background: var(--primary); 
  color: #fff; 
  border: none; 
  padding: 14px; 
  border-radius: 8px; 
  font-weight: 600; 
  cursor: pointer; 
  font-size: 14px; 
  transition: all 0.2s; 
  margin-top: 4px; 
  display: flex;
  justify-content: center;
  align-items: center;
}

.btn-primary:hover:not(:disabled) { 
  background: var(--primary-hover); 
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(99, 102, 241, 0.3);
}

.btn-primary:active:not(:disabled) {
  transform: translateY(0);
}

.btn-primary:disabled { 
  opacity: 0.7; 
  cursor: not-allowed; 
}

.spinner {
  width: 20px;
  height: 20px;
  border: 2px solid rgba(255,255,255,0.3);
  border-radius: 50%;
  border-top-color: #fff;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>
