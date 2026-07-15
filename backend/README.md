# Backend — API RESTful de Gestión de Tareas (Control 2 TBD 1-2026)

API REST desarrollada en **Spring Boot 3 (Java 17)** con acceso a datos mediante
**SQL explícito (`NamedParameterJdbcTemplate`, sin ORM)**, autenticación **JWT**,
contraseñas con **BCrypt** y consultas espaciales **PostGIS**.

## Requisitos

- Java 17+
- Maven 3.8+ (o usar el Dockerfile incluido)
- La base de datos del proyecto corriendo (ver `INSTRUCCIONES DE EJECUCION.txt`
  en la raíz: `docker compose up -d` + `dbCreate.sql` + `loadData.sql`)

## Ejecución en desarrollo

```bash
cd backend
mvn spring-boot:run
```

La API queda en `http://localhost:8080`. La configuración por defecto apunta a
`jdbc:postgresql://localhost:5435/tareas_db` (el puerto que expone el
docker-compose del proyecto). Todo es configurable por variables de entorno:
`DB_URL`, `DB_USER`, `DB_PASSWORD`, `JWT_SECRET`, `JWT_EXPIRATION_MS`,
`CORS_ORIGIN`, `SERVER_PORT`.

## Seguridad

- **Autenticación**: JWT (HS256) emitido en el login. Toda ruta fuera de
  `/api/auth/**` exige header `Authorization: Bearer <token>` (middleware
  `JwtAuthFilter`).
- **Autorización**: cada consulta de tareas/notificaciones filtra por el
  `id_usuario` extraído del token; un usuario no puede ver ni modificar
  recursos de otro.
- **Inyección SQL**: todas las consultas usan parámetros nombrados
  (prepared statements); nunca se concatena entrada del usuario en el SQL.
- **CSRF**: deshabilitado de forma justificada — la API es stateless y el
  token viaja en el header `Authorization`, que el navegador no adjunta
  automáticamente (a diferencia de las cookies de sesión), por lo que el
  vector CSRF no aplica.
- **Contraseñas**: hasheadas con BCrypt; nunca se almacenan ni retornan en claro.

## Endpoints

### Autenticación (públicos)

| Método | Ruta | Cuerpo |
|---|---|---|
| POST | `/api/auth/register` | `{"nombreUsuario","contrasena","latitud","longitud"}` (el punto ES la dirección geográfica) |
| POST | `/api/auth/login` | `{"nombreUsuario","contrasena"}` → `{"token","id","nombreUsuario"}` |

Ejemplo:

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"nombreUsuario":"admin","contrasena":"admin123"}'
```

### Tareas (requieren token)

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/tareas?estado=pendiente\|completada&buscar=palabra` | Lista con filtros y búsqueda por palabra clave |
| POST | `/api/tareas` | Crear: `{"titulo","descripcion","fechaVencimiento":"2026-07-20","idSector":1}` |
| PUT | `/api/tareas/{id}` | Editar título, descripción, vencimiento y sector |
| DELETE | `/api/tareas/{id}` | Eliminar |
| PATCH | `/api/tareas/{id}/completar` | Marcar como completada |

### Sectores y notificaciones (requieren token)

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/api/sectores` | Sectores con latitud/longitud |
| POST | `/api/sectores` | Crear sector: `{"nombre","latitud","longitud"}` (nombre único) |
| GET | `/api/notificaciones` | Notificaciones del usuario (genera las de tareas que vencen en ≤3 días) |
| PATCH | `/api/notificaciones/{id}/leer` | Marcar como leída |

### Estadísticas espaciales (requieren token — TODAS privadas)

Cada respuesta se calcula exclusivamente con las tareas del usuario del token.
Las preguntas del enunciado formuladas "por cada usuario" se responden con
estas mismas rutas, evaluadas en la sesión de cada usuario.

| Ruta | Pregunta del enunciado |
|---|---|
| GET `/api/estadisticas/tareas-por-sector` | ¿Cuántas tareas ha hecho el usuario por sector? (también responde la versión "cada usuario", por sesión) |
| GET `/api/estadisticas/tarea-mas-cercana` | ¿Cuál es la tarea pendiente más cercana al usuario? (KNN + `ST_Distance`) |
| GET `/api/estadisticas/sector-mas-completadas?radioKm=2` | ¿Sector con más completadas en un radio de 2 km? (`ST_DWithin`) |
| GET `/api/estadisticas/sector-mas-completadas?radioKm=5` | Ídem con radio de 5 km |
| GET `/api/estadisticas/promedio-distancia` | ¿Promedio de distancia de las completadas? (también la versión "por usuario", por sesión) |
| GET `/api/estadisticas/clusters-pendientes?k=3` | ¿Dónde se concentran las pendientes? (`ST_ClusterKMeans`; incluye centro y radio en metros para el mapa) |

## Estructura del código

```
backend/src/main/java/cl/usach/tareas/
├── TareasApplication.java      # punto de entrada
├── config/SecurityConfig.java  # rutas protegidas, CORS, BCrypt, CSRF
├── security/                   # JwtUtil, JwtAuthFilter (middleware), principal
├── dto/                        # records de entrada/salida validados
├── repository/                 # SQL explícito parametrizado (sin ORM)
├── service/                    # lógica de negocio (auth, tareas)
└── controller/                 # endpoints REST + manejador global de errores
```

## Docker

```bash
docker build -t tareas-backend ./backend
docker run -p 8080:8080 -e DB_URL=jdbc:postgresql://host.docker.internal:5435/tareas_db tareas-backend
```

(En la fase final el backend se integrará al `docker-compose.yml` junto a la
base de datos y el frontend.)
