# Guía de defensa — entender cada elemento del proyecto

Este documento explica **por qué** el proyecto está construido como está, capa
por capa, con las preguntas típicas de defensa al final. La idea es que puedas
justificar cualquier decisión sin memorizar código.

---

## 1. Base de datos

### 1.1 El modelo (4 tablas)

- **usuario**: credenciales + `ubicacion GEOMETRY(Point, 4326)`. La contraseña
  se guarda como *hash* BCrypt, nunca en claro.
- **sector**: los tipos de trabajo (construcción, semáforos, calles…), cada uno
  con su propio punto georreferenciado, como exige el Requisito 5.
- **tarea**: título, descripción, `fecha_vencimiento`, `completada`,
  `fecha_completada`, y dos claves foráneas: `id_usuario` (dueño) e `id_sector`.
- **notificacion**: avisos de vencimiento, con FK a usuario y tarea.

**Interpretación del modelo (la "paradoja" del enunciado):** el enunciado
ejemplifica sectores como "construcción" o "semáforos" y a la vez exige que
cada sector tenga UNA ubicación espacial — pero un rubro abstracto no vive en
una coordenada. La interpretación adoptada: un **sector es una zona de
operaciones**, un foco de obra físico en la ciudad (ej. "Semáforo dañado —
Plaza de Armas"), y por eso tiene un punto georreferenciado con todo sentido.
Las **tareas son los quehaceres** de esa zona (pedir repuestos, instalar,
pintar), con vencimiento y estado propios. Bajo esta narrativa la ubicación
pertenece a la zona, el usuario tiene la suya, y "la tarea más cercana"
significa literalmente a qué lugar conviene ir primero.

**Privacidad:** todas las estadísticas son privadas — cada consulta se evalúa
con el `id_usuario` del token, incluidas las preguntas formuladas "por cada
usuario", que se responden con la misma consulta ejecutada en la sesión de
cada uno. Un usuario jamás ve tareas ni métricas ajenas.

**Sin dirección textual:** la "dirección geográfica" del enunciado SE
MATERIALIZA como el punto PostGIS, capturado con GPS (con ajuste fino en el
mapa) o con un clic si el GPS se rechaza (mapa centrado en Santiago). Un campo
de texto libre no aporta datos consultables y exigiría geocodificación externa.

### 1.2 ¿Qué es SRID 4326?

Un SRID identifica el sistema de referencia de coordenadas. **4326 = WGS 84**,
el sistema de GPS: latitud/longitud en grados. Es el estándar para guardar
puntos del mundo real. Ojo con el orden: PostGIS usa `ST_MakePoint(longitud,
latitud)` — X primero (longitud), Y después (latitud).

### 1.3 geometry vs geography (la pregunta clásica)

- `GEOMETRY` trabaja sobre un **plano cartesiano**: rápido, pero con SRID 4326
  las distancias salen en **grados**, que no sirven para "un radio de 2 km".
- `GEOGRAPHY` trabaja sobre el **elipsoide terrestre**: `ST_Distance` devuelve
  **metros reales**.

Por eso las columnas se almacenan como `geometry` (más eficiente, permite
índices y todas las funciones) y en las consultas de distancia se hace el cast
`::geography`. Es el patrón recomendado.

### 1.4 Funciones PostGIS usadas (saber explicar cada una)

| Función | Qué hace | Dónde se usa |
|---|---|---|
| `ST_MakePoint(lng, lat)` + `ST_SetSRID(..., 4326)` | Construye el punto y le asigna el sistema de referencia | Registro de usuarios, carga de sectores |
| `ST_X` / `ST_Y` | Extraen longitud / latitud de un punto | Devolver coordenadas a la API sin librerías espaciales en Java |
| `ST_Distance(a::geography, b::geography)` | Distancia en metros sobre el elipsoide | P2, P3, P4, P7, P8 |
| `ST_DWithin(a::geography, b::geography, r)` | ¿Están a menos de `r` metros? — más eficiente que `ST_Distance < r` porque puede usar el índice | P3 (2 km) y P7 (5 km) |
| Operador `<->` (KNN) | Ordena por cercanía usando el índice GIST; ideal para "el más cercano" | P2 (ORDER BY ... LIMIT 1) |
| `ST_ClusterKMeans(geom, k) OVER ()` | Función de ventana: asigna cada punto a uno de k clusters espaciales | P5 (concentración de pendientes) |
| `ST_Collect` + `ST_Centroid` | Junta puntos y calcula su centro | Centro de cada cluster en P5 |
| `ST_ClosestPoint(g1, g2)` | Punto de g1 más cercano a g2 | Consulta extra (el enunciado menciona la función) |

### 1.5 Índices

- **GIST sobre `usuario.ubicacion` y `sector.ubicacion`**: los índices B-Tree
  ordenan valores escalares y no sirven para datos 2D. GIST indexa cajas
  envolventes (R-Tree) y acelera `ST_DWithin` y el operador `<->`.
- B-Tree sobre `tarea.id_usuario`, `tarea.id_sector`, `tarea.completada`:
  columnas de filtros frecuentes (listados y joins).

### 1.6 Trigger de notificaciones

En `dbCreate.sql`: función `fn_notificar_vencimiento()` (PL/pgSQL) + trigger
`AFTER INSERT OR UPDATE OF fecha_vencimiento ON tarea`. Si la tarea queda con
vencimiento a ≤ 3 días y está pendiente, inserta una notificación. Es "lógica
de negocio en el motor": se cumple aunque alguien inserte tareas sin pasar por
la API. El backend lo **complementa**: al pedir `GET /api/notificaciones`
genera avisos para tareas cuyo vencimiento *se acercó con el paso del tiempo*
(el trigger solo ve inserciones/ediciones), evitando duplicados con
`NOT EXISTS`.

---

## 2. Backend (Spring Boot)

### 2.1 Arquitectura en capas

```
Controller  →  Service  →  Repository  →  PostgreSQL
(HTTP/JSON)    (reglas)     (SQL explícito)
```

- **Controller**: recibe/valida la petición HTTP y delega. No tiene SQL.
- **Service**: reglas de negocio (ej: "el nombre de usuario no puede repetirse",
  "hashear la contraseña antes de guardar").
- **Repository**: único lugar con SQL. Spring inyecta las dependencias por
  constructor (inversión de control).

### 2.2 ¿Por qué sin ORM?

Norma del curso (enunciados de laboratorio): no se permiten ORMs. Se usa
`NamedParameterJdbcTemplate` de Spring, que es un ayudante de JDBC, **no un
ORM**: nosotros escribimos cada SQL. Ventaja adicional: control total sobre las
funciones PostGIS, que en un ORM requieren extensiones especiales.

### 2.3 Seguridad — flujo JWT completo (esquema para la defensa)

1. `POST /api/auth/login` con usuario y contraseña.
2. El backend busca el usuario y compara con `BCrypt.matches(plano, hash)`.
3. Si coincide, firma un **JWT** con algoritmo **HS256** (clave secreta
   simétrica del servidor). El token lleva: `sub` (nombre de usuario), claim
   `id`, fecha de emisión y expiración (24 h).
4. El frontend guarda el token y lo adjunta en cada petición:
   `Authorization: Bearer <token>`.
5. El **middleware** `JwtAuthFilter` (un `OncePerRequestFilter`) intercepta
   cada petición, valida la firma y la expiración, y registra al usuario en el
   `SecurityContext`. Si el token es inválido → 401.
6. `SecurityConfig` define las reglas: `/api/auth/**` es público, todo lo demás
   exige autenticación.

Estructura de un JWT: `header.payload.firma` (tres bloques Base64). La firma
garantiza **integridad** (nadie puede alterar el payload sin la clave), pero el
payload **no va cifrado**: por eso jamás se mete la contraseña en el token.

### 2.4 Autorización (no basta con autenticar)

Autenticación = saber quién eres. Autorización = qué puedes hacer. Aquí la
autorización va **a nivel de datos**: cada consulta de tareas/notificaciones
incluye `WHERE id_usuario = :idUsuario` con el id **sacado del token** (no de
la URL ni del body, que el cliente podría falsear). Así un usuario no puede
leer, editar ni borrar tareas ajenas aunque adivine sus IDs.

### 2.5 Inyección SQL

Todas las consultas usan **parámetros nombrados** (`:titulo`, `:idUsuario`),
que JDBC convierte en *prepared statements*: el motor compila el SQL con
huecos y los valores viajan por separado como datos, nunca como código. Un
input malicioso como `'; DROP TABLE tarea; --` queda guardado como texto
literal. Incluso la búsqueda con `ILIKE` está parametrizada (el patrón `%...%`
se arma como *valor*, no concatenado al SQL).

### 2.6 CSRF — por qué está deshabilitado y cómo justificarlo

CSRF explota que el navegador **adjunta cookies automáticamente**: un sitio
malicioso hace que tu navegador dispare una petición al banco y la cookie de
sesión viaja sola. Nuestra API **no usa cookies**: el token va en el header
`Authorization`, que solo nuestro JavaScript agrega explícitamente. Un sitio
externo no puede forjar ese header. Por eso la protección CSRF de Spring
(pensada para sesiones con cookies) se deshabilita **con justificación**, que
está documentada en `SecurityConfig`. Frase para la defensa: *"no es que
ignoremos CSRF; es que nuestro diseño stateless con token en header elimina el
vector de ataque"*.

### 2.7 BCrypt — por qué no MD5/SHA

- Es **lento a propósito** (factor de costo configurable): frena ataques de
  fuerza bruta; MD5/SHA son rápidos, lo que favorece al atacante.
- Incluye **salt aleatorio** en cada hash: dos usuarios con la misma contraseña
  tienen hashes distintos → inutiliza las *rainbow tables*.
- El hash `$2a$10$...` codifica versión, costo y salt en el mismo string.

---

## 3. Frontend (Vue 3)

### 3.1 Componentes reutilizables (requisito explícito del enunciado)

| Componente | Responsabilidad | Por qué es "reutilizable" |
|---|---|---|
| `TareaCard` | Muestra una tarea | Recibe props, emite eventos; no llama a la API. Se instancia N veces en la grilla |
| `TareaForm` | Formulario en modal | El **mismo** componente sirve para crear (prop `tarea=null`) y editar |
| `FiltrosBarra` | Estado + búsqueda | v-model doble (`update:estado`, `update:buscar`) |
| `PanelNotificaciones` | Campana con avisos | Independiente de dónde se monte |
| `MapaSelector` | Elegir un punto (registro) | Emite `{lat, lng}` con v-model |
| `MapaSectores` | Visualizar sectores/usuario/clusters | Recibe todo por props |
| `BarraNavegacion` | Navegación y sesión | — |

Patrón central: **props hacia abajo, eventos hacia arriba**. Los componentes de
presentación no conocen la API; las vistas (`TareasView`, `EstadisticasView`)
orquestan las llamadas. Eso es lo que hace a los componentes reutilizables y
testeables.

### 3.2 Manejo de sesión en el cliente

- `auth.js`: estado reactivo compartido (token + usuario) persistido en
  `localStorage` para sobrevivir recargas.
- `api.js`: instancia de Axios con dos interceptores. El de **petición**
  adjunta `Authorization: Bearer <token>`; el de **respuesta** detecta 401
  (token vencido) y devuelve al login.
- `router.js`: guardia de navegación que exige sesión para las rutas privadas.
  Importante para la defensa: esta guardia es **usabilidad**, no seguridad; la
  seguridad real está en el backend (sin token válido, la API responde 401
  aunque alguien fuerce la ruta en el navegador).

### 3.3 Los mapas

Leaflet con teselas de OpenStreetMap. `MapaSelector` traduce un clic del mapa a
coordenadas que viajan al backend y terminan como `POINT` en PostGIS.
`MapaSectores` hace el camino inverso: puntos PostGIS → `ST_X`/`ST_Y` → JSON →
marcadores. Los círculos azules del mapa de estadísticas son los clusters de
`ST_ClusterKMeans` (P5), con radio proporcional a la cantidad de pendientes.

### 3.4 Filtros que filtran en la base de datos

La barra de filtros no oculta tarjetas en el navegador: cambia los *query
params* de `GET /api/tareas`, y el `WHERE` se arma en SQL. Con pocos datos
daría lo mismo, pero con miles de tareas filtrar en el cliente obligaría a
descargar todo; filtrar en la BD usa índices y transfiere solo lo necesario.

---

## 4. Despliegue (Docker Compose)

- **3 servicios**: `db` (imagen `postgis/postgis:16-3.4`), `backend`, `frontend`.
- **Inicialización automática**: los `.sql` se montan en
  `/docker-entrypoint-initdb.d`; la imagen oficial de Postgres los ejecuta en
  orden alfabético **solo la primera vez** (volumen vacío). Por eso
  "reiniciar la BD" = `docker compose down -v`.
- **Healthcheck + depends_on**: el backend arranca solo cuando `pg_isready`
  confirma que la BD acepta conexiones; evita el clásico fallo de carrera.
- **Builds multi-etapa**: el backend compila con Maven en una imagen y corre en
  otra solo con el JRE; el frontend compila con Node y se sirve con nginx.
  Resultado: imágenes finales livianas y sin herramientas de compilación.
- **nginx como proxy inverso**: sirve los estáticos de Vue y redirige `/api` al
  contenedor del backend. Ventajas: un solo origen (sin CORS en producción) y
  `try_files ... /index.html` para que el router de Vue funcione al recargar.
- Dentro de la red de Compose los servicios se resuelven **por nombre**
  (`db`, `backend`): por eso el backend usa `jdbc:postgresql://db:5432/...`.

---

## 5. Las 8 preguntas, en una frase cada una

1. **Tareas del usuario por sector**: `JOIN` + `GROUP BY sector` + `COUNT`,
   filtrando `completada = TRUE` y el usuario del token.
2. **Tarea pendiente más cercana**: `ORDER BY u.ubicacion <-> s.ubicacion
   LIMIT 1` (KNN con índice GIST) y `ST_Distance::geography` para informar los
   metros.
3. **Sector con más completadas en 2 km**: `ST_DWithin(..., 2000)` como filtro
   (usa índice) + `GROUP BY` + `ORDER BY COUNT DESC LIMIT 1`.
4. **Promedio de distancia de completadas**: `AVG(ST_Distance(...))` de las
   tareas completadas del usuario.
5. **Concentración espacial de pendientes**: `ST_ClusterKMeans(punto, 3) OVER ()`
   etiqueta cada tarea pendiente con un cluster; se agrupa por etiqueta y se
   calcula el centro con `ST_Centroid(ST_Collect(...))`.
6. **Cada usuario por sector**: por privacidad, la misma consulta de la 1
   evaluada con la sesión de cada usuario.
7. **Sector con más completadas en 5 km**: la misma consulta de la 3 con radio
   5000 — por eso el endpoint recibe `radioKm` como parámetro.
8. **Promedio de distancia por usuario**: la misma consulta de la 4, evaluada
   por cada sesión (privada).

---

## 6. Preguntas probables de la defensa (con respuesta corta)

**¿Por qué guardan geometry y no geography?**
Geometry es más eficiente y compatible con todas las funciones e índices; el
cast `::geography` se aplica solo al calcular distancias para obtener metros.

**¿Qué pasa si dos usuarios se registran con el mismo nombre?**
La columna tiene `UNIQUE`; además el service lo verifica antes y responde 400
con mensaje claro. Defensa en dos capas: la restricción de BD es la garantía
final.

**¿Dónde está el "middleware de autenticación"?**
`JwtAuthFilter`, registrado en la cadena de filtros de Spring Security antes
del filtro de autenticación estándar; corre en cada petición.

**¿Cómo evitan que un usuario edite tareas de otro?**
El `UPDATE/DELETE` incluye `AND id_usuario = :idUsuario` con el id del token;
si no calza, 0 filas afectadas → la API responde 404.

**¿Por qué el frontend guarda el token en localStorage y no en una cookie?**
Simplicidad y coherencia con el diseño stateless; con localStorage no hay envío
automático (inmune a CSRF). El trade-off honesto: localStorage es legible por
JS, así que la defensa contra XSS es no inyectar HTML sin escapar (Vue escapa
por defecto en `{{ }}`).

**¿Qué devuelve la API, geometry cruda?**
No: la API expone `latitud`/`longitud` planas extraídas con `ST_X`/`ST_Y`. El
formato binario interno (WKB) no le sirve al cliente. (Para el Lab 2 se puede
evolucionar a GeoJSON con `ST_AsGeoJSON`.)

**¿El sistema queda "desplegado en producción"?**
Sí, en un entorno de producción local: build optimizado (minificado) servido
por nginx, contenedores con restart automático, healthchecks y configuración
por variables de entorno. Llevarlo a un servidor real es copiar la carpeta y
correr el mismo `docker compose up -d --build`.

**¿Qué es un prepared statement?**
SQL precompilado con huecos; los valores llegan después como datos tipados. El
motor jamás interpreta el input como código: elimina la inyección SQL.

**¿Por qué `ST_DWithin` y no `ST_Distance(...) < radio`?**
Mismo resultado lógico, pero `ST_DWithin` está optimizada para usar el índice
espacial (descarta por caja envolvente antes de calcular distancias exactas);
`ST_Distance < r` obliga a calcular la distancia contra todas las filas.
