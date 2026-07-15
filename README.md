# Tareas Territoriales — Control 2, Taller de Base de Datos 1-2026

Sistema de gestión de tareas georreferenciadas. Los usuarios se registran con su
ubicación geográfica (punto PostGIS), crean y gestionan tareas asociadas a
sectores de trabajo también georreferenciados (construcción, semáforos, calles,
etc.), reciben notificaciones de vencimiento y consultan estadísticas
espaciales (distancias, radios, agrupaciones) calculadas con PostGIS.

## Arquitectura y tecnologías

Arquitectura desacoplada de tres capas:

```
┌─────────────────┐   HTTP/JSON    ┌──────────────────┐    SQL     ┌──────────────────────┐
│  FRONTEND        │ ─────────────▶ │  BACKEND          │ ─────────▶ │  BASE DE DATOS        │
│  Vue 3 + Vite    │  JWT en header │  Spring Boot 3    │  JDBC      │  PostgreSQL 16        │
│  Leaflet (mapas) │ ◀───────────── │  API RESTful      │ ◀───────── │  + PostGIS 3.4        │
│  nginx (prod)    │                │  Java 17          │            │  (puntos, triggers)   │
└─────────────────┘                └──────────────────┘            └──────────────────────┘
```

| Capa | Tecnología | Detalle |
|---|---|---|
| Frontend | Vue 3 (Composition API) + Vite | Componentes reutilizables, Vue Router, Axios, Leaflet para mapas |
| Backend | Spring Boot 3 (Java 17) | API RESTful, Spring Security + JWT, `NamedParameterJdbcTemplate` con **SQL explícito (sin ORM)** |
| Base de datos | PostgreSQL 16 + PostGIS 3.4 | Puntos `GEOMETRY(Point, 4326)`, índices GIST, trigger de notificaciones |
| Despliegue | Docker Compose | 3 contenedores; nginx sirve el frontend y hace proxy de `/api` al backend |

## Estructura del repositorio

```
.
├── dbCreate.sql              # Esquema: tablas, índices GIST, función y trigger
├── loadData.sql              # Datos de prueba (usuarios, sectores, 30 tareas en Santiago)
├── runStatements.sql         # Las 8 consultas espaciales del enunciado, comentadas
├── docker-compose.yml        # Despliegue completo (db + backend + frontend)
├── backend/                  # API Spring Boot (ver backend/README.md: doc de la API)
├── frontend/                 # Aplicación Vue 3
├── GUIA_DE_DEFENSA.md        # Explicación de cada elemento del proyecto (para estudiar)
└── INSTRUCCIONES DE EJECUCION.txt   # Versión corta de este manual
```

## Manual de instalación y despliegue

### Requisito único

Tener instalado **Docker** (con Docker Compose v2, incluido en Docker Desktop).
No se necesita instalar Java, Maven, Node ni PostgreSQL: todo se compila y
ejecuta dentro de los contenedores.

### Opción A — Despliegue completo con Docker (recomendada)

1. Abrir una terminal en la carpeta raíz del proyecto (donde está
   `docker-compose.yml`).

2. Levantar todo:

   ```bash
   docker compose up -d --build
   ```

   La primera ejecución tarda varios minutos: descarga las imágenes, compila el
   backend con Maven y el frontend con Node dentro de Docker. Las siguientes
   ejecuciones son casi inmediatas.

3. La base de datos se **crea y carga sola** la primera vez: el contenedor de
   PostGIS ejecuta automáticamente `dbCreate.sql` y `loadData.sql` (montados en
   `/docker-entrypoint-initdb.d`). El backend espera a que la base de datos
   esté sana (healthcheck) antes de arrancar.

4. Verificar que los tres servicios estén arriba:

   ```bash
   docker compose ps
   ```

5. Abrir la aplicación:

   | Servicio | URL |
   |---|---|
   | Aplicación web | http://localhost:8081 |
   | API REST | http://localhost:8080 |
   | PostgreSQL | localhost:5435 — usuario `postgres`, contraseña `postgres`, BD `tareas_db` |

6. Iniciar sesión con un usuario de prueba o registrar uno nuevo (el registro
   pide marcar la ubicación en el mapa):

   | Usuario | Contraseña |
   |---|---|
   | admin | admin123 |
   | mzapata, cfuentes, jperez, vrojas | clave123 |

Para **detener**: `docker compose down`. Para **reiniciar la base de datos
desde cero** (vuelve a ejecutar los scripts): `docker compose down -v` y luego
`docker compose up -d --build`.

### Opción B — Desarrollo local (BD en Docker, backend y frontend nativos)

Requiere Java 17+, Maven 3.8+ y Node 18+.

```bash
# 1. Solo la base de datos
docker compose up -d db

# 2. Backend (queda en http://localhost:8080)
cd backend
mvn spring-boot:run

# 3. Frontend (queda en http://localhost:5173; Vite redirige /api al backend)
cd frontend
npm install
npm run dev
```

### Ejecutar las 8 consultas del enunciado por consola (opcional)

```bash
docker exec -i control-2-bda-2026-1-db-1 psql -U postgres -d tareas_db < runStatements.sql
```

Si el nombre del contenedor difiere (depende del nombre de la carpeta),
verificarlo con `docker ps`.

### Problemas frecuentes

- **"port is already allocated"**: otro proceso usa 5435, 8080 u 8081. Cambiar
  el lado izquierdo del mapeo de puertos en `docker-compose.yml`.
- **La BD quedó a medias** (por ejemplo se interrumpió la primera carga): los
  scripts de `initdb.d` solo corren con el volumen vacío. Ejecutar
  `docker compose down -v` y volver a levantar.
- **El mapa se ve gris**: las teselas del mapa vienen de OpenStreetMap; se
  requiere conexión a internet en el navegador.

## Documentación de la API

La referencia completa con ejemplos de JSON está en
[`backend/README.md`](backend/README.md). Resumen:

| Método y ruta | Descripción | Autenticación |
|---|---|---|
| POST `/api/auth/register` | Registro con nombre, contraseña y coordenadas (punto PostGIS) | Pública |
| POST `/api/auth/login` | Entrega el JWT | Pública |
| GET `/api/usuarios/me` | Perfil y coordenadas del usuario autenticado | JWT |
| GET `/api/tareas?estado=&buscar=` | Lista con filtro por estado y búsqueda por palabra clave | JWT |
| POST `/api/tareas` | Crear tarea (título, descripción, vencimiento, sector) | JWT |
| PUT `/api/tareas/{id}` | Editar tarea | JWT |
| DELETE `/api/tareas/{id}` | Eliminar tarea | JWT |
| PATCH `/api/tareas/{id}/completar` | Marcar como completada | JWT |
| GET `/api/sectores` | Sectores georreferenciados | JWT |
| GET `/api/notificaciones` | Avisos de tareas por vencer (≤ 3 días) | JWT |
| PATCH `/api/notificaciones/{id}/leer` | Marcar aviso como leído | JWT |
| GET `/api/estadisticas/...` | Las 8 preguntas del enunciado (ver tabla siguiente) | JWT |

Endpoints de estadísticas — **todas privadas** (cada una se calcula solo con
las tareas del usuario autenticado; las preguntas "por cada usuario" del
enunciado se responden con la misma ruta evaluada en la sesión de cada uno):

| Endpoint | Pregunta |
|---|---|
| `/api/estadisticas/tareas-por-sector` | Tareas hechas por el usuario por sector |
| `/api/estadisticas/tarea-mas-cercana` | Tarea pendiente más cercana (KNN + `ST_Distance`) |
| `/api/estadisticas/sector-mas-completadas?radioKm=2` | Sector con más completadas en 2 km (`ST_DWithin`) |
| `/api/estadisticas/sector-mas-completadas?radioKm=5` | Ídem en 5 km |
| `/api/estadisticas/promedio-distancia` | Promedio de distancia de las completadas |
| `/api/estadisticas/clusters-pendientes?k=3` | Concentración espacial de pendientes (`ST_ClusterKMeans`, con radio en metros para el mapa) |

**Interpretación del modelo** (documentada también en la guía de defensa): un
*sector* es una **zona de operaciones** — un foco de obra físico y
georreferenciado en la ciudad (ej. "Semáforo dañado — Plaza de Armas") — y las
*tareas* son los quehaceres concretos que la cuadrilla ejecuta en esa zona.
Esto resuelve la aparente paradoja del enunciado (una categoría abstracta como
"construcción" no vive en una coordenada) y hace física la pregunta de la
tarea más cercana.

Ejemplo de uso con `curl`:

```bash
# 1. Login
TOKEN=$(curl -s -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"nombreUsuario":"admin","contrasena":"admin123"}' | python3 -c "import sys,json;print(json.load(sys.stdin)['token'])")

# 2. Tarea pendiente más cercana (P2)
curl -s http://localhost:8080/api/estadisticas/tarea-mas-cercana \
  -H "Authorization: Bearer $TOKEN"
```

## Cumplimiento de requisitos del enunciado

| Requisito | Dónde está implementado |
|---|---|
| Registro con punto geoespacial (PostGIS) | `RegistroView.vue` (GPS con ajuste en mapa; si se rechaza, mapa centrado en Santiago) → `POST /api/auth/register` → `UsuarioRepository.insertar` con `ST_SetSRID(ST_MakePoint(lng, lat), 4326)` |
| Crear / editar / eliminar / completar / listar tareas | `TareasView.vue` + `TareaController` + `TareaRepository` |
| Filtros por estado y búsqueda por palabra clave | `FiltrosBarra.vue` → query params → SQL con `ILIKE` parametrizado |
| Notificaciones de vencimiento | Trigger `trg_notificar_vencimiento` (dbCreate.sql) + `GET /api/notificaciones` + campana en la interfaz |
| Sectores georreferenciados | Tabla `sector` con `GEOMETRY(Point, 4326)`; asociación por FK en `tarea`; creación desde la app con el mismo flujo GPS/mapa (`POST /api/sectores`) |
| Las 8 preguntas con funciones PostGIS | `runStatements.sql` y `EstadisticaRepository` (`ST_Distance`, `ST_DWithin`, operador KNN `<->`, `ST_ClusterKMeans`, `ST_Centroid`, `ST_ClosestPoint`) |
| Frontend Vue con componentes reutilizables | `frontend/src/components/` (TareaCard, TareaForm, FiltrosBarra, PanelNotificaciones, MapaSelector, MapaSectores, BarraNavegacion) |
| Backend API RESTful en Spring | `backend/` (Spring Boot 3; acceso a datos con SQL explícito, sin ORM, según la norma del curso) |
| Autenticación y autorización | JWT (middleware `JwtAuthFilter`) + autorización a nivel de datos: cada consulta filtra por el `id_usuario` del token |
| Protección contra inyección SQL | Todas las consultas usan parámetros nombrados (prepared statements); nunca se concatena entrada del usuario |
| Protección CSRF | API stateless con token en header `Authorization` (no en cookie): el vector CSRF no aplica; deshabilitado con justificación documentada en `SecurityConfig` |
| Despliegue en entorno de producción | Docker Compose: build multi-etapa, frontend optimizado servido por nginx con proxy inverso, healthcheck de BD |
| Documentación | Este README + `backend/README.md` (API) + `GUIA_DE_DEFENSA.md` (explicación de cada elemento) |

## Créditos

Proyecto para el curso Taller de Base de Datos Diurno 1-2026,
Departamento de Ingeniería Informática, Universidad de Santiago de Chile.
