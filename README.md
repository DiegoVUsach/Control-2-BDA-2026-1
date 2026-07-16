# Aplicación de Tareas Territoriales

Integrantes: Sebastian Salles, Martin Fuentes, Diego Vega, Ignacio Caro


Sistema de gestion de tareas con datos geograficos. El usuario se registra con
su ubicacion, que se guarda como un punto PostGIS, crea tareas asociadas a zonas (sectores) de trabajo (tambien georreferenciadas), 
recibe avisos cuando una tareaesta por vencer, y puede ver estadisticas.
(distancias, radios y agrupaciones).

Parte del enunciado estaba abierto a interpretación y se decidió trabajar los sectores como
una "tarea principal" a la cual se le asignan sub-tareas. Nos imaginamos un trabajador que le asignan
el sector Alameda con Victor Jara, título "Reparar semáforo", luego de creado ese sector Reparar Semáforo asociado a ese punto geográfico
 se empiezan a asignar tareas como: comprar semáforo, desmontar semáforo antiguo, conectar cables, etc.

(En el enunciado decia que sector debe ser por ejemplo: construcción, pero "construcción" no tiene sentido asociarlo
a solo un lugar en el mapa, ya que construcción se puede realizar en distintas zonas de la ciudad, es por esto que se 
decidió con el diseño mencionado)

## Tecnologias

- Frontend: Vue 3 con Vite, Vue Router, Axios y Leaflet para los mapas
- Backend: Spring Boot 3 (Java 17), API REST, Spring Security con JWT
- Base de datos: PostgreSQL 16 con PostGIS 3.4
- Acceso a datos: JdbcTemplate con SQL escrito a mano, sin ORM (norma del curso)
- Despliegue: Docker Compose (base de datos, backend y frontend con nginx)

## Estructura


dbCreate.sql          Tablas, indices GIST, funcion y trigger
loadData.sql          Datos de prueba: 9 usuarios, 19 zonas, 177 tareas
runStatements.sql     Las consultas del enunciado
docker-compose.yml    Levanta los tres servicios
backend/              API en Spring Boot
frontend/             Aplicacion Vue


## Como levantarlo

Solo se necesita Docker instalado (con Docker Compose). No hace falta instalar Java, Maven, Node ni PostgreSQL: todo se compila dentro de los contenedores.

En consola en la carpeta del proyecto:
docker compose up -d --build


La primera vez demora varios minutos porque descarga las imagenes y compila el backend y el frontend. La base de datos se crea y se llena sola: el contenedor
de PostGIS ejecuta `dbCreate.sql` y `loadData.sql` al arrancar por primera vez. El backend espera a que la base este lista antes de partir.

Cuando termine:

| Aplicacion | http://localhost:8081 |
| API | http://localhost:8080 |
| Base de datos | localhost:5435, usuario `postgres`, clave `postgres`, BD `tareas_db` |

Para detener: `docker compose down`.
Para reiniciar la base desde cero: `docker compose down -v` y volver a levantar.

## Usuarios de prueba

| Usuario | Clave | Ubicacion |
|---|---|---|
| admin | admin123 | USACH, Estacion Central |
| mzapata | clave123 | Providencia |
| cfuentes | clave123 | Maipu |
| jperez | clave123 | La Florida |
| vrojas | clave123 | Las Condes |
| rmorales | clave123 | Nunoa |
| avaldes | clave123 | Puente Alto |
| ktapia | clave123 | Quilicura |
| pgomez | clave123 | Pedro Aguirre Cerda |

Tambien se puede registrar un usuario nuevo. El registro pide marcar la ubicacion en el mapa (usa el GPS del navegador y se puede ajustar a mano.
Si se rechaza el permiso, el mapa parte centrado en Santiago).


## Como esta armado el codigo

El backend sigue el esquema controller / service / repository. El controller recibe la peticion HTTP, 
el service tiene las reglas (por ejemplo que el nombre de usuario no se repita, o hashear la clave antes de guardarla) y el repository es el unico lugar donde hay SQL.

El frontend separa vistas de componentes. Las vistas (`TareasView`, `EstadisticasView`, `MapaView`) son las que llaman a la API. 
Los componentes (`TareaCard`, `TareaForm`, `FiltrosBarra`, `PanelNotificaciones`, `MapaSelector`, `MapaSectores`, `BarraNavegacion`) reciben datos por props 
y avisan hacia arriba con eventos, asi que se pueden reutilizar. `TareaForm`, por ejemplo, es el mismo componente para crear y para editar.

Los filtros y la busqueda se resuelven en la base de datos, no en el navegador:
la barra de filtros cambia los parametros de `GET /api/tareas` y el `WHERE` se arma en SQL.

## Endpoints

| Metodo y ruta | Que hace | Auth |
|---|---|---|
| POST `/api/auth/register` | Registro con nombre, clave y coordenadas | Publica |
| POST `/api/auth/login` | Devuelve el JWT | Publica |
| GET `/api/usuarios/me` | Perfil y coordenadas del usuario | JWT |
| GET `/api/tareas?estado=&buscar=` | Lista con filtro y busqueda | JWT |
| POST `/api/tareas` | Crear tarea | JWT |
| PUT `/api/tareas/{id}` | Editar tarea | JWT |
| DELETE `/api/tareas/{id}` | Eliminar tarea | JWT |
| PATCH `/api/tareas/{id}/completar` | Marcar como completada | JWT |
| GET `/api/sectores` | Zonas georreferenciadas | JWT |
| POST `/api/sectores` | Crear una zona | JWT |
| GET `/api/notificaciones` | Avisos de tareas por vencer | JWT |
| PATCH `/api/notificaciones/{id}/leer` | Marcar aviso como leido | JWT |
| GET `/api/estadisticas/...` | Las preguntas del enunciado (ver abajo) | JWT |



## Las preguntas del enunciado

| Pregunta | Endpoint | PostGIS usado |
|---|---|---|
| Cuantas tareas ha hecho el usuario por sector | `/estadisticas/tareas-por-sector` | JOIN y GROUP BY |
| Tarea pendiente mas cercana | `/estadisticas/tarea-mas-cercana` | operador `<->` y `ST_Distance` |
| Sector con mas completadas en 2 km | `/estadisticas/sector-mas-completadas?radioKm=2` | `ST_DWithin` |
| Sector con mas completadas en 5 km | `/estadisticas/sector-mas-completadas?radioKm=5` | `ST_DWithin` |
| Promedio de distancia de las completadas | `/estadisticas/promedio-distancia` | `AVG(ST_Distance(...))` |
| Donde se concentran las pendientes | `/estadisticas/clusters-pendientes?k=3` | `ST_ClusterKMeans`, `ST_Collect`, `ST_Centroid` |
| Cuantas tareas ha realizado cada usuario por sector | `/estadisticas/tareas-por-usuario-sector` | JOIN y GROUP BY |
| (apoyo del mapa) zonas con pendientes y su grupo | `/estadisticas/pendientes-por-zona` | `ST_ClusterKMeans` |
| (apoyo del mapa) zonas con completadas y radios | `/estadisticas/completadas-por-zona` | `ST_DWithin` y `ST_Distance` |

Las mismas consultas estan en `runStatements.sql`, comentadas, para correrlas directo en el motor:

```bash
docker exec -i control-2-bda-2026-1-db-1 psql -U postgres -d tareas_db < runStatements.sql
```
