# Guía completa y autosuficiente — Control 2 TBD 1-2026

Esta guía reemplaza a las anteriores. Regla de oro de esta versión: **cada
bloque de código es UN ARCHIVO COMPLETO**, con su ruta exacta encima y, en el
caso de Java, con su línea `package` e imports incluidos. Puedes tipearlo o
pegarlo entero — nunca a medias. Si al pegar algo queda en rojo, la causa es
una de dos: no recargaste Maven, o el archivo está en una carpeta que no
coincide con su `package`.

Cómo usarla: sigue el orden. Los archivos están ordenados por dependencia
(cada uno solo usa cosas que ya existen), así IntelliJ nunca te ofrecerá
"Create class". En Alt+Enter elige siempre "Import class"; si solo ofrece
crear, detente: falta un archivo anterior o la recarga de Maven.

El backend usa el paquete `usach.cl.tareasbackend`: la carpeta de cada archivo
debe calzar con su package (`usach/cl/tareasbackend/security/`, etc.).
Para aprender de verdad: después de agregar cada archivo, léelo y di en voz
alta qué hace; los checkpoints te confirman que todo lo anterior funciona.
# FASE 0 — Preparación

Herramientas: Docker Desktop, IntelliJ IDEA (con tu correo institucional
tienes licencia de estudiante para Ultimate, que trae el asistente de Spring;
con Community también se puede, se indica cómo), Node 18+, y un JDK 17
(IntelliJ puede descargarlo por ti: File → Project Structure → SDK → Add SDK →
Download JDK → 17, vendor Temurin).

```bash
mkdir mi-control2 && cd mi-control2
git init
mkdir frontend    # backend/ lo creara IntelliJ en la Fase 2
```

---

# FASE 1 — Base de datos

## 1.1 Levantar PostGIS

`docker-compose.yml` en la raíz (por ahora solo la BD):

```yaml
services:
  db:
    image: postgis/postgis:16-3.4   # PostgreSQL 16 CON PostGIS ya instalado
    restart: always
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: tareas_db        # se crea sola al primer arranque
    ports:
      - "5435:5432"                 # puerto de tu PC : puerto interno
    volumes:
      - datos_db:/var/lib/postgresql/data

volumes:
  datos_db:
```

```bash
docker compose up -d
docker ps                                # anota el nombre del contenedor
docker exec -it mi-control2-db-1 psql -U postgres -d tareas_db
# dentro: SELECT PostGIS_Version();  debe responder 3.4. Sal con \q
```

## 1.2 `dbCreate.sql` — archivo completo

Escríbelo entendiendo: el orden de las tablas lo dictan las FK; SRID 4326 es
el sistema WGS84 de GPS; GIST para columnas espaciales (un B-Tree no indexa
datos 2D); el trigger es AFTER porque la notificación referencia por FK a una
tarea que en BEFORE aún no existiría.

```sql
-- ============================================================
-- CONTROL 2 - TALLER DE BASE DE DATOS 1-2026
-- Sistema de Gestion de Tareas con datos geoespaciales
-- Script de creacion de estructura (dbCreate.sql)
-- ============================================================
-- NOTA: Este script se ejecuta conectado a la base "tareas_db",
-- que el contenedor Docker crea automaticamente (POSTGRES_DB).
-- ============================================================

-- Habilitar la extension PostGIS para datos espaciales
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- TABLA: sector
-- Sectores de trabajo (construccion, semaforos, calles, etc.)
-- Cada sector esta georreferenciado con un punto (SRID 4326)
-- ============================================================
DROP TABLE IF EXISTS sector CASCADE;
CREATE TABLE sector (
    id_sector SERIAL,
    nombre VARCHAR(100) NOT NULL,
    ubicacion GEOMETRY(Point, 4326) NOT NULL,
    PRIMARY KEY (id_sector)
);

-- ============================================================
-- TABLA: usuario
-- Usuarios del sistema. La contrasena se guarda hasheada con
-- BCrypt (compatible con Spring Security). La ubicacion es un
-- punto geoespacial PostGIS (longitud, latitud - SRID 4326).
-- ============================================================
DROP TABLE IF EXISTS usuario CASCADE;
CREATE TABLE usuario (
    id_usuario SERIAL,
    nombre_usuario VARCHAR(100) NOT NULL UNIQUE,
    contrasena VARCHAR(255) NOT NULL,
    direccion VARCHAR(255) NOT NULL,
    ubicacion GEOMETRY(Point, 4326) NOT NULL,
    PRIMARY KEY (id_usuario)
);

-- ============================================================
-- TABLA: tarea
-- Tareas de cada usuario, asociadas a un sector georreferenciado
-- ============================================================
DROP TABLE IF EXISTS tarea CASCADE;
CREATE TABLE tarea (
    id_tarea SERIAL,
    titulo VARCHAR(150) NOT NULL,
    descripcion TEXT,
    fecha_vencimiento DATE NOT NULL,
    completada BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_completada TIMESTAMP,
    id_usuario INT NOT NULL,
    id_sector INT NOT NULL,
    PRIMARY KEY (id_tarea),
    FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
        ON DELETE CASCADE,
    FOREIGN KEY (id_sector)
        REFERENCES sector(id_sector)
);

-- ============================================================
-- TABLA: notificacion
-- Notificaciones generadas cuando se acerca la fecha de
-- vencimiento de una tarea (Requisito Funcional 4)
-- ============================================================
DROP TABLE IF EXISTS notificacion CASCADE;
CREATE TABLE notificacion (
    id_notificacion SERIAL,
    mensaje VARCHAR(255) NOT NULL,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT NOW(),
    leida BOOLEAN NOT NULL DEFAULT FALSE,
    id_usuario INT NOT NULL,
    id_tarea INT NOT NULL,
    PRIMARY KEY (id_notificacion),
    FOREIGN KEY (id_usuario)
        REFERENCES usuario(id_usuario)
        ON DELETE CASCADE,
    FOREIGN KEY (id_tarea)
        REFERENCES tarea(id_tarea)
        ON DELETE CASCADE
);

-- ============================================================
-- INDICES
-- Indices espaciales GIST para acelerar consultas PostGIS
-- e indices de apoyo para filtros frecuentes
-- ============================================================
CREATE INDEX idx_usuario_ubicacion ON usuario USING GIST (ubicacion);
CREATE INDEX idx_sector_ubicacion  ON sector  USING GIST (ubicacion);
CREATE INDEX idx_tarea_usuario     ON tarea (id_usuario);
CREATE INDEX idx_tarea_sector      ON tarea (id_sector);
CREATE INDEX idx_tarea_completada  ON tarea (completada);

-- ============================================================
-- FUNCION + TRIGGER: notificacion automatica de vencimiento
-- Genera una notificacion cuando una tarea se crea o edita y
-- su fecha de vencimiento esta a 3 dias o menos.
-- (El backend ademas consulta las tareas por vencer.)
-- ============================================================
CREATE OR REPLACE FUNCTION fn_notificar_vencimiento()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT NEW.completada
       AND NEW.fecha_vencimiento <= CURRENT_DATE + INTERVAL '3 days' THEN
        INSERT INTO notificacion (mensaje, id_usuario, id_tarea)
        VALUES (
            'La tarea "' || NEW.titulo || '" vence el ' ||
            TO_CHAR(NEW.fecha_vencimiento, 'DD-MM-YYYY'),
            NEW.id_usuario,
            NEW.id_tarea
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notificar_vencimiento ON tarea;
CREATE TRIGGER trg_notificar_vencimiento
AFTER INSERT OR UPDATE OF fecha_vencimiento ON tarea
FOR EACH ROW
EXECUTE FUNCTION fn_notificar_vencimiento();
```

**Prueba del trigger a mano** (en psql):

```sql
INSERT INTO sector (nombre, ubicacion)
VALUES ('Prueba', ST_SetSRID(ST_MakePoint(-70.65, -33.45), 4326));
INSERT INTO usuario (nombre_usuario, contrasena, direccion, ubicacion)
VALUES ('t', 'x', 'x', ST_SetSRID(ST_MakePoint(-70.65, -33.45), 4326));
INSERT INTO tarea (titulo, fecha_vencimiento, id_usuario, id_sector)
VALUES ('vence pronto', CURRENT_DATE + 2, 1, 1);
SELECT * FROM notificacion;   -- debe haber 1 fila
-- limpia antes de cargar los datos reales:
DELETE FROM tarea; DELETE FROM usuario; DELETE FROM sector;
```

## 1.3 `loadData.sql` — archivo completo

Dos detalles críticos: `ST_MakePoint(LONGITUD, LATITUD)` — X primero (en
Santiago: lng ≈ -70.6, lat ≈ -33.4); y las contraseñas van como hash BCrypt
`$2a$` para que el login de Spring funcione (admin123 y clave123).

```sql
-- ============================================================
-- CONTROL 2 - TALLER DE BASE DE DATOS 1-2026
-- Carga de datos de prueba (loadData.sql)
-- Coordenadas reales de Santiago de Chile (SRID 4326)
-- IMPORTANTE: ST_MakePoint(longitud, latitud)
-- ============================================================

-- ============================================================
-- SECTORES (georreferenciados en distintas comunas de Santiago)
-- ============================================================
INSERT INTO sector (nombre, ubicacion) VALUES
('Construccion',             ST_SetSRID(ST_MakePoint(-70.6520, -33.4460), 4326)), -- Estacion Central
('Reparacion de semaforos',  ST_SetSRID(ST_MakePoint(-70.6506, -33.4372), 4326)), -- Plaza de Armas
('Reparacion de calles',     ST_SetSRID(ST_MakePoint(-70.6109, -33.4263), 4326)), -- Providencia
('Areas verdes',             ST_SetSRID(ST_MakePoint(-70.6344, -33.4269), 4326)), -- Parque Forestal
('Alumbrado publico',        ST_SetSRID(ST_MakePoint(-70.7069, -33.4569), 4326)), -- Estacion Central poniente
('Recoleccion de residuos',  ST_SetSRID(ST_MakePoint(-70.7622, -33.5093), 4326)), -- Maipu
('Senaletica vial',          ST_SetSRID(ST_MakePoint(-70.5758, -33.4172), 4326)), -- Las Condes
('Ciclovias',                ST_SetSRID(ST_MakePoint(-70.5987, -33.5226), 4326)); -- La Florida

-- ============================================================
-- USUARIOS
-- Contrasenas hasheadas con BCrypt ($2a$, compatible con
-- Spring Security BCryptPasswordEncoder).
--   admin   -> admin123
--   resto   -> clave123
-- ============================================================
INSERT INTO usuario (nombre_usuario, contrasena, direccion, ubicacion) VALUES
('admin',
 '$2a$10$f/4X0aEGKQZRNR9LFXu.4eECC1oeNpTCWZd2fhyd4iS2ukV6iRnOe',
 'Av. Libertador Bernardo O''Higgins 3363, Estacion Central',
 ST_SetSRID(ST_MakePoint(-70.6506, -33.4489), 4326)), -- USACH
('mzapata',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 'Av. Providencia 1550, Providencia',
 ST_SetSRID(ST_MakePoint(-70.6180, -33.4287), 4326)),
('cfuentes',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 'Av. Pajaritos 2652, Maipu',
 ST_SetSRID(ST_MakePoint(-70.7530, -33.5040), 4326)),
('jperez',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 'Av. Vicuna Mackenna 7110, La Florida',
 ST_SetSRID(ST_MakePoint(-70.5980, -33.5180), 4326)),
('vrojas',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 'Av. Apoquindo 4501, Las Condes',
 ST_SetSRID(ST_MakePoint(-70.5760, -33.4170), 4326));

-- ============================================================
-- TAREAS
-- Mezcla de pendientes y completadas, con fechas alrededor de
-- junio-agosto 2026 para probar filtros y notificaciones.
-- ============================================================
INSERT INTO tarea (titulo, descripcion, fecha_vencimiento, completada, fecha_completada, id_usuario, id_sector) VALUES
-- Usuario 1: admin (USACH, Estacion Central)
('Inspeccionar obra Alameda',        'Revisar avance de la construccion en Alameda con Ecuador',        '2026-06-15', TRUE,  '2026-06-14 16:30:00', 1, 1),
('Reponer semaforo Bandera',         'Semaforo apagado en Bandera con Compania',                        '2026-06-20', TRUE,  '2026-06-19 11:00:00', 1, 2),
('Bachear calzada Matucana',         'Bache profundo frente al Planetario',                             '2026-07-09', FALSE, NULL,                  1, 1),
('Podar arboles Parque Forestal',    'Ramas caidas tras el temporal',                                    '2026-07-12', FALSE, NULL,                  1, 4),
('Cambiar luminarias Ecuador',       'Tres postes sin luz en calle Ecuador',                             '2026-07-25', FALSE, NULL,                  1, 5),
('Revisar ciclovia Macul',           'Demarcacion borrada en tramo sur',                                 '2026-08-02', FALSE, NULL,                  1, 8),
('Retirar escombros Estacion',       'Escombros de obra abandonados en la vereda',                       '2026-06-28', TRUE,  '2026-06-27 09:45:00', 1, 1),
('Sincronizar semaforos Alameda',    'Ola verde desincronizada entre Las Rejas y Ecuador',               '2026-06-25', TRUE,  '2026-06-24 18:20:00', 1, 2),

-- Usuario 2: mzapata (Providencia)
('Reparar vereda Providencia',       'Vereda levantada por raices frente al 1550',                       '2026-06-18', TRUE,  '2026-06-17 14:00:00', 2, 3),
('Instalar senaletica Los Leones',   'Falta senal de ceda el paso',                                      '2026-07-08', FALSE, NULL,                  2, 7),
('Mantener plaza Las Lilas',         'Riego automatico fallando',                                        '2026-07-15', FALSE, NULL,                  2, 4),
('Repintar paso peatonal Suecia',    'Paso de cebra desgastado',                                         '2026-06-22', TRUE,  '2026-06-21 10:30:00', 2, 3),
('Reparar semaforo Pedro de Valdivia','Luz roja intermitente',                                           '2026-07-10', FALSE, NULL,                  2, 2),
('Limpiar punto verde Providencia',  'Contenedores de reciclaje rebalsados',                             '2026-06-30', TRUE,  '2026-06-29 08:15:00', 2, 6),

-- Usuario 3: cfuentes (Maipu)
('Retirar microbasural Pajaritos',   'Acumulacion de basura en sitio eriazo',                            '2026-06-19', TRUE,  '2026-06-18 13:40:00', 3, 6),
('Bachear Av. 5 de Abril',           'Multiples baches tras lluvias',                                    '2026-07-11', FALSE, NULL,                  3, 3),
('Iluminar plaza de Maipu',          'Sector oscuro reportado por vecinos',                              '2026-07-20', FALSE, NULL,                  3, 5),
('Fiscalizar obra Camino Rinconada', 'Obra sin cierre perimetral',                                       '2026-06-26', TRUE,  '2026-06-25 17:10:00', 3, 1),
('Reparar contenedores Maipu',       'Cuatro contenedores con tapas rotas',                              '2026-07-05', TRUE,  '2026-07-04 12:00:00', 3, 6),

-- Usuario 4: jperez (La Florida)
('Extender ciclovia Vicuna Mackenna','Conectar tramo con estacion Bellavista',                           '2026-08-10', FALSE, NULL,                  4, 8),
('Reponer senaletica Walker Martinez','Senales de transito rayadas',                                     '2026-07-09', FALSE, NULL,                  4, 7),
('Podar platanos orientales',        'Alergia estacional: poda solicitada por vecinos',                  '2026-06-24', TRUE,  '2026-06-23 15:50:00', 4, 4),
('Reparar semaforo Rojas Magallanes','No cambia a verde para peatones',                                  '2026-06-29', TRUE,  '2026-06-28 09:00:00', 4, 2),
('Limpiar canal San Carlos',         'Basura acumulada en rejilla',                                      '2026-07-18', FALSE, NULL,                  4, 6),

-- Usuario 5: vrojas (Las Condes)
('Auditar obra Apoquindo',           'Verificar permisos de edificacion',                                '2026-06-17', TRUE,  '2026-06-16 11:20:00', 5, 1),
('Instalar semaforo El Golf',        'Cruce peligroso reportado',                                        '2026-07-30', FALSE, NULL,                  5, 2),
('Renovar senaletica Kennedy',       'Senales desactualizadas por nueva pista solo bus',                 '2026-07-08', FALSE, NULL,                  5, 7),
('Mantener areas verdes Araucano',   'Cesped seco en sector norte del parque',                           '2026-06-21', TRUE,  '2026-06-20 16:00:00', 5, 4),
('Demarcar ciclovia Isidora',        'Pintura reflectante en curvas',                                    '2026-07-14', FALSE, NULL,                  5, 8),
('Reparar luminaria El Bosque',      'Poste chocado, cableado expuesto',                                 '2026-06-27', TRUE,  '2026-06-26 19:30:00', 5, 5);
```

## 1.4 `runStatements.sql` — archivo completo (las 8 preguntas + extras)

Antes de tipearlo, fija los tres arquetipos que lo explican todo:
**A) agregación** (P1, P6): JOIN + GROUP BY + COUNT. **B) distancias en
metros** (P2, P3, P4, P7, P8): cast `::geography` para que ST_Distance y
ST_DWithin trabajen en metros; el operador KNN `<->` ordena por cercanía
usando el índice GIST; ST_DWithin y no `ST_Distance < r` porque DWithin
descarta por caja envolvente con el índice. **C) agrupación espacial** (P5):
ST_ClusterKMeans como función de ventana: directa de implementar y de defender.

```sql
-- ============================================================
-- CONTROL 2 - TALLER DE BASE DE DATOS 1-2026
-- Consultas espaciales PostGIS (runStatements.sql)
-- Responden las 8 preguntas del enunciado.
--
-- NOTA: Las preguntas sobre "el usuario" usan id_usuario = 1
-- (admin) como ejemplo. En la API el id viene de la sesion.
-- NOTA: El cast ::geography hace que ST_Distance / ST_DWithin
-- trabajen en METROS sobre el elipsoide (con geometry 4326
-- serian grados, lo cual no sirve para radios en km).
-- ============================================================

-- ============================================================
-- PREGUNTA 1: ¿Cuantas tareas ha hecho el usuario por sector?
-- (tareas completadas del usuario 1, agrupadas por sector)
-- ============================================================
SELECT s.nombre AS sector,
       COUNT(t.id_tarea) AS tareas_completadas
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
WHERE t.id_usuario = 1
  AND t.completada = TRUE
GROUP BY s.nombre
ORDER BY tareas_completadas DESC;

-- ============================================================
-- PREGUNTA 2: ¿Cual es la tarea mas cercana al usuario
-- (que este pendiente)?
-- Usa el operador KNN <-> para ordenar por cercania y
-- ST_Distance(::geography) para reportar la distancia en metros.
-- ============================================================
SELECT t.id_tarea,
       t.titulo,
       s.nombre AS sector,
       ROUND(ST_Distance(u.ubicacion::geography,
                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
JOIN usuario u ON u.id_usuario = 1
WHERE t.id_usuario = 1
  AND t.completada = FALSE
ORDER BY u.ubicacion <-> s.ubicacion
LIMIT 1;

-- ============================================================
-- PREGUNTA 3: ¿Cual es el sector con mas tareas completadas
-- en un radio de 2 kilometros del usuario?
-- ST_DWithin(::geography, 2000) filtra por radio en metros.
-- ============================================================
SELECT s.nombre AS sector,
       COUNT(t.id_tarea) AS tareas_completadas,
       ROUND(ST_Distance(u.ubicacion::geography,
                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
JOIN usuario u ON u.id_usuario = 1
WHERE t.completada = TRUE
  AND ST_DWithin(u.ubicacion::geography, s.ubicacion::geography, 2000)
GROUP BY s.nombre, u.ubicacion, s.ubicacion
ORDER BY tareas_completadas DESC
LIMIT 1;

-- ============================================================
-- PREGUNTA 4: ¿Cual es el promedio de distancia de las tareas
-- completadas respecto a la ubicacion del usuario?
-- (tareas completadas del usuario 1)
-- ============================================================
SELECT ROUND(AVG(ST_Distance(u.ubicacion::geography,
                             s.ubicacion::geography))::numeric, 1)
       AS promedio_distancia_metros
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
JOIN usuario u ON u.id_usuario = 1
WHERE t.id_usuario = 1
  AND t.completada = TRUE;

-- ============================================================
-- PREGUNTA 5: ¿En que sectores geograficos se concentran la
-- mayoria de las tareas pendientes? (agrupacion espacial)
-- ST_ClusterKMeans agrupa espacialmente los puntos de las
-- tareas pendientes en 3 clusters; se reporta cada cluster con
-- su centro, cantidad de tareas y los sectores que lo componen.
-- ============================================================
WITH pendientes AS (
    SELECT t.id_tarea,
           s.nombre,
           s.ubicacion,
           ST_ClusterKMeans(s.ubicacion, 3) OVER () AS cluster_id
    FROM tarea t
    JOIN sector s ON s.id_sector = t.id_sector
    WHERE t.completada = FALSE
)
SELECT cluster_id,
       COUNT(*) AS tareas_pendientes,
       STRING_AGG(DISTINCT nombre, ', ') AS sectores,
       ST_AsText(ST_Centroid(ST_Collect(ubicacion))) AS centro_cluster
FROM pendientes
GROUP BY cluster_id
ORDER BY tareas_pendientes DESC;

-- ============================================================
-- PREGUNTA 6: ¿Cuantas tareas ha realizado cada usuario
-- por sector? (todos los usuarios)
-- ============================================================
SELECT u.nombre_usuario,
       s.nombre AS sector,
       COUNT(t.id_tarea) AS tareas_completadas
FROM tarea t
JOIN usuario u ON u.id_usuario = t.id_usuario
JOIN sector s ON s.id_sector = t.id_sector
WHERE t.completada = TRUE
GROUP BY u.nombre_usuario, s.nombre
ORDER BY u.nombre_usuario, tareas_completadas DESC;

-- ============================================================
-- PREGUNTA 7: ¿Cual es el sector con mas tareas completadas
-- dentro de un radio de 5 km desde la ubicacion del usuario?
-- ============================================================
SELECT s.nombre AS sector,
       COUNT(t.id_tarea) AS tareas_completadas,
       ROUND(ST_Distance(u.ubicacion::geography,
                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
JOIN usuario u ON u.id_usuario = 1
WHERE t.completada = TRUE
  AND ST_DWithin(u.ubicacion::geography, s.ubicacion::geography, 5000)
GROUP BY s.nombre, u.ubicacion, s.ubicacion
ORDER BY tareas_completadas DESC
LIMIT 1;

-- ============================================================
-- PREGUNTA 8: ¿Cual es el promedio de distancia entre las
-- tareas completadas y el punto registrado del usuario?
-- (version para todos los usuarios, cada uno con sus tareas)
-- ============================================================
SELECT u.nombre_usuario,
       ROUND(AVG(ST_Distance(u.ubicacion::geography,
                             s.ubicacion::geography))::numeric, 1)
       AS promedio_distancia_metros
FROM tarea t
JOIN usuario u ON u.id_usuario = t.id_usuario
JOIN sector s ON s.id_sector = t.id_sector
WHERE t.completada = TRUE
GROUP BY u.nombre_usuario
ORDER BY u.nombre_usuario;

-- ============================================================
-- EXTRA (util para la app): tarea pendiente mas cercana usando
-- ST_ClosestPoint, funcion mencionada en el enunciado.
-- Devuelve el punto del sector mas cercano al usuario 1
-- entre los sectores con tareas pendientes.
-- ============================================================
SELECT s.nombre AS sector,
       ST_AsText(ST_ClosestPoint(s.ubicacion, u.ubicacion)) AS punto_mas_cercano,
       ROUND(ST_Distance(u.ubicacion::geography,
                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
FROM sector s
JOIN usuario u ON u.id_usuario = 1
WHERE EXISTS (SELECT 1 FROM tarea t
              WHERE t.id_sector = s.id_sector AND t.completada = FALSE)
ORDER BY u.ubicacion <-> s.ubicacion
LIMIT 1;
```

**Ejecución de los tres archivos** (desde la carpeta donde están):

```bash
docker exec -i mi-control2-db-1 psql -U postgres -d tareas_db < dbCreate.sql
docker exec -i mi-control2-db-1 psql -U postgres -d tareas_db < loadData.sql
docker exec -i mi-control2-db-1 psql -U postgres -d tareas_db < runStatements.sql
```

**Rómpelo a propósito:** quita los `::geography` de la pregunta 2 → la
distancia sale ~0.003 (grados). Esa es LA pregunta de defensa.

**Checkpoint Fase 1:** las 8 consultas (y las 2 extra) corren y entiendes cada
cláusula. Verifica una distancia contra Google Maps (medir distancia).

---
# FASE 2 — Backend Spring Boot (desde IntelliJ)

## 2.1 Crear el proyecto

**IntelliJ Ultimate:** File → New → Project → Spring Boot. Name `backend`,
Language Java, Type Maven, Group `usach.cl`, Artifact `tareas-backend`,
Package name `usach.cl.tareasbackend`, JDK 17, Spring Boot 3.3.x.
Dependencias: Spring Web, JDBC API, Spring Security, Validation, PostgreSQL
Driver. **NO marques Spring Data JPA** (ORM prohibido por el curso).

**IntelliJ Community:** genera lo mismo en https://start.spring.io, descarga,
descomprime como `backend/` y ábrelo con File → Open.

Después de crearlo, **reemplaza el `pom.xml` completo por este** (fija Boot
3.3.5, alinea las tres jjwt y no trae overrides del compilador) y recarga
Maven (ícono flotante o panel Maven → Reload). Verifica en File → Project
Structure que SDK y Language level sean **17**.

**Archivo: `backend/pom.xml`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
	xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
	<modelVersion>4.0.0</modelVersion>
	<parent>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-parent</artifactId>
		<version>3.3.5</version>
		<relativePath/>
	</parent>
	<groupId>usach.cl</groupId>
	<artifactId>tareas-backend</artifactId>
	<version>0.0.1-SNAPSHOT</version>
	<name>backend</name>
	<description>Control 2 TBD - API de gestion de tareas con PostGIS</description>

	<properties>
		<java.version>17</java.version>
	</properties>

	<dependencies>
		<!-- API REST (en Boot 3 se llama starter-web, no starter-webmvc) -->
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-web</artifactId>
		</dependency>
		<!-- Acceso a datos con SQL explicito (sin ORM) -->
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-jdbc</artifactId>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-security</artifactId>
		</dependency>
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-validation</artifactId>
		</dependency>
		<dependency>
			<groupId>org.postgresql</groupId>
			<artifactId>postgresql</artifactId>
			<scope>runtime</scope>
		</dependency>
		<!-- JWT: las TRES con la MISMA version -->
		<dependency>
			<groupId>io.jsonwebtoken</groupId>
			<artifactId>jjwt-api</artifactId>
			<version>0.11.5</version>
		</dependency>
		<dependency>
			<groupId>io.jsonwebtoken</groupId>
			<artifactId>jjwt-impl</artifactId>
			<version>0.11.5</version>
			<scope>runtime</scope>
		</dependency>
		<dependency>
			<groupId>io.jsonwebtoken</groupId>
			<artifactId>jjwt-jackson</artifactId>
			<version>0.11.5</version>
			<scope>runtime</scope>
		</dependency>
		<!-- Tests: en Boot 3 existe UN solo starter de test -->
		<dependency>
			<groupId>org.springframework.boot</groupId>
			<artifactId>spring-boot-starter-test</artifactId>
			<scope>test</scope>
		</dependency>
	</dependencies>

	<build>
		<plugins>
			<plugin>
				<groupId>org.springframework.boot</groupId>
				<artifactId>spring-boot-maven-plugin</artifactId>
			</plugin>
			<!-- SIN maven-compiler-plugin: el parent lo configura desde java.version -->
		</plugins>
	</build>
</project>
```

**Archivo: `backend/src/main/resources/application.properties`**

```properties
spring.application.name=backend
server.port=${SERVER_PORT:8080}
spring.datasource.url=${DB_URL:jdbc:postgresql://localhost:5435/tareas_db}
spring.datasource.username=${DB_USER:postgres}
spring.datasource.password=${DB_PASSWORD:postgres}
jwt.secret=${JWT_SECRET:una-clave-larga-de-al-menos-32-caracteres-para-hs256}
jwt.expiration-ms=${JWT_EXPIRATION_MS:86400000}
app.cors.allowed-origin=${CORS_ORIGIN:http://localhost:5173}
```
**Checkpoint 2.1:** flecha verde sobre `BackendApplication` (con la BD de
Docker arriba) → banner de Spring y "Started BackendApplication". Todo
endpoint responde 401: correcto, es la seguridad por defecto.

## 2.2 Seguridad (4 archivos)

Crea los paquetes con clic derecho sobre `usach.cl.tareasbackend` → New →
Package: `security`, `config`, `dto`, `repository`, `service`, `controller`.
Luego, en cada paquete, New → **Java Class** (nunca aceptes sugerencias de
"implicitly declared class" ni de habilitar preview features).

`JwtUtil`: fabrica y valida los tokens (HS256, clave simétrica del servidor).

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/security/JwtUtil.java`**

```java
package usach.cl.tareasbackend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Date;

@Component
public class JwtUtil {
    private final Key key;
    private final long expirationMs;

    public JwtUtil(@Value("${jwt.secret}") String secret,
                   @Value("${jwt.expiration-ms}") long expirationMs) {
        // La clave HS256 se deriva del secreto de configuracion (simetrica:
        // la misma clave firma y verifica; solo el servidor la conoce)
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.expirationMs = expirationMs;
    }

    public String generarToken(int idUsuario, String nombreUsuario) {
        Date ahora = new Date();
        return Jwts.builder()
                .setSubject(nombreUsuario)      // claim estandar "sub"
                .claim("id", idUsuario)         // claim propio: id para autorizar
                .setIssuedAt(ahora)
                .setExpiration(new Date(ahora.getTime() + expirationMs))
                .signWith(key, SignatureAlgorithm.HS256)
                .compact();                     // header.payload.firma en Base64
    }

    public Claims validarToken(String token) throws JwtException {
        // parseClaimsJws VERIFICA la firma y la expiracion; si algo falla
        // lanza JwtException (por eso el filtro lo envuelve en try/catch)
        return Jwts.parserBuilder().setSigningKey(key).build()
                .parseClaimsJws(token).getBody();
    }
}
```

`UsuarioAutenticado`: el "quién es" que viaja por la aplicación tras validar el token.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/security/UsuarioAutenticado.java`**

```java
package usach.cl.tareasbackend.security;

public record UsuarioAutenticado(int id, String nombreUsuario) {}
```

`JwtAuthFilter`: el middleware; corre en CADA petición, valida el token y puebla el contexto de seguridad.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/security/JwtAuthFilter.java`**

```java
package usach.cl.tareasbackend.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {
    private final JwtUtil jwtUtil;
    public JwtAuthFilter(JwtUtil jwtUtil) { this.jwtUtil = jwtUtil; }

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            try {
                Claims claims = jwtUtil.validarToken(header.substring(7));
                var principal = new UsuarioAutenticado(
                        claims.get("id", Integer.class), claims.getSubject());
                // Registrar al usuario en el contexto: desde aqui en adelante
                // los controllers pueden pedirlo con @AuthenticationPrincipal
                SecurityContextHolder.getContext().setAuthentication(
                        new UsernamePasswordAuthenticationToken(principal, null, List.of()));
            } catch (JwtException e) {
                SecurityContextHolder.clearContext(); // token malo => anonimo => 401
            }
        }
        filterChain.doFilter(request, response); // SIEMPRE continuar la cadena
    }
}
```

`SecurityConfig`: las reglas — `/api/auth/**` público, resto con token; STATELESS; CSRF deshabilitado con justificación; CORS para el frontend de desarrollo; bean BCrypt.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/config/SecurityConfig.java`**

```java
package usach.cl.tareasbackend.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import usach.cl.tareasbackend.security.JwtAuthFilter;

import java.util.List;

@Configuration          // le dice a Spring: esta clase declara beans
@EnableWebSecurity      // activa la configuracion de seguridad web
public class SecurityConfig {

    private final JwtAuthFilter jwtAuthFilter;   // el middleware, inyectado

    @Value("${app.cors.allowed-origin}")
    private String allowedOrigin;

    public SecurityConfig(JwtAuthFilter jwtAuthFilter) {
        this.jwtAuthFilter = jwtAuthFilter;
    }

    /**
     * CSRF deshabilitado CON justificacion: API stateless, token en el header
     * Authorization que el navegador NO adjunta solo (a diferencia de las
     * cookies) => el vector CSRF no existe en este diseno.
     */
    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .cors(Customizer.withDefaults())
            .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .exceptionHandling(e -> e.authenticationEntryPoint(
                    new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
            .authorizeHttpRequests(auth -> auth
                    .requestMatchers("/api/auth/**").permitAll()
                    .anyRequest().authenticated())
            .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }

    /** Origen permitido para el frontend de desarrollo (Vite, puerto 5173). */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of(allowedOrigin));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }
}
```
## 2.3 Registro y login

Orden de dependencia: DTOs → repositorio → service → controller → manejador de
errores.

`AuthDtos`: records de entrada/salida con validación declarativa.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/dto/AuthDtos.java`**

```java
package usach.cl.tareasbackend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * DTOs de autenticacion (registro y login).
 */
public class AuthDtos {

    public record RegistroRequest(
            @NotBlank String nombreUsuario,
            @NotBlank String contrasena,
            @NotBlank String direccion,
            @NotNull Double latitud,
            @NotNull Double longitud) {
    }

    public record LoginRequest(
            @NotBlank String nombreUsuario,
            @NotBlank String contrasena) {
    }

    public record LoginResponse(String token, int id, String nombreUsuario) {
    }
}
```

`UsuarioRepository`: SQL explícito parametrizado (prepared statements = sin inyección); el punto PostGIS entra con `ST_MakePoint` y sale con `ST_X`/`ST_Y`.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/repository/UsuarioRepository.java`**

```java
package usach.cl.tareasbackend.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.Map;
import java.util.Optional;

/**
 * Acceso a datos de usuarios con SQL explicito (sin ORM).
 * Todas las consultas usan parametros nombrados, que se traducen a
 * prepared statements: proteccion contra inyeccion SQL.
 */
@Repository
public class UsuarioRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public UsuarioRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Registra un usuario guardando su ubicacion como punto PostGIS. */
    public int insertar(String nombreUsuario, String hashContrasena,
                        String direccion, double latitud, double longitud) {
        String sql = """
                INSERT INTO usuario (nombre_usuario, contrasena, direccion, ubicacion)
                VALUES (:nombre, :contrasena, :direccion,
                        ST_SetSRID(ST_MakePoint(:longitud, :latitud), 4326))
                RETURNING id_usuario
                """;
        var params = new MapSqlParameterSource()
                .addValue("nombre", nombreUsuario)
                .addValue("contrasena", hashContrasena)
                .addValue("direccion", direccion)
                .addValue("latitud", latitud)
                .addValue("longitud", longitud);
        return jdbc.queryForObject(sql, params, Integer.class);
    }

    /** Busca un usuario por nombre; retorna id y hash de contrasena. */
    public Optional<Map<String, Object>> buscarPorNombre(String nombreUsuario) {
        String sql = """
                SELECT id_usuario, nombre_usuario, contrasena
                FROM usuario
                WHERE nombre_usuario = :nombre
                """;
        var params = new MapSqlParameterSource("nombre", nombreUsuario);
        return jdbc.queryForList(sql, params).stream().findFirst();
    }

    /** Perfil del usuario con sus coordenadas extraidas del punto PostGIS. */
    public Optional<Map<String, Object>> datosPerfil(int idUsuario) {
        String sql = """
                SELECT id_usuario, nombre_usuario, direccion,
                       ST_Y(ubicacion) AS latitud,
                       ST_X(ubicacion) AS longitud
                FROM usuario
                WHERE id_usuario = :id
                """;
        var params = new MapSqlParameterSource("id", idUsuario);
        return jdbc.queryForList(sql, params).stream().findFirst();
    }

    public boolean existeNombre(String nombreUsuario) {
        String sql = "SELECT COUNT(*) FROM usuario WHERE nombre_usuario = :nombre";
        Integer n = jdbc.queryForObject(sql,
                new MapSqlParameterSource("nombre", nombreUsuario), Integer.class);
        return n != null && n > 0;
    }
}
```

`AuthService`: nombre único, hash BCrypt al registrar, `matches()` al validar, mismo mensaje si falla usuario o clave.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/service/AuthService.java`**

```java
package usach.cl.tareasbackend.service;

import usach.cl.tareasbackend.dto.AuthDtos.LoginRequest;
import usach.cl.tareasbackend.dto.AuthDtos.LoginResponse;
import usach.cl.tareasbackend.dto.AuthDtos.RegistroRequest;
import usach.cl.tareasbackend.repository.UsuarioRepository;
import usach.cl.tareasbackend.security.JwtUtil;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class AuthService {

    private final UsuarioRepository usuarioRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    public AuthService(UsuarioRepository usuarioRepository,
                       PasswordEncoder passwordEncoder,
                       JwtUtil jwtUtil) {
        this.usuarioRepository = usuarioRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
    }

    /** Registra al usuario hasheando su contrasena con BCrypt. */
    public int registrar(RegistroRequest req) {
        if (usuarioRepository.existeNombre(req.nombreUsuario())) {
            throw new IllegalArgumentException("El nombre de usuario ya existe");
        }
        if (req.latitud() < -90 || req.latitud() > 90
                || req.longitud() < -180 || req.longitud() > 180) {
            throw new IllegalArgumentException("Coordenadas fuera de rango");
        }
        String hash = passwordEncoder.encode(req.contrasena());
        return usuarioRepository.insertar(req.nombreUsuario(), hash,
                req.direccion(), req.latitud(), req.longitud());
    }

    /** Valida credenciales y genera el JWT. */
    public LoginResponse login(LoginRequest req) {
        Map<String, Object> usuario = usuarioRepository
                .buscarPorNombre(req.nombreUsuario())
                .orElseThrow(() -> new BadCredentialsException("Credenciales invalidas"));

        String hash = (String) usuario.get("contrasena");
        if (!passwordEncoder.matches(req.contrasena(), hash)) {
            throw new BadCredentialsException("Credenciales invalidas");
        }
        int id = (Integer) usuario.get("id_usuario");
        String nombre = (String) usuario.get("nombre_usuario");
        return new LoginResponse(jwtUtil.generarToken(id, nombre), id, nombre);
    }
}
```

`AuthController`: mapea las dos rutas públicas.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/controller/AuthController.java`**

```java
package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.dto.AuthDtos.LoginRequest;
import usach.cl.tareasbackend.dto.AuthDtos.LoginResponse;
import usach.cl.tareasbackend.dto.AuthDtos.RegistroRequest;
import usach.cl.tareasbackend.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    public ResponseEntity<Map<String, Object>> registrar(@Valid @RequestBody RegistroRequest req) {
        int id = authService.registrar(req);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(Map.of("id", id, "nombreUsuario", req.nombreUsuario(),
                             "mensaje", "Usuario registrado. Ahora puede iniciar sesion."));
    }

    @PostMapping("/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }
}
```

`GlobalExceptionHandler`: traduce excepciones a códigos HTTP con JSON uniforme `{"error": ...}`.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/controller/GlobalExceptionHandler.java`**

```java
package usach.cl.tareasbackend.controller;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;
import java.util.NoSuchElementException;

/**
 * Traduce excepciones a respuestas HTTP con un JSON uniforme {"error": ...}.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, String>> badRequest(IllegalArgumentException e) {
        return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, String>> validacion(MethodArgumentNotValidException e) {
        String detalle = e.getBindingResult().getFieldErrors().stream()
                .map(f -> f.getField() + " " + f.getDefaultMessage())
                .findFirst().orElse("Datos invalidos");
        return ResponseEntity.badRequest().body(Map.of("error", detalle));
    }

    @ExceptionHandler(NoSuchElementException.class)
    public ResponseEntity<Map<String, String>> notFound(NoSuchElementException e) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", e.getMessage()));
    }

    @ExceptionHandler(BadCredentialsException.class)
    public ResponseEntity<Map<String, String>> unauthorized(BadCredentialsException e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", e.getMessage()));
    }
}
```
**Checkpoint 2.3 (terminal, o espera al `pruebas.http` del final de la fase):**

```bash
curl -X POST localhost:8080/api/auth/register -H "Content-Type: application/json" \
  -d '{"nombreUsuario":"yo","contrasena":"1234","direccion":"Casa","latitud":-33.45,"longitud":-70.66}'
curl -X POST localhost:8080/api/auth/login -H "Content-Type: application/json" \
  -d '{"nombreUsuario":"yo","contrasena":"1234"}'
curl -i localhost:8080/api/tareas            # sin token -> 401
```

En pgAdmin/psql: `SELECT nombre_usuario, contrasena, ST_AsText(ubicacion) FROM usuario;`
→ hash `$2a$...` y `POINT(-70.66 -33.45)`.

## 2.4 Dominio completo: sectores, tareas, notificaciones, estadísticas

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/dto/SectorDto.java`**

```java
package usach.cl.tareasbackend.dto;

/**
 * Sector de trabajo con su punto georreferenciado.
 */
public record SectorDto(int idSector, String nombre, double latitud, double longitud) {
}
```

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/dto/TareaDtos.java`**

```java
package usach.cl.tareasbackend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * DTOs de tareas.
 */
public class TareaDtos {

    /** Cuerpo para crear o editar una tarea. */
    public record TareaRequest(
            @NotBlank String titulo,
            String descripcion,
            @NotNull LocalDate fechaVencimiento,
            @NotNull Integer idSector) {
    }

    /** Respuesta con la tarea y los datos de su sector georreferenciado. */
    public record TareaResponse(
            int idTarea,
            String titulo,
            String descripcion,
            LocalDate fechaVencimiento,
            boolean completada,
            LocalDateTime fechaCompletada,
            int idSector,
            String nombreSector,
            double latitudSector,
            double longitudSector) {
    }
}
```

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/dto/NotificacionDto.java`**

```java
package usach.cl.tareasbackend.dto;

import java.time.LocalDateTime;

/**
 * Notificacion de vencimiento de tarea.
 */
public record NotificacionDto(int idNotificacion, String mensaje,
                              LocalDateTime fechaCreacion, boolean leida,
                              int idTarea) {
}
```

`SectorRepository`: lista los sectores con coordenadas extraídas del punto.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/repository/SectorRepository.java`**

```java
package usach.cl.tareasbackend.repository;

import usach.cl.tareasbackend.dto.SectorDto;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Acceso a datos de sectores (SQL explicito, sin ORM).
 */
@Repository
public class SectorRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public SectorRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** Lista los sectores con sus coordenadas extraidas del punto PostGIS. */
    public List<SectorDto> listar() {
        String sql = """
                SELECT id_sector,
                       nombre,
                       ST_Y(ubicacion) AS latitud,
                       ST_X(ubicacion) AS longitud
                FROM sector
                ORDER BY nombre
                """;
        return jdbc.query(sql, (rs, i) -> new SectorDto(
                rs.getInt("id_sector"),
                rs.getString("nombre"),
                rs.getDouble("latitud"),
                rs.getDouble("longitud")));
    }
}
```

`TareaRepository`: el corazón del CRUD. TODAS las consultas llevan `id_usuario = :idUsuario` (autorización a nivel de datos) y la búsqueda ILIKE va parametrizada.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/repository/TareaRepository.java`**

```java
package usach.cl.tareasbackend.repository;

import usach.cl.tareasbackend.dto.TareaDtos.TareaResponse;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Timestamp;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/**
 * Acceso a datos de tareas con SQL explicito (sin ORM).
 * Todas las operaciones filtran por id_usuario: un usuario solo puede
 * ver y modificar SUS tareas (autorizacion a nivel de datos).
 */
@Repository
public class TareaRepository {

    private final NamedParameterJdbcTemplate jdbc;

    private static final String SELECT_BASE = """
            SELECT t.id_tarea, t.titulo, t.descripcion, t.fecha_vencimiento,
                   t.completada, t.fecha_completada,
                   s.id_sector, s.nombre AS nombre_sector,
                   ST_Y(s.ubicacion) AS latitud_sector,
                   ST_X(s.ubicacion) AS longitud_sector
            FROM tarea t
            JOIN sector s ON s.id_sector = t.id_sector
            """;

    private static final RowMapper<TareaResponse> MAPPER = (rs, i) -> {
        Timestamp fc = rs.getTimestamp("fecha_completada");
        return new TareaResponse(
                rs.getInt("id_tarea"),
                rs.getString("titulo"),
                rs.getString("descripcion"),
                rs.getDate("fecha_vencimiento").toLocalDate(),
                rs.getBoolean("completada"),
                fc != null ? fc.toLocalDateTime() : null,
                rs.getInt("id_sector"),
                rs.getString("nombre_sector"),
                rs.getDouble("latitud_sector"),
                rs.getDouble("longitud_sector"));
    };

    public TareaRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * Lista las tareas del usuario con filtros opcionales:
     * - estado: "pendiente" | "completada" | null (todas)
     * - buscar: palabra clave en titulo o descripcion (ILIKE parametrizado)
     */
    public List<TareaResponse> listar(int idUsuario, String estado, String buscar) {
        StringBuilder sql = new StringBuilder(SELECT_BASE)
                .append(" WHERE t.id_usuario = :idUsuario ");
        var params = new MapSqlParameterSource("idUsuario", idUsuario);

        if ("pendiente".equalsIgnoreCase(estado)) {
            sql.append(" AND t.completada = FALSE ");
        } else if ("completada".equalsIgnoreCase(estado)) {
            sql.append(" AND t.completada = TRUE ");
        }
        if (buscar != null && !buscar.isBlank()) {
            sql.append(" AND (t.titulo ILIKE :patron OR t.descripcion ILIKE :patron) ");
            params.addValue("patron", "%" + buscar.trim() + "%");
        }
        sql.append(" ORDER BY t.completada ASC, t.fecha_vencimiento ASC ");
        return jdbc.query(sql.toString(), params, MAPPER);
    }

    public Optional<TareaResponse> buscarPorIdYUsuario(int idTarea, int idUsuario) {
        String sql = SELECT_BASE + " WHERE t.id_tarea = :idTarea AND t.id_usuario = :idUsuario";
        var params = new MapSqlParameterSource()
                .addValue("idTarea", idTarea)
                .addValue("idUsuario", idUsuario);
        return jdbc.query(sql, params, MAPPER).stream().findFirst();
    }

    public int insertar(int idUsuario, String titulo, String descripcion,
                        LocalDate fechaVencimiento, int idSector) {
        String sql = """
                INSERT INTO tarea (titulo, descripcion, fecha_vencimiento, id_usuario, id_sector)
                VALUES (:titulo, :descripcion, :fecha, :idUsuario, :idSector)
                RETURNING id_tarea
                """;
        var params = new MapSqlParameterSource()
                .addValue("titulo", titulo)
                .addValue("descripcion", descripcion)
                .addValue("fecha", fechaVencimiento)
                .addValue("idUsuario", idUsuario)
                .addValue("idSector", idSector);
        return jdbc.queryForObject(sql, params, Integer.class);
    }

    /** Edita titulo, descripcion, vencimiento y sector. Retorna filas afectadas. */
    public int actualizar(int idTarea, int idUsuario, String titulo, String descripcion,
                          LocalDate fechaVencimiento, int idSector) {
        String sql = """
                UPDATE tarea
                SET titulo = :titulo,
                    descripcion = :descripcion,
                    fecha_vencimiento = :fecha,
                    id_sector = :idSector
                WHERE id_tarea = :idTarea AND id_usuario = :idUsuario
                """;
        var params = new MapSqlParameterSource()
                .addValue("titulo", titulo)
                .addValue("descripcion", descripcion)
                .addValue("fecha", fechaVencimiento)
                .addValue("idSector", idSector)
                .addValue("idTarea", idTarea)
                .addValue("idUsuario", idUsuario);
        return jdbc.update(sql, params);
    }

    public int eliminar(int idTarea, int idUsuario) {
        String sql = "DELETE FROM tarea WHERE id_tarea = :idTarea AND id_usuario = :idUsuario";
        var params = new MapSqlParameterSource()
                .addValue("idTarea", idTarea)
                .addValue("idUsuario", idUsuario);
        return jdbc.update(sql, params);
    }

    public int marcarCompletada(int idTarea, int idUsuario) {
        String sql = """
                UPDATE tarea
                SET completada = TRUE, fecha_completada = NOW()
                WHERE id_tarea = :idTarea AND id_usuario = :idUsuario AND completada = FALSE
                """;
        var params = new MapSqlParameterSource()
                .addValue("idTarea", idTarea)
                .addValue("idUsuario", idUsuario);
        return jdbc.update(sql, params);
    }
}
```

`NotificacionRepository`: lista avisos y genera los de tareas por vencer (≤3 días) sin duplicar, complementando al trigger.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/repository/NotificacionRepository.java`**

```java
package usach.cl.tareasbackend.repository;

import usach.cl.tareasbackend.dto.NotificacionDto;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;

/**
 * Acceso a datos de notificaciones. Las notificaciones son generadas por
 * el trigger trg_notificar_vencimiento definido en dbCreate.sql.
 */
@Repository
public class NotificacionRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public NotificacionRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<NotificacionDto> listarPorUsuario(int idUsuario) {
        String sql = """
                SELECT id_notificacion, mensaje, fecha_creacion, leida, id_tarea
                FROM notificacion
                WHERE id_usuario = :idUsuario
                ORDER BY fecha_creacion DESC
                """;
        return jdbc.query(sql, new MapSqlParameterSource("idUsuario", idUsuario),
                (rs, i) -> new NotificacionDto(
                        rs.getInt("id_notificacion"),
                        rs.getString("mensaje"),
                        rs.getTimestamp("fecha_creacion").toLocalDateTime(),
                        rs.getBoolean("leida"),
                        rs.getInt("id_tarea")));
    }

    /**
     * Genera notificaciones para las tareas pendientes del usuario que
     * vencen dentro de :dias dias y que aun no tienen notificacion.
     * Complementa al trigger para tareas cuyo vencimiento "se acerco"
     * con el paso del tiempo.
     */
    public int generarPorVencer(int idUsuario, int dias) {
        String sql = """
                INSERT INTO notificacion (mensaje, id_usuario, id_tarea)
                SELECT 'La tarea "' || t.titulo || '" vence el ' ||
                       TO_CHAR(t.fecha_vencimiento, 'DD-MM-YYYY'),
                       t.id_usuario, t.id_tarea
                FROM tarea t
                WHERE t.id_usuario = :idUsuario
                  AND t.completada = FALSE
                  AND t.fecha_vencimiento <= CURRENT_DATE + :dias
                  AND NOT EXISTS (SELECT 1 FROM notificacion n
                                  WHERE n.id_tarea = t.id_tarea)
                """;
        var params = new MapSqlParameterSource()
                .addValue("idUsuario", idUsuario)
                .addValue("dias", dias);
        return jdbc.update(sql, params);
    }

    public int marcarLeida(int idNotificacion, int idUsuario) {
        String sql = """
                UPDATE notificacion SET leida = TRUE
                WHERE id_notificacion = :id AND id_usuario = :idUsuario
                """;
        var params = new MapSqlParameterSource()
                .addValue("id", idNotificacion)
                .addValue("idUsuario", idUsuario);
        return jdbc.update(sql, params);
    }
}
```

`EstadisticaRepository`: las 8 preguntas — tu SQL de la Fase 1 con `:idUsuario` y `:radio` como parámetros.

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/repository/EstadisticaRepository.java`**

```java
package usach.cl.tareasbackend.repository;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Map;

/**
 * Consultas espaciales PostGIS que responden las 8 preguntas del enunciado.
 * Son las mismas consultas de runStatements.sql, parametrizadas por usuario.
 * El cast ::geography hace que las distancias se calculen en METROS.
 */
@Repository
public class EstadisticaRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public EstadisticaRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    /** P1: tareas completadas del usuario, agrupadas por sector. */
    public List<Map<String, Object>> tareasPorSector(int idUsuario) {
        String sql = """
                SELECT s.nombre AS sector, COUNT(t.id_tarea) AS tareas_completadas
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                WHERE t.id_usuario = :idUsuario AND t.completada = TRUE
                GROUP BY s.nombre
                ORDER BY tareas_completadas DESC
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("idUsuario", idUsuario));
    }

    /** P2: tarea pendiente mas cercana al usuario (operador KNN). */
    public List<Map<String, Object>> tareaMasCercana(int idUsuario) {
        String sql = """
                SELECT t.id_tarea, t.titulo, s.nombre AS sector,
                       ROUND(ST_Distance(u.ubicacion::geography,
                                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                JOIN usuario u ON u.id_usuario = :idUsuario
                WHERE t.id_usuario = :idUsuario AND t.completada = FALSE
                ORDER BY u.ubicacion <-> s.ubicacion
                LIMIT 1
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("idUsuario", idUsuario));
    }

    /** P3 y P7: sector con mas tareas completadas dentro de un radio (metros). */
    public List<Map<String, Object>> sectorConMasCompletadas(int idUsuario, double radioMetros) {
        String sql = """
                SELECT s.nombre AS sector, COUNT(t.id_tarea) AS tareas_completadas,
                       ROUND(ST_Distance(u.ubicacion::geography,
                                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                JOIN usuario u ON u.id_usuario = :idUsuario
                WHERE t.completada = TRUE
                  AND ST_DWithin(u.ubicacion::geography, s.ubicacion::geography, :radio)
                GROUP BY s.nombre, u.ubicacion, s.ubicacion
                ORDER BY tareas_completadas DESC
                LIMIT 1
                """;
        var params = new MapSqlParameterSource()
                .addValue("idUsuario", idUsuario)
                .addValue("radio", radioMetros);
        return jdbc.queryForList(sql, params);
    }

    /** P4: promedio de distancia de las tareas completadas del usuario. */
    public List<Map<String, Object>> promedioDistancia(int idUsuario) {
        String sql = """
                SELECT ROUND(AVG(ST_Distance(u.ubicacion::geography,
                                             s.ubicacion::geography))::numeric, 1)
                       AS promedio_distancia_metros
                FROM tarea t
                JOIN sector s ON s.id_sector = t.id_sector
                JOIN usuario u ON u.id_usuario = :idUsuario
                WHERE t.id_usuario = :idUsuario AND t.completada = TRUE
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("idUsuario", idUsuario));
    }

    /** P5: agrupacion espacial (K-Means) de las tareas pendientes. */
    public List<Map<String, Object>> clustersPendientes(int k) {
        String sql = """
                WITH pendientes AS (
                    SELECT t.id_tarea, s.nombre, s.ubicacion,
                           ST_ClusterKMeans(s.ubicacion, :k) OVER () AS cluster_id
                    FROM tarea t
                    JOIN sector s ON s.id_sector = t.id_sector
                    WHERE t.completada = FALSE
                )
                SELECT cluster_id,
                       COUNT(*) AS tareas_pendientes,
                       STRING_AGG(DISTINCT nombre, ', ') AS sectores,
                       ST_Y(ST_Centroid(ST_Collect(ubicacion))) AS latitud_centro,
                       ST_X(ST_Centroid(ST_Collect(ubicacion))) AS longitud_centro
                FROM pendientes
                GROUP BY cluster_id
                ORDER BY tareas_pendientes DESC
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource("k", k));
    }

    /** P6: tareas completadas de cada usuario por sector. */
    public List<Map<String, Object>> tareasPorUsuarioYSector() {
        String sql = """
                SELECT u.nombre_usuario, s.nombre AS sector,
                       COUNT(t.id_tarea) AS tareas_completadas
                FROM tarea t
                JOIN usuario u ON u.id_usuario = t.id_usuario
                JOIN sector s ON s.id_sector = t.id_sector
                WHERE t.completada = TRUE
                GROUP BY u.nombre_usuario, s.nombre
                ORDER BY u.nombre_usuario, tareas_completadas DESC
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource());
    }

    /** P8: promedio de distancia de tareas completadas, por cada usuario. */
    public List<Map<String, Object>> promedioDistanciaTodos() {
        String sql = """
                SELECT u.nombre_usuario,
                       ROUND(AVG(ST_Distance(u.ubicacion::geography,
                                             s.ubicacion::geography))::numeric, 1)
                       AS promedio_distancia_metros
                FROM tarea t
                JOIN usuario u ON u.id_usuario = t.id_usuario
                JOIN sector s ON s.id_sector = t.id_sector
                WHERE t.completada = TRUE
                GROUP BY u.nombre_usuario
                ORDER BY u.nombre_usuario
                """;
        return jdbc.queryForList(sql, new MapSqlParameterSource());
    }
}
```

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/service/TareaService.java`**

```java
package usach.cl.tareasbackend.service;

import usach.cl.tareasbackend.dto.TareaDtos.TareaRequest;
import usach.cl.tareasbackend.dto.TareaDtos.TareaResponse;
import usach.cl.tareasbackend.repository.TareaRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.NoSuchElementException;

@Service
public class TareaService {

    private final TareaRepository tareaRepository;

    public TareaService(TareaRepository tareaRepository) {
        this.tareaRepository = tareaRepository;
    }

    public List<TareaResponse> listar(int idUsuario, String estado, String buscar) {
        return tareaRepository.listar(idUsuario, estado, buscar);
    }

    public TareaResponse crear(int idUsuario, TareaRequest req) {
        int id = tareaRepository.insertar(idUsuario, req.titulo(),
                req.descripcion(), req.fechaVencimiento(), req.idSector());
        return obtener(id, idUsuario);
    }

    public TareaResponse editar(int idTarea, int idUsuario, TareaRequest req) {
        int filas = tareaRepository.actualizar(idTarea, idUsuario, req.titulo(),
                req.descripcion(), req.fechaVencimiento(), req.idSector());
        if (filas == 0) {
            throw new NoSuchElementException("Tarea no encontrada");
        }
        return obtener(idTarea, idUsuario);
    }

    public void eliminar(int idTarea, int idUsuario) {
        if (tareaRepository.eliminar(idTarea, idUsuario) == 0) {
            throw new NoSuchElementException("Tarea no encontrada");
        }
    }

    public TareaResponse completar(int idTarea, int idUsuario) {
        tareaRepository.marcarCompletada(idTarea, idUsuario);
        return obtener(idTarea, idUsuario);
    }

    private TareaResponse obtener(int idTarea, int idUsuario) {
        return tareaRepository.buscarPorIdYUsuario(idTarea, idUsuario)
                .orElseThrow(() -> new NoSuchElementException("Tarea no encontrada"));
    }
}
```

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/controller/SectorController.java`**

```java
package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.dto.SectorDto;
import usach.cl.tareasbackend.repository.SectorRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/sectores")
public class SectorController {

    private final SectorRepository sectorRepository;

    public SectorController(SectorRepository sectorRepository) {
        this.sectorRepository = sectorRepository;
    }

    @GetMapping
    public List<SectorDto> listar() {
        return sectorRepository.listar();
    }
}
```

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/controller/TareaController.java`**

```java
package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.dto.TareaDtos.TareaRequest;
import usach.cl.tareasbackend.dto.TareaDtos.TareaResponse;
import usach.cl.tareasbackend.security.UsuarioAutenticado;
import usach.cl.tareasbackend.service.TareaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/tareas")
public class TareaController {

    private final TareaService tareaService;

    public TareaController(TareaService tareaService) {
        this.tareaService = tareaService;
    }

    /** Lista con filtros: /api/tareas?estado=pendiente|completada&buscar=palabra */
    @GetMapping
    public List<TareaResponse> listar(@AuthenticationPrincipal UsuarioAutenticado usuario,
                                      @RequestParam(required = false) String estado,
                                      @RequestParam(required = false) String buscar) {
        return tareaService.listar(usuario.id(), estado, buscar);
    }

    @PostMapping
    public ResponseEntity<TareaResponse> crear(@AuthenticationPrincipal UsuarioAutenticado usuario,
                                               @Valid @RequestBody TareaRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(tareaService.crear(usuario.id(), req));
    }

    @PutMapping("/{id}")
    public TareaResponse editar(@AuthenticationPrincipal UsuarioAutenticado usuario,
                                @PathVariable int id,
                                @Valid @RequestBody TareaRequest req) {
        return tareaService.editar(id, usuario.id(), req);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> eliminar(@AuthenticationPrincipal UsuarioAutenticado usuario,
                                         @PathVariable int id) {
        tareaService.eliminar(id, usuario.id());
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{id}/completar")
    public TareaResponse completar(@AuthenticationPrincipal UsuarioAutenticado usuario,
                                   @PathVariable int id) {
        return tareaService.completar(id, usuario.id());
    }
}
```

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/controller/NotificacionController.java`**

```java
package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.dto.NotificacionDto;
import usach.cl.tareasbackend.repository.NotificacionRepository;
import usach.cl.tareasbackend.security.UsuarioAutenticado;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/notificaciones")
public class NotificacionController {

    private final NotificacionRepository notificacionRepository;

    public NotificacionController(NotificacionRepository notificacionRepository) {
        this.notificacionRepository = notificacionRepository;
    }

    /**
     * Antes de listar, genera notificaciones para las tareas del usuario
     * que vencen en los proximos 3 dias (si aun no existen).
     */
    @GetMapping
    public List<NotificacionDto> listar(@AuthenticationPrincipal UsuarioAutenticado usuario) {
        notificacionRepository.generarPorVencer(usuario.id(), 3);
        return notificacionRepository.listarPorUsuario(usuario.id());
    }

    @PatchMapping("/{id}/leer")
    public void marcarLeida(@AuthenticationPrincipal UsuarioAutenticado usuario,
                            @PathVariable int id) {
        notificacionRepository.marcarLeida(id, usuario.id());
    }
}
```

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/controller/EstadisticaController.java`**

```java
package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.repository.EstadisticaRepository;
import usach.cl.tareasbackend.security.UsuarioAutenticado;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * Endpoints que responden las 8 preguntas del enunciado con PostGIS.
 */
@RestController
@RequestMapping("/api/estadisticas")
public class EstadisticaController {

    private final EstadisticaRepository repo;

    public EstadisticaController(EstadisticaRepository repo) {
        this.repo = repo;
    }

    /** P1 */
    @GetMapping("/tareas-por-sector")
    public List<Map<String, Object>> tareasPorSector(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.tareasPorSector(u.id());
    }

    /** P2 */
    @GetMapping("/tarea-mas-cercana")
    public List<Map<String, Object>> tareaMasCercana(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.tareaMasCercana(u.id());
    }

    /** P3 (radioKm=2) y P7 (radioKm=5) */
    @GetMapping("/sector-mas-completadas")
    public List<Map<String, Object>> sectorMasCompletadas(
            @AuthenticationPrincipal UsuarioAutenticado u,
            @RequestParam(defaultValue = "2") double radioKm) {
        return repo.sectorConMasCompletadas(u.id(), radioKm * 1000);
    }

    /** P4 */
    @GetMapping("/promedio-distancia")
    public List<Map<String, Object>> promedioDistancia(@AuthenticationPrincipal UsuarioAutenticado u) {
        return repo.promedioDistancia(u.id());
    }

    /** P5 */
    @GetMapping("/clusters-pendientes")
    public List<Map<String, Object>> clustersPendientes(
            @RequestParam(defaultValue = "3") int k) {
        return repo.clustersPendientes(k);
    }

    /** P6 */
    @GetMapping("/tareas-por-usuario-sector")
    public List<Map<String, Object>> tareasPorUsuarioYSector() {
        return repo.tareasPorUsuarioYSector();
    }

    /** P8 */
    @GetMapping("/promedio-distancia-usuarios")
    public List<Map<String, Object>> promedioDistanciaTodos() {
        return repo.promedioDistanciaTodos();
    }
}
```

**Archivo: `backend/src/main/java/usach/cl/tareasbackend/controller/UsuarioController.java`**

```java
package usach.cl.tareasbackend.controller;

import usach.cl.tareasbackend.repository.UsuarioRepository;
import usach.cl.tareasbackend.security.UsuarioAutenticado;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.NoSuchElementException;

@RestController
@RequestMapping("/api/usuarios")
public class UsuarioController {

    private final UsuarioRepository usuarioRepository;

    public UsuarioController(UsuarioRepository usuarioRepository) {
        this.usuarioRepository = usuarioRepository;
    }

    /** Perfil del usuario autenticado con sus coordenadas (para el mapa). */
    @GetMapping("/me")
    public Map<String, Object> perfil(@AuthenticationPrincipal UsuarioAutenticado u) {
        return usuarioRepository.datosPerfil(u.id())
                .orElseThrow(() -> new NoSuchElementException("Usuario no encontrado"));
    }
}
```
**Checkpoint 2.4 — cierre de la Fase 2:** guarda este archivo en la raíz del
proyecto y ejecuta cada bloque con el ▶ del HTTP Client de IntelliJ, de arriba
hacia abajo. Las 13 pruebas en verde = Fase 2 terminada.

**Archivo: `backend/pruebas.http`**

```http
### ============================================================
### BATERIA DE PRUEBAS DE LA API - Control 2 TBD
### Uso: guardar como pruebas.http dentro del proyecto en IntelliJ
### y ejecutar cada bloque con el boton verde que aparece al lado.
### Requisitos: BD de Docker arriba + backend corriendo (:8080).
### El login guarda el token automaticamente en {{token}}.
### ============================================================

### 1. REGISTRO de un usuario nuevo (fase 2.3) -> 201
POST http://localhost:8080/api/auth/register
Content-Type: application/json

{
  "nombreUsuario": "prueba1",
  "contrasena": "1234",
  "direccion": "Av. Libertador B. O'Higgins 3363",
  "latitud": -33.4489,
  "longitud": -70.6506
}

### 1b. REGISTRO duplicado (mismo nombre) -> 400 con mensaje claro
POST http://localhost:8080/api/auth/register
Content-Type: application/json

{
  "nombreUsuario": "prueba1",
  "contrasena": "1234",
  "direccion": "Otra direccion",
  "latitud": -33.4,
  "longitud": -70.6
}

### 2. LOGIN -> 200 y captura el token para el resto de las pruebas
POST http://localhost:8080/api/auth/login
Content-Type: application/json

{
  "nombreUsuario": "prueba1",
  "contrasena": "1234"
}

> {% client.global.set("token", response.body.token); %}

### 2b. LOGIN con clave mala -> 401 (mismo mensaje que usuario inexistente)
POST http://localhost:8080/api/auth/login
Content-Type: application/json

{
  "nombreUsuario": "prueba1",
  "contrasena": "incorrecta"
}

### 3. RUTA PROTEGIDA SIN TOKEN -> 401 (el middleware funciona)
GET http://localhost:8080/api/tareas

### 3b. TOKEN ADULTERADO -> 401 (la firma HS256 detecta el cambio)
GET http://localhost:8080/api/tareas
Authorization: Bearer {{token}}XXX

### 4. SECTORES con token -> 200, lista con latitud/longitud (fase 2.4)
GET http://localhost:8080/api/sectores
Authorization: Bearer {{token}}

### 5. CREAR TAREA -> 201; guarda el id para las pruebas siguientes
POST http://localhost:8080/api/tareas
Content-Type: application/json
Authorization: Bearer {{token}}

{
  "titulo": "Tarea de prueba HTTP",
  "descripcion": "Creada desde el HTTP Client de IntelliJ",
  "fechaVencimiento": "2026-07-20",
  "idSector": 1
}

> {% client.global.set("idTarea", response.body.idTarea); %}

### 5b. CREAR TAREA QUE VENCE EN 2 DIAS (debe disparar el trigger)
### Ajusta la fecha a hoy+2 antes de ejecutar
POST http://localhost:8080/api/tareas
Content-Type: application/json
Authorization: Bearer {{token}}

{
  "titulo": "Vence pronto",
  "descripcion": "Para probar el trigger de notificaciones",
  "fechaVencimiento": "2026-07-14",
  "idSector": 2
}

### 6. LISTAR con FILTROS (Requisito 3): estado + palabra clave
GET http://localhost:8080/api/tareas?estado=pendiente&buscar=prueba
Authorization: Bearer {{token}}

### 7. EDITAR la tarea creada -> 200
PUT http://localhost:8080/api/tareas/{{idTarea}}
Content-Type: application/json
Authorization: Bearer {{token}}

{
  "titulo": "Tarea de prueba HTTP (editada)",
  "descripcion": "Descripcion modificada",
  "fechaVencimiento": "2026-07-25",
  "idSector": 3
}

### 8. COMPLETAR -> 200 con completada=true y fechaCompletada
PATCH http://localhost:8080/api/tareas/{{idTarea}}/completar
Authorization: Bearer {{token}}

### 9. NOTIFICACIONES -> 200; debe aparecer la de "Vence pronto"
GET http://localhost:8080/api/notificaciones
Authorization: Bearer {{token}}

### 10. LAS 8 PREGUNTAS (fase 2.4)
GET http://localhost:8080/api/estadisticas/tareas-por-sector
Authorization: Bearer {{token}}

### P2
GET http://localhost:8080/api/estadisticas/tarea-mas-cercana
Authorization: Bearer {{token}}

### P3 (2 km)
GET http://localhost:8080/api/estadisticas/sector-mas-completadas?radioKm=2
Authorization: Bearer {{token}}

### P4
GET http://localhost:8080/api/estadisticas/promedio-distancia
Authorization: Bearer {{token}}

### P5
GET http://localhost:8080/api/estadisticas/clusters-pendientes?k=3
Authorization: Bearer {{token}}

### P6
GET http://localhost:8080/api/estadisticas/tareas-por-usuario-sector
Authorization: Bearer {{token}}

### P7 (5 km)
GET http://localhost:8080/api/estadisticas/sector-mas-completadas?radioKm=5
Authorization: Bearer {{token}}

### P8
GET http://localhost:8080/api/estadisticas/promedio-distancia-usuarios
Authorization: Bearer {{token}}

### 11. PERFIL con coordenadas (para el mapa de la fase 3)
GET http://localhost:8080/api/usuarios/me
Authorization: Bearer {{token}}

### 12. PRUEBA DE AUTORIZACION: intentar editar una tarea AJENA -> 404
### (los ids 1..30 son de los usuarios de loadData, no de "prueba1")
PUT http://localhost:8080/api/tareas/1
Content-Type: application/json
Authorization: Bearer {{token}}

{
  "titulo": "intento de hackeo",
  "descripcion": "no deberia funcionar",
  "fechaVencimiento": "2026-08-01",
  "idSector": 1
}

### 13. ELIMINAR la tarea de prueba -> 204
DELETE http://localhost:8080/api/tareas/{{idTarea}}
Authorization: Bearer {{token}}

### ============================================================
### Verificaciones en la BASE DE DATOS (pgAdmin / DBeaver / psql)
### Conexion: localhost:5435, postgres/postgres, BD tareas_db
### ------------------------------------------------------------
### SELECT nombre_usuario, contrasena FROM usuario;      -- hash $2a$
### SELECT ST_AsText(ubicacion) FROM usuario;            -- POINT(lng lat)
### SELECT * FROM notificacion ORDER BY fecha_creacion;  -- trigger
### SELECT * FROM tarea WHERE completada = TRUE;         -- fecha_completada
### ============================================================
```
---

# FASE 3 — Frontend Vue

Estructura: primero la "plomería" (configuración, cliente HTTP, sesión,
router), luego los componentes reutilizables y al final las vistas.
**Importante:** el router importa las 4 vistas, así que `npm run dev` recién
va a levantar cuando TODOS los archivos de esta fase existan. Crea las
carpetas: `frontend/src/components`, `frontend/src/views`, `frontend/src/assets`.

```bash
cd frontend
npm install    # lee el package.json de abajo e instala vue, router, axios, leaflet y vite
```

## 3.1 Configuración y plomería

**Archivo: `frontend/package.json`**

```json
{
  "name": "tareas-frontend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "axios": "^1.7.9",
    "leaflet": "^1.9.4",
    "vue": "^3.5.13",
    "vue-router": "^4.5.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^5.2.1",
    "vite": "^5.4.11"
  }
}
```

`vite.config.js`: el proxy `/api` → backend evita CORS en desarrollo y permite usar la misma baseURL que en producción.

**Archivo: `frontend/vite.config.js`**

```js
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// En desarrollo, las llamadas a /api se redirigen al backend Spring
// (evita problemas de CORS y permite usar la misma baseURL que en produccion)
export default defineConfig({
  plugins: [vue()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:8080',
    },
  },
})
```

**Archivo: `frontend/index.html`**

```html
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Tareas Territoriales — Control 2 TBD</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;600;700&family=Barlow:wght@400;500;600&display=swap"
      rel="stylesheet"
    />
  </head>
  <body>
    <div id="app"></div>
    <script type="module" src="/src/main.js"></script>
  </body>
</html>
```

**Archivo: `frontend/src/main.js`**

```js
import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import './assets/styles.css'

createApp(App).use(router).mount('#app')
```

`api.js`: cliente Axios único; un interceptor cuelga el JWT y otro reacciona al 401 (token vencido) cerrando la sesión.

**Archivo: `frontend/src/api.js`**

```js
import axios from 'axios'

/**
 * Cliente HTTP unico de la aplicacion.
 * - baseURL '/api': en desarrollo Vite lo redirige al backend (proxy),
 *   en produccion nginx hace lo mismo. Asi el codigo no cambia.
 * - Interceptor de peticion: adjunta el JWT en el header Authorization.
 * - Interceptor de respuesta: si el backend responde 401 (token invalido
 *   o expirado) se cierra la sesion y se vuelve al login.
 */
const api = axios.create({ baseURL: '/api' })

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  (respuesta) => respuesta,
  (error) => {
    const enLogin = window.location.pathname.startsWith('/login')
    if (error.response && error.response.status === 401 && !enLogin) {
      localStorage.removeItem('token')
      localStorage.removeItem('usuario')
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

export default api
```

`auth.js`: estado de sesión reactivo compartido, persistido en localStorage.

**Archivo: `frontend/src/auth.js`**

```js
import { reactive } from 'vue'

/**
 * Estado de sesion compartido por toda la aplicacion (patron composable).
 * Se persiste en localStorage para sobrevivir recargas de pagina.
 */
export const sesion = reactive({
  token: localStorage.getItem('token'),
  usuario: JSON.parse(localStorage.getItem('usuario') || 'null'),
})

export function guardarSesion(datos) {
  sesion.token = datos.token
  sesion.usuario = { id: datos.id, nombreUsuario: datos.nombreUsuario }
  localStorage.setItem('token', datos.token)
  localStorage.setItem('usuario', JSON.stringify(sesion.usuario))
}

export function cerrarSesion() {
  sesion.token = null
  sesion.usuario = null
  localStorage.removeItem('token')
  localStorage.removeItem('usuario')
}
```

`router.js`: rutas + guardia de navegación (usabilidad; la seguridad real es el 401 del backend).

**Archivo: `frontend/src/router.js`**

```js
import { createRouter, createWebHistory } from 'vue-router'
import { sesion } from './auth'
import LoginView from './views/LoginView.vue'
import RegistroView from './views/RegistroView.vue'
import TareasView from './views/TareasView.vue'
import EstadisticasView from './views/EstadisticasView.vue'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', redirect: '/tareas' },
    { path: '/login', component: LoginView, meta: { publica: true } },
    { path: '/registro', component: RegistroView, meta: { publica: true } },
    { path: '/tareas', component: TareasView },
    { path: '/estadisticas', component: EstadisticasView },
  ],
})

/**
 * Guardia de navegacion: proteccion de rutas en el cliente.
 * (La proteccion real esta en el backend: sin JWT valido la API responde 401.)
 */
router.beforeEach((to) => {
  if (!to.meta.publica && !sesion.token) return '/login'
  if (to.meta.publica && sesion.token) return '/tareas'
})

export default router
```

`leafletBase.js`: configura Leaflet una sola vez y corrige los íconos (bug clásico con bundlers).

**Archivo: `frontend/src/leafletBase.js`**

```js
/**
 * Configuracion base de Leaflet compartida por los componentes de mapa.
 * Corrige la ruta de los iconos por defecto (problema conocido de Leaflet
 * con empaquetadores como Vite) importandolos como assets del bundle.
 */
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import iconRetinaUrl from 'leaflet/dist/images/marker-icon-2x.png'
import iconUrl from 'leaflet/dist/images/marker-icon.png'
import shadowUrl from 'leaflet/dist/images/marker-shadow.png'

delete L.Icon.Default.prototype._getIconUrl
L.Icon.Default.mergeOptions({ iconRetinaUrl, iconUrl, shadowUrl })

export default L
```

**Archivo: `frontend/src/App.vue`**

```vue
<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import BarraNavegacion from './components/BarraNavegacion.vue'
import { sesion } from './auth'

const route = useRoute()
const mostrarNav = computed(() => !route.meta.publica && !!sesion.token)
</script>

<template>
  <BarraNavegacion v-if="mostrarNav" />
  <main class="contenido">
    <router-view />
  </main>
</template>
```

`styles.css`: el sistema de diseño completo (identidad de señalética de obras: tipografía condensada, naranjo de obras, sello COMPLETADA).

**Archivo: `frontend/src/assets/styles.css`**

```css
/* ============================================================
   TAREAS TERRITORIALES - Sistema de diseño
   Identidad: señalética de obras públicas / cartografía técnica.
   - Display: Barlow Condensed (tipografía de señal vial)
   - Cuerpo: Barlow
   - Acento: naranjo de obras (--obra)
   - Firma visual: sello "COMPLETADA" tipo timbre en las tarjetas
   ============================================================ */

:root {
  --tinta: #182226;        /* texto principal, casi negro azulado */
  --tinta-suave: #5a6b72;  /* texto secundario */
  --papel: #eef1ef;        /* fondo general, gris verdoso claro */
  --carta: #ffffff;        /* fondo de tarjetas y paneles */
  --obra: #d95b12;         /* naranjo de obras: acciones primarias */
  --obra-oscuro: #b34a0d;
  --mapa: #28536b;         /* azul cartográfico: datos espaciales */
  --ok: #2e7d5b;           /* verde: completado */
  --alerta: #b3261e;       /* rojo: vencido / eliminar */
  --borde: #d7ddd9;
  --radio: 6px;
  --sombra: 0 1px 3px rgba(24, 34, 38, 0.12);
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  background: var(--papel);
  color: var(--tinta);
  font-family: 'Barlow', system-ui, -apple-system, sans-serif;
  font-size: 15px;
  line-height: 1.5;
}

h1, h2, h3 {
  font-family: 'Barlow Condensed', 'Barlow', sans-serif;
  letter-spacing: 0.01em;
  margin: 0;
}

h1 { font-size: 2.1rem; font-weight: 700; text-transform: uppercase; }
h2 { font-size: 1.25rem; font-weight: 600; text-transform: uppercase; }
h3 { font-size: 1.15rem; font-weight: 600; }

em { color: var(--obra); font-style: normal; }

.eyebrow {
  font-family: 'Barlow Condensed', sans-serif;
  font-size: 0.8rem;
  font-weight: 600;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--tinta-suave);
  margin: 0 0 2px;
}

.contenido {
  max-width: 1100px;
  margin: 0 auto;
  padding: 24px 20px 60px;
}

/* ---------- Barra de navegación ---------- */
.nav {
  display: flex;
  align-items: center;
  gap: 28px;
  background: var(--tinta);
  color: #fff;
  padding: 10px 24px;
  border-bottom: 4px solid var(--obra);
}

.nav-marca { display: flex; align-items: center; gap: 8px; }
.nav-logo { color: var(--obra); font-size: 1.2rem; }
.nav-titulo {
  font-family: 'Barlow Condensed', sans-serif;
  font-size: 1.25rem;
  font-weight: 700;
  text-transform: uppercase;
}

.nav-enlaces { display: flex; gap: 18px; flex: 1; }
.nav-enlaces a {
  color: #cfd8d3;
  text-decoration: none;
  font-family: 'Barlow Condensed', sans-serif;
  font-size: 1.02rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 4px 2px;
  border-bottom: 2px solid transparent;
}
.nav-enlaces a.router-link-active {
  color: #fff;
  border-bottom-color: var(--obra);
}

.nav-usuario { display: flex; align-items: center; gap: 12px; }
.nav-nombre { font-weight: 600; }

/* ---------- Botones ---------- */
.boton {
  font-family: 'Barlow', sans-serif;
  font-size: 0.92rem;
  font-weight: 600;
  border: 1px solid transparent;
  border-radius: var(--radio);
  padding: 8px 16px;
  cursor: pointer;
  transition: background 0.15s ease;
}
.boton:disabled { opacity: 0.55; cursor: not-allowed; }
.boton:focus-visible { outline: 2px solid var(--mapa); outline-offset: 2px; }

.boton-primario { background: var(--obra); color: #fff; }
.boton-primario:hover:not(:disabled) { background: var(--obra-oscuro); }

.boton-secundario {
  background: transparent;
  color: inherit;
  border-color: var(--borde);
}
.nav .boton-secundario { color: #fff; border-color: #4a585e; }
.boton-secundario:hover:not(:disabled) { border-color: var(--tinta-suave); }

.boton-peligro { background: transparent; color: var(--alerta); border-color: var(--alerta); }
.boton-peligro:hover:not(:disabled) { background: #fdf1f0; }

.ancho { width: 100%; }
.centrado { display: block; text-align: center; text-decoration: none; }
.enlace {
  background: none;
  border: none;
  color: var(--mapa);
  cursor: pointer;
  padding: 0;
  font-size: 0.85rem;
  text-decoration: underline;
}

/* ---------- Cabecera de página ---------- */
.pagina-cabecera {
  display: flex;
  justify-content: space-between;
  align-items: flex-end;
  gap: 16px;
  margin-bottom: 18px;
  flex-wrap: wrap;
}
.pagina-acciones { display: flex; gap: 10px; align-items: center; }

/* ---------- Filtros ---------- */
.filtros {
  display: flex;
  gap: 12px;
  align-items: center;
  flex-wrap: wrap;
  margin-bottom: 20px;
}
.filtros-estado {
  display: flex;
  border: 1px solid var(--borde);
  border-radius: var(--radio);
  overflow: hidden;
  background: var(--carta);
}
.filtro-boton {
  background: transparent;
  border: none;
  padding: 8px 14px;
  cursor: pointer;
  font-family: 'Barlow Condensed', sans-serif;
  font-size: 0.95rem;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--tinta-suave);
}
.filtro-boton.activo { background: var(--tinta); color: #fff; }

.filtros-buscar {
  flex: 1;
  min-width: 220px;
  padding: 9px 12px;
  border: 1px solid var(--borde);
  border-radius: var(--radio);
  font: inherit;
  background: var(--carta);
}

/* ---------- Tarjetas de tareas ---------- */
.tarjetas {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 16px;
}

.tarjeta {
  position: relative;
  background: var(--carta);
  border: 1px solid var(--borde);
  border-left: 4px solid var(--obra);
  border-radius: var(--radio);
  padding: 16px;
  box-shadow: var(--sombra);
  display: flex;
  flex-direction: column;
  gap: 10px;
  overflow: hidden;
}
.tarjeta-completada { border-left-color: var(--ok); opacity: 0.92; }

.tarjeta-cabecera {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 10px;
}
.tarjeta-descripcion { margin: 0; color: var(--tinta-suave); flex: 1; }
.tarjeta-pie {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}
.tarjeta-fecha { font-size: 0.88rem; color: var(--tinta-suave); }
.tarjeta-acciones { display: flex; gap: 8px; flex-wrap: wrap; }

/* Chips */
.chip {
  font-family: 'Barlow Condensed', sans-serif;
  font-size: 0.82rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  padding: 3px 9px;
  border-radius: 999px;
  white-space: nowrap;
}
.chip-sector { background: #e7edf1; color: var(--mapa); }
.chip-porvencer { background: #fdeee3; color: var(--obra-oscuro); }
.chip-vencida { background: #fdeceb; color: var(--alerta); }

/* Firma visual: sello tipo timbre */
.sello {
  position: absolute;
  right: -6px;
  top: 14px;
  transform: rotate(8deg);
  font-family: 'Barlow Condensed', sans-serif;
  font-weight: 700;
  font-size: 0.95rem;
  letter-spacing: 0.2em;
  color: var(--ok);
  border: 2px solid var(--ok);
  border-radius: 4px;
  padding: 2px 10px;
  opacity: 0.85;
  pointer-events: none;
}

.vacio {
  color: var(--tinta-suave);
  background: var(--carta);
  border: 1px dashed var(--borde);
  border-radius: var(--radio);
  padding: 26px;
  text-align: center;
}

/* ---------- Formularios ---------- */
label {
  display: flex;
  flex-direction: column;
  gap: 5px;
  font-weight: 600;
  font-size: 0.9rem;
  margin-bottom: 12px;
}
input, textarea, select {
  font: inherit;
  font-weight: 400;
  padding: 9px 11px;
  border: 1px solid var(--borde);
  border-radius: var(--radio);
  background: #fff;
  color: var(--tinta);
}
input:focus, textarea:focus, select:focus {
  outline: 2px solid var(--mapa);
  outline-offset: 1px;
}
.fila {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 14px;
}
.ayuda { font-weight: 400; font-size: 0.85rem; color: var(--tinta-suave); }
.coordenadas {
  font-family: monospace;
  font-size: 0.88rem;
  color: var(--mapa);
  margin: 8px 0 12px;
}
.mensaje-error {
  background: #fdeceb;
  color: var(--alerta);
  border-radius: var(--radio);
  padding: 9px 12px;
  font-size: 0.9rem;
}
.mensaje-exito {
  background: #e8f4ee;
  color: var(--ok);
  border-radius: var(--radio);
  padding: 12px 14px;
  margin-bottom: 16px;
}

/* ---------- Modal ---------- */
.modal-fondo {
  position: fixed;
  inset: 0;
  background: rgba(24, 34, 38, 0.55);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  z-index: 1100;
}
.modal {
  background: var(--carta);
  border-radius: var(--radio);
  border-top: 4px solid var(--obra);
  padding: 22px;
  width: 100%;
  max-width: 520px;
  max-height: 90vh;
  overflow: auto;
}
.modal h2 { margin-bottom: 16px; }
.modal-acciones {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 6px;
}

/* ---------- Notificaciones ---------- */
.notifs { position: relative; }
.notifs-contador {
  background: var(--obra);
  color: #fff;
  border-radius: 999px;
  font-size: 0.75rem;
  padding: 1px 7px;
  margin-left: 4px;
}
.notifs-panel {
  position: absolute;
  right: 0;
  top: calc(100% + 8px);
  width: 320px;
  max-height: 380px;
  overflow: auto;
  background: var(--carta);
  border: 1px solid var(--borde);
  border-radius: var(--radio);
  box-shadow: 0 8px 24px rgba(24, 34, 38, 0.18);
  z-index: 1000;
  padding: 8px;
}
.notifs-item {
  padding: 10px;
  border-bottom: 1px solid var(--borde);
  display: flex;
  flex-direction: column;
  gap: 3px;
}
.notifs-item:last-child { border-bottom: none; }
.notifs-item p { margin: 0; font-size: 0.9rem; }
.notifs-item small { color: var(--tinta-suave); }
.notifs-item.leida { opacity: 0.55; }
.notifs-vacio { padding: 14px; color: var(--tinta-suave); font-size: 0.9rem; margin: 0; }

/* ---------- Acceso (login / registro) ---------- */
.acceso {
  min-height: calc(100vh - 48px);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px 0;
}
.acceso-panel {
  background: var(--carta);
  border: 1px solid var(--borde);
  border-top: 5px solid var(--obra);
  border-radius: var(--radio);
  box-shadow: var(--sombra);
  padding: 32px;
  width: 100%;
  max-width: 420px;
}
.acceso-panel-grande { max-width: 640px; }
.acceso-titulo { margin-bottom: 4px; }
.acceso-sub { color: var(--tinta-suave); margin: 0 0 22px; }
.acceso-alt { text-align: center; margin-top: 18px; font-size: 0.92rem; }
.acceso-alt a { color: var(--obra); }
.acceso-demo {
  text-align: center;
  font-size: 0.82rem;
  color: var(--tinta-suave);
  background: var(--papel);
  border-radius: var(--radio);
  padding: 6px;
  margin-top: 12px;
}

/* ---------- Estadísticas ---------- */
.stats-grilla {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 16px;
  margin-bottom: 20px;
}
.stat-carta {
  background: var(--tinta);
  color: #fff;
  border-radius: var(--radio);
  border-bottom: 4px solid var(--obra);
  padding: 18px;
}
.stat-etiqueta {
  font-family: 'Barlow Condensed', sans-serif;
  font-size: 0.85rem;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: #aebcc0;
  margin: 0 0 8px;
}
.stat-valor {
  font-family: 'Barlow Condensed', sans-serif;
  font-size: 1.7rem;
  font-weight: 700;
  margin: 0;
}
.stat-detalle { color: #cfd8d3; font-size: 0.88rem; margin: 4px 0 0; }
.stat-radios { display: flex; gap: 8px; margin-bottom: 10px; }
.stat-carta .filtro-boton { color: #aebcc0; border: 1px solid #4a585e; border-radius: var(--radio); }
.stat-carta .filtro-boton.activo { background: var(--obra); color: #fff; border-color: var(--obra); }

.stats-columnas {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 16px;
  margin-bottom: 20px;
}
.panel {
  background: var(--carta);
  border: 1px solid var(--borde);
  border-radius: var(--radio);
  padding: 18px;
}
.panel h2 { margin-bottom: 10px; }

table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
th {
  font-family: 'Barlow Condensed', sans-serif;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  font-size: 0.82rem;
  color: var(--tinta-suave);
  text-align: left;
  border-bottom: 2px solid var(--borde);
  padding: 6px 8px;
}
td { border-bottom: 1px solid var(--borde); padding: 7px 8px; }
tr:last-child td { border-bottom: none; }

/* ---------- Mapas ---------- */
.mapa {
  height: 260px;
  border-radius: var(--radio);
  border: 1px solid var(--borde);
  z-index: 0;
}
.mapa-grande { height: 420px; }

/* ---------- Responsivo y accesibilidad ---------- */
@media (max-width: 640px) {
  .fila { grid-template-columns: 1fr; }
  .nav { flex-wrap: wrap; gap: 10px; }
  .nav-enlaces { order: 3; width: 100%; }
}

@media (prefers-reduced-motion: reduce) {
  * { transition: none !important; animation: none !important; }
}
```
## 3.2 Componentes reutilizables (7)

Patrón: **props hacia abajo, eventos hacia arriba**. Los componentes muestran;
las vistas deciden y llaman a la API.

**Archivo: `frontend/src/components/BarraNavegacion.vue`**

```vue
<script setup>
import { useRouter } from 'vue-router'
import { sesion, cerrarSesion } from '../auth'

const router = useRouter()

function salir() {
  cerrarSesion()
  router.push('/login')
}
</script>

<template>
  <header class="nav">
    <div class="nav-marca">
      <span class="nav-logo">▦</span>
      <span class="nav-titulo">Tareas <em>Territoriales</em></span>
    </div>
    <nav class="nav-enlaces">
      <router-link to="/tareas">Mis tareas</router-link>
      <router-link to="/estadisticas">Estadísticas</router-link>
    </nav>
    <div class="nav-usuario">
      <span class="nav-nombre">{{ sesion.usuario?.nombreUsuario }}</span>
      <button class="boton boton-secundario" @click="salir">Cerrar sesión</button>
    </div>
  </header>
</template>
```

`TareaCard`: muestra una tarea y emite `editar`/`eliminar`/`completar`; calcula el aviso de vencimiento.

**Archivo: `frontend/src/components/TareaCard.vue`**

```vue
<script setup>
import { computed } from 'vue'

/**
 * Componente reutilizable: tarjeta de una tarea.
 * Recibe la tarea por props y comunica las acciones al padre por eventos
 * (el componente no llama a la API directamente: separacion de responsabilidades).
 */
const props = defineProps({ tarea: { type: Object, required: true } })
const emit = defineEmits(['editar', 'eliminar', 'completar'])

const diasRestantes = computed(() => {
  const hoy = new Date()
  hoy.setHours(0, 0, 0, 0)
  const vencimiento = new Date(props.tarea.fechaVencimiento + 'T00:00:00')
  return Math.round((vencimiento - hoy) / 86400000)
})

const avisoVencimiento = computed(() => {
  if (props.tarea.completada) return null
  if (diasRestantes.value < 0) return { clase: 'chip-vencida', texto: 'Vencida' }
  if (diasRestantes.value === 0) return { clase: 'chip-porvencer', texto: 'Vence hoy' }
  if (diasRestantes.value <= 3)
    return { clase: 'chip-porvencer', texto: 'Vence en ' + diasRestantes.value + ' día(s)' }
  return null
})

function formatearFecha(f) {
  return new Date(f + 'T00:00:00').toLocaleDateString('es-CL')
}
</script>

<template>
  <article class="tarjeta" :class="{ 'tarjeta-completada': tarea.completada }">
    <div class="tarjeta-cabecera">
      <h3>{{ tarea.titulo }}</h3>
      <span class="chip chip-sector">{{ tarea.nombreSector }}</span>
    </div>
    <p class="tarjeta-descripcion">{{ tarea.descripcion || 'Sin descripción' }}</p>
    <div class="tarjeta-pie">
      <span class="tarjeta-fecha">Vence: {{ formatearFecha(tarea.fechaVencimiento) }}</span>
      <span v-if="avisoVencimiento" class="chip" :class="avisoVencimiento.clase">
        {{ avisoVencimiento.texto }}
      </span>
    </div>
    <div class="tarjeta-acciones">
      <template v-if="!tarea.completada">
        <button class="boton boton-primario" @click="emit('completar', tarea)">Completar</button>
        <button class="boton boton-secundario" @click="emit('editar', tarea)">Editar</button>
      </template>
      <button class="boton boton-peligro" @click="emit('eliminar', tarea)">Eliminar</button>
    </div>
    <div v-if="tarea.completada" class="sello">COMPLETADA</div>
  </article>
</template>
```

`TareaForm`: un solo componente para CREAR (prop `tarea=null`) y EDITAR (prop con datos).

**Archivo: `frontend/src/components/TareaForm.vue`**

```vue
<script setup>
import { computed, reactive } from 'vue'

/**
 * Componente reutilizable: formulario de tarea en modal.
 * Se usa tanto para CREAR (prop tarea = null) como para EDITAR
 * (prop tarea con datos): mismo componente, dos usos.
 */
const props = defineProps({
  tarea: { type: Object, default: null },
  sectores: { type: Array, default: () => [] },
})
const emit = defineEmits(['guardar', 'cerrar'])

const form = reactive({
  titulo: props.tarea?.titulo || '',
  descripcion: props.tarea?.descripcion || '',
  fechaVencimiento: props.tarea?.fechaVencimiento || '',
  idSector: props.tarea?.idSector || props.sectores[0]?.idSector || null,
})

const tituloModal = computed(() => (props.tarea ? 'Editar tarea' : 'Nueva tarea'))
const valido = computed(() => form.titulo.trim() && form.fechaVencimiento && form.idSector)

function enviar() {
  if (!valido.value) return
  emit('guardar', { ...form, titulo: form.titulo.trim() })
}
</script>

<template>
  <div class="modal-fondo" @click.self="emit('cerrar')">
    <div class="modal">
      <h2>{{ tituloModal }}</h2>
      <label>
        Título
        <input v-model="form.titulo" placeholder="Ej: Reparar semáforo en cruce principal" />
      </label>
      <label>
        Descripción
        <textarea v-model="form.descripcion" rows="3" placeholder="Detalle del trabajo a realizar"></textarea>
      </label>
      <div class="fila">
        <label>
          Fecha de vencimiento
          <input type="date" v-model="form.fechaVencimiento" />
        </label>
        <label>
          Sector
          <select v-model="form.idSector">
            <option v-for="s in sectores" :key="s.idSector" :value="s.idSector">
              {{ s.nombre }}
            </option>
          </select>
        </label>
      </div>
      <div class="modal-acciones">
        <button class="boton boton-secundario" @click="emit('cerrar')">Cancelar</button>
        <button class="boton boton-primario" :disabled="!valido" @click="enviar">
          Guardar tarea
        </button>
      </div>
    </div>
  </div>
</template>
```

`FiltrosBarra`: estado + búsqueda con v-model doble (Requisito 3).

**Archivo: `frontend/src/components/FiltrosBarra.vue`**

```vue
<script setup>
/**
 * Componente reutilizable: barra de filtros (Requisito Funcional 3).
 * Estado (pendiente/completada) + busqueda por palabra clave.
 * Usa v-model multiple (update:estado / update:buscar).
 */
defineProps({ estado: String, buscar: String })
const emit = defineEmits(['update:estado', 'update:buscar'])

const opciones = [
  { valor: '', texto: 'Todas' },
  { valor: 'pendiente', texto: 'Pendientes' },
  { valor: 'completada', texto: 'Completadas' },
]
</script>

<template>
  <div class="filtros">
    <div class="filtros-estado">
      <button
        v-for="o in opciones"
        :key="o.valor"
        class="filtro-boton"
        :class="{ activo: estado === o.valor }"
        @click="emit('update:estado', o.valor)"
      >
        {{ o.texto }}
      </button>
    </div>
    <input
      class="filtros-buscar"
      :value="buscar"
      placeholder="Buscar por título o descripción…"
      @input="emit('update:buscar', $event.target.value)"
    />
  </div>
</template>
```

`PanelNotificaciones`: campana con contador de no leídas (Requisito 4).

**Archivo: `frontend/src/components/PanelNotificaciones.vue`**

```vue
<script setup>
import { computed, ref } from 'vue'

/**
 * Componente reutilizable: campana de notificaciones (Requisito Funcional 4).
 * Muestra los avisos de tareas por vencer generados en la base de datos.
 */
const props = defineProps({ notificaciones: { type: Array, default: () => [] } })
const emit = defineEmits(['leer'])

const abierto = ref(false)
const noLeidas = computed(() => props.notificaciones.filter((n) => !n.leida).length)

function formatear(f) {
  return new Date(f).toLocaleString('es-CL')
}
</script>

<template>
  <div class="notifs">
    <button class="boton boton-secundario" @click="abierto = !abierto">
      Notificaciones
      <span v-if="noLeidas" class="notifs-contador">{{ noLeidas }}</span>
    </button>
    <div v-if="abierto" class="notifs-panel">
      <p v-if="!notificaciones.length" class="notifs-vacio">
        Sin avisos por ahora. Aquí aparecerán las tareas próximas a vencer.
      </p>
      <div
        v-for="n in notificaciones"
        :key="n.idNotificacion"
        class="notifs-item"
        :class="{ leida: n.leida }"
      >
        <p>{{ n.mensaje }}</p>
        <small>{{ formatear(n.fechaCreacion) }}</small>
        <button v-if="!n.leida" class="enlace" @click="emit('leer', n.idNotificacion)">
          Marcar leída
        </button>
      </div>
    </div>
  </div>
</template>
```

`MapaSelector`: mapa para ELEGIR un punto (registro); emite {lat, lng}.

**Archivo: `frontend/src/components/MapaSelector.vue`**

```vue
<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue'
import L from '../leafletBase'

/**
 * Componente reutilizable: mapa para SELECCIONAR un punto.
 * Se usa en el registro para capturar la direccion geografica del usuario
 * (Requisito Funcional 1): el punto elegido se guarda como GEOMETRY(Point)
 * en PostGIS. Emite { lat, lng } al hacer clic.
 */
const props = defineProps({ modelValue: { type: Object, default: null } })
const emit = defineEmits(['update:modelValue'])

const contenedor = ref(null)
let mapa = null
let marcador = null

function ponerMarcador(latlng) {
  if (marcador) marcador.setLatLng(latlng)
  else marcador = L.marker(latlng).addTo(mapa)
}

onMounted(() => {
  mapa = L.map(contenedor.value).setView([-33.4489, -70.6693], 11)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap',
  }).addTo(mapa)

  if (props.modelValue) ponerMarcador([props.modelValue.lat, props.modelValue.lng])

  mapa.on('click', (e) => {
    ponerMarcador(e.latlng)
    emit('update:modelValue', {
      lat: +e.latlng.lat.toFixed(6),
      lng: +e.latlng.lng.toFixed(6),
    })
  })

  setTimeout(() => mapa.invalidateSize(), 150)
})

onBeforeUnmount(() => {
  if (mapa) mapa.remove()
})
</script>

<template>
  <div ref="contenedor" class="mapa"></div>
</template>
```

`MapaSectores`: mapa para VISUALIZAR sectores, tu ubicación y los clusters de la P5.

**Archivo: `frontend/src/components/MapaSectores.vue`**

```vue
<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import L from '../leafletBase'

/**
 * Componente reutilizable: mapa para VISUALIZAR datos espaciales.
 * - Marcadores de sectores (puntos PostGIS de la tabla sector)
 * - Ubicacion del usuario (punto PostGIS de la tabla usuario)
 * - Circulos de clusters de tareas pendientes (ST_ClusterKMeans, Pregunta 5)
 */
const props = defineProps({
  sectores: { type: Array, default: () => [] },
  usuario: { type: Object, default: null },
  clusters: { type: Array, default: () => [] },
})

const contenedor = ref(null)
let mapa = null
let capa = null

function dibujar() {
  if (!mapa) return
  if (capa) capa.remove()
  capa = L.layerGroup().addTo(mapa)

  props.sectores.forEach((s) => {
    L.marker([s.latitud, s.longitud])
      .addTo(capa)
      .bindPopup('<b>' + s.nombre + '</b><br>Sector de trabajo')
  })

  if (props.usuario) {
    L.circleMarker([props.usuario.latitud, props.usuario.longitud], {
      radius: 9,
      color: '#D95B12',
      fillColor: '#D95B12',
      fillOpacity: 0.9,
    })
      .addTo(capa)
      .bindPopup('<b>Tu ubicación registrada</b><br>' + (props.usuario.direccion || ''))
  }

  props.clusters.forEach((c) => {
    L.circle([c.latitud_centro, c.longitud_centro], {
      radius: 300 + 250 * Number(c.tareas_pendientes),
      color: '#28536B',
      fillColor: '#28536B',
      fillOpacity: 0.12,
    })
      .addTo(capa)
      .bindPopup(
        '<b>Concentración de pendientes</b><br>' +
          c.tareas_pendientes + ' tareas<br>' + c.sectores
      )
  })
}

onMounted(() => {
  mapa = L.map(contenedor.value).setView([-33.46, -70.65], 11)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap',
  }).addTo(mapa)
  dibujar()
  setTimeout(() => mapa.invalidateSize(), 150)
})

watch(() => [props.sectores, props.usuario, props.clusters], dibujar, { deep: true })

onBeforeUnmount(() => {
  if (mapa) mapa.remove()
})
</script>

<template>
  <div ref="contenedor" class="mapa mapa-grande"></div>
</template>
```
## 3.3 Vistas (4)

**Archivo: `frontend/src/views/LoginView.vue`**

```vue
<script setup>
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import api from '../api'
import { guardarSesion } from '../auth'

const router = useRouter()
const form = reactive({ nombreUsuario: '', contrasena: '' })
const error = ref('')
const cargando = ref(false)

async function entrar() {
  error.value = ''
  cargando.value = true
  try {
    const { data } = await api.post('/auth/login', form)
    guardarSesion(data)
    router.push('/tareas')
  } catch (e) {
    error.value = e.response?.data?.error || 'No se pudo iniciar sesión. Revisa tus datos.'
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="acceso">
    <div class="acceso-panel">
      <p class="eyebrow">Control 2 · Taller de Base de Datos</p>
      <h1 class="acceso-titulo">Tareas <em>Territoriales</em></h1>
      <p class="acceso-sub">Gestión de tareas georreferenciadas por sector</p>

      <form @submit.prevent="entrar">
        <label>
          Nombre de usuario
          <input v-model="form.nombreUsuario" autocomplete="username" />
        </label>
        <label>
          Contraseña
          <input type="password" v-model="form.contrasena" autocomplete="current-password" />
        </label>
        <p v-if="error" class="mensaje-error">{{ error }}</p>
        <button class="boton boton-primario ancho" :disabled="cargando">
          {{ cargando ? 'Entrando…' : 'Iniciar sesión' }}
        </button>
      </form>

      <p class="acceso-alt">
        ¿No tienes cuenta? <router-link to="/registro">Regístrate aquí</router-link>
      </p>
      <p class="acceso-demo">Datos de prueba: admin / admin123</p>
    </div>
  </div>
</template>
```

`RegistroView`: Requisito 1 — el punto elegido en el mapa viaja a la API y se guarda como GEOMETRY(Point) en PostGIS.

**Archivo: `frontend/src/views/RegistroView.vue`**

```vue
<script setup>
import { reactive, ref } from 'vue'
import api from '../api'
import MapaSelector from '../components/MapaSelector.vue'

/**
 * Registro de usuarios (Requisito Funcional 1): nombre, contrasena y
 * direccion geografica seleccionada en el mapa. Las coordenadas se
 * envian a la API, que las guarda como punto PostGIS.
 */
const form = reactive({ nombreUsuario: '', contrasena: '', direccion: '' })
const punto = ref(null)
const error = ref('')
const exito = ref(false)
const cargando = ref(false)

async function registrar() {
  error.value = ''
  if (!form.nombreUsuario.trim() || !form.contrasena || !form.direccion.trim()) {
    error.value = 'Completa nombre de usuario, contraseña y dirección.'
    return
  }
  if (!punto.value) {
    error.value = 'Marca tu ubicación en el mapa (haz clic sobre el punto donde vives).'
    return
  }
  cargando.value = true
  try {
    await api.post('/auth/register', {
      nombreUsuario: form.nombreUsuario.trim(),
      contrasena: form.contrasena,
      direccion: form.direccion.trim(),
      latitud: punto.value.lat,
      longitud: punto.value.lng,
    })
    exito.value = true
  } catch (e) {
    error.value = e.response?.data?.error || 'No se pudo completar el registro.'
  } finally {
    cargando.value = false
  }
}
</script>

<template>
  <div class="acceso">
    <div class="acceso-panel acceso-panel-grande">
      <p class="eyebrow">Crear cuenta</p>
      <h1 class="acceso-titulo">Registro</h1>

      <template v-if="!exito">
        <form @submit.prevent="registrar">
          <div class="fila">
            <label>
              Nombre de usuario
              <input v-model="form.nombreUsuario" autocomplete="username" />
            </label>
            <label>
              Contraseña
              <input type="password" v-model="form.contrasena" autocomplete="new-password" />
            </label>
          </div>
          <label>
            Dirección (texto)
            <input v-model="form.direccion" placeholder="Ej: Av. Libertador B. O'Higgins 3363" />
          </label>
          <label>
            Ubicación en el mapa
            <span class="ayuda">Haz clic en el mapa para marcar tu punto geográfico.</span>
          </label>
          <MapaSelector v-model="punto" />
          <p v-if="punto" class="coordenadas">
            Punto seleccionado: {{ punto.lat }}, {{ punto.lng }}
          </p>
          <p v-if="error" class="mensaje-error">{{ error }}</p>
          <button class="boton boton-primario ancho" :disabled="cargando">
            {{ cargando ? 'Registrando…' : 'Crear cuenta' }}
          </button>
        </form>
        <p class="acceso-alt">
          ¿Ya tienes cuenta? <router-link to="/login">Inicia sesión</router-link>
        </p>
      </template>

      <template v-else>
        <p class="mensaje-exito">
          Cuenta creada. Tu ubicación quedó registrada como punto geoespacial.
        </p>
        <router-link class="boton boton-primario ancho centrado" to="/login">
          Ir a iniciar sesión
        </router-link>
      </template>
    </div>
  </div>
</template>
```

`TareasView`: orquesta el CRUD, los filtros (con debounce de 300 ms) y las notificaciones. Única que llama a la API en esta pantalla.

**Archivo: `frontend/src/views/TareasView.vue`**

```vue
<script setup>
import { onMounted, reactive, ref, watch } from 'vue'
import api from '../api'
import TareaCard from '../components/TareaCard.vue'
import TareaForm from '../components/TareaForm.vue'
import FiltrosBarra from '../components/FiltrosBarra.vue'
import PanelNotificaciones from '../components/PanelNotificaciones.vue'

/**
 * Vista principal: Gestion de Tareas (Requisito Funcional 2) con
 * filtros y busqueda (RF 3) y notificaciones (RF 4).
 * El filtrado se hace EN LA BASE DE DATOS (query params -> SQL),
 * no en el navegador.
 */
const tareas = ref([])
const sectores = ref([])
const notificaciones = ref([])
const filtros = reactive({ estado: '', buscar: '' })
const mostrarForm = ref(false)
const tareaEnEdicion = ref(null)
const error = ref('')
let temporizador = null

async function cargarTareas() {
  const params = {}
  if (filtros.estado) params.estado = filtros.estado
  if (filtros.buscar) params.buscar = filtros.buscar
  const { data } = await api.get('/tareas', { params })
  tareas.value = data
}

async function cargarSectores() {
  sectores.value = (await api.get('/sectores')).data
}

async function cargarNotificaciones() {
  notificaciones.value = (await api.get('/notificaciones')).data
}

// Busqueda con retardo (debounce) para no consultar en cada tecla
watch(
  () => filtros.buscar,
  () => {
    clearTimeout(temporizador)
    temporizador = setTimeout(cargarTareas, 300)
  }
)
watch(() => filtros.estado, cargarTareas)

function abrirCrear() {
  tareaEnEdicion.value = null
  mostrarForm.value = true
}

function abrirEditar(tarea) {
  tareaEnEdicion.value = tarea
  mostrarForm.value = true
}

async function guardar(datos) {
  error.value = ''
  try {
    if (tareaEnEdicion.value) {
      await api.put('/tareas/' + tareaEnEdicion.value.idTarea, datos)
    } else {
      await api.post('/tareas', datos)
    }
    mostrarForm.value = false
    await Promise.all([cargarTareas(), cargarNotificaciones()])
  } catch (e) {
    error.value = e.response?.data?.error || 'No se pudo guardar la tarea.'
  }
}

async function completar(tarea) {
  await api.patch('/tareas/' + tarea.idTarea + '/completar')
  cargarTareas()
}

async function eliminar(tarea) {
  if (!confirm('¿Eliminar la tarea "' + tarea.titulo + '"?')) return
  await api.delete('/tareas/' + tarea.idTarea)
  cargarTareas()
}

async function leerNotificacion(id) {
  await api.patch('/notificaciones/' + id + '/leer')
  cargarNotificaciones()
}

onMounted(() => {
  cargarTareas()
  cargarSectores()
  cargarNotificaciones()
})
</script>

<template>
  <section>
    <div class="pagina-cabecera">
      <div>
        <p class="eyebrow">Panel de trabajo</p>
        <h1>Mis tareas</h1>
      </div>
      <div class="pagina-acciones">
        <PanelNotificaciones :notificaciones="notificaciones" @leer="leerNotificacion" />
        <button class="boton boton-primario" @click="abrirCrear">+ Nueva tarea</button>
      </div>
    </div>

    <FiltrosBarra v-model:estado="filtros.estado" v-model:buscar="filtros.buscar" />
    <p v-if="error" class="mensaje-error">{{ error }}</p>

    <div v-if="tareas.length" class="tarjetas">
      <TareaCard
        v-for="t in tareas"
        :key="t.idTarea"
        :tarea="t"
        @editar="abrirEditar"
        @eliminar="eliminar"
        @completar="completar"
      />
    </div>
    <p v-else class="vacio">
      No hay tareas para este filtro. Crea una con el botón "+ Nueva tarea".
    </p>

    <TareaForm
      v-if="mostrarForm"
      :key="tareaEnEdicion ? tareaEnEdicion.idTarea : 'nueva'"
      :tarea="tareaEnEdicion"
      :sectores="sectores"
      @guardar="guardar"
      @cerrar="mostrarForm = false"
    />
  </section>
</template>
```

`EstadisticasView`: dispara las 8 consultas en paralelo (Promise.all) y pinta tarjetas, tablas y el mapa.

**Archivo: `frontend/src/views/EstadisticasView.vue`**

```vue
<script setup>
import { onMounted, ref } from 'vue'
import api from '../api'
import MapaSectores from '../components/MapaSectores.vue'

/**
 * Vista de estadisticas: consume los endpoints que responden las
 * 8 preguntas del enunciado usando funciones espaciales PostGIS.
 */
const porSector = ref([])
const masCercana = ref(null)
const sectorTop = ref(null)
const radioKm = ref(2)
const promedio = ref(null)
const clusters = ref([])
const porUsuarioSector = ref([])
const promediosUsuarios = ref([])
const sectores = ref([])
const perfil = ref(null)
const cargando = ref(true)

async function cargarSectorTop() {
  const { data } = await api.get('/estadisticas/sector-mas-completadas', {
    params: { radioKm: radioKm.value },
  })
  sectorTop.value = data[0] || null
}

function cambiarRadio(km) {
  radioKm.value = km
  cargarSectorTop()
}

function metros(v) {
  if (v == null) return '—'
  return Number(v).toLocaleString('es-CL') + ' m'
}

onMounted(async () => {
  const [ps, mc, pd, cl, pus, pdu, sec, per] = await Promise.all([
    api.get('/estadisticas/tareas-por-sector'),
    api.get('/estadisticas/tarea-mas-cercana'),
    api.get('/estadisticas/promedio-distancia'),
    api.get('/estadisticas/clusters-pendientes'),
    api.get('/estadisticas/tareas-por-usuario-sector'),
    api.get('/estadisticas/promedio-distancia-usuarios'),
    api.get('/sectores'),
    api.get('/usuarios/me'),
  ])
  porSector.value = ps.data
  masCercana.value = mc.data[0] || null
  promedio.value = pd.data[0] ? pd.data[0].promedio_distancia_metros : null
  clusters.value = cl.data
  porUsuarioSector.value = pus.data
  promediosUsuarios.value = pdu.data
  sectores.value = sec.data
  perfil.value = per.data
  await cargarSectorTop()
  cargando.value = false
})
</script>

<template>
  <section>
    <div class="pagina-cabecera">
      <div>
        <p class="eyebrow">Análisis espacial · PostGIS</p>
        <h1>Estadísticas</h1>
      </div>
    </div>

    <p v-if="cargando" class="vacio">Calculando estadísticas espaciales…</p>

    <template v-else>
      <div class="stats-grilla">
        <div class="stat-carta">
          <p class="stat-etiqueta">P2 · Tarea pendiente más cercana a ti</p>
          <template v-if="masCercana">
            <p class="stat-valor">{{ masCercana.titulo }}</p>
            <p class="stat-detalle">
              Sector {{ masCercana.sector }} · a {{ metros(masCercana.distancia_metros) }}
            </p>
          </template>
          <p v-else class="stat-detalle">No tienes tareas pendientes.</p>
        </div>

        <div class="stat-carta">
          <p class="stat-etiqueta">P3 / P7 · Sector con más completadas cerca de ti</p>
          <div class="stat-radios">
            <button
              class="filtro-boton"
              :class="{ activo: radioKm === 2 }"
              @click="cambiarRadio(2)"
            >
              Radio 2 km
            </button>
            <button
              class="filtro-boton"
              :class="{ activo: radioKm === 5 }"
              @click="cambiarRadio(5)"
            >
              Radio 5 km
            </button>
          </div>
          <template v-if="sectorTop">
            <p class="stat-valor">{{ sectorTop.sector }}</p>
            <p class="stat-detalle">
              {{ sectorTop.tareas_completadas }} tareas completadas ·
              a {{ metros(sectorTop.distancia_metros) }}
            </p>
          </template>
          <p v-else class="stat-detalle">Sin sectores con tareas completadas en ese radio.</p>
        </div>

        <div class="stat-carta">
          <p class="stat-etiqueta">P4 · Promedio de distancia de tus completadas</p>
          <p class="stat-valor">{{ metros(promedio) }}</p>
          <p class="stat-detalle">Calculado con ST_Distance sobre geografía (metros reales)</p>
        </div>
      </div>

      <div class="stats-columnas">
        <div class="panel">
          <h2>P1 · Tus tareas completadas por sector</h2>
          <table v-if="porSector.length">
            <thead>
              <tr><th>Sector</th><th>Completadas</th></tr>
            </thead>
            <tbody>
              <tr v-for="f in porSector" :key="f.sector">
                <td>{{ f.sector }}</td>
                <td>{{ f.tareas_completadas }}</td>
              </tr>
            </tbody>
          </table>
          <p v-else class="vacio">Aún no completas tareas.</p>
        </div>

        <div class="panel">
          <h2>P6 · Tareas completadas por usuario y sector</h2>
          <table>
            <thead>
              <tr><th>Usuario</th><th>Sector</th><th>Completadas</th></tr>
            </thead>
            <tbody>
              <tr v-for="(f, i) in porUsuarioSector" :key="i">
                <td>{{ f.nombre_usuario }}</td>
                <td>{{ f.sector }}</td>
                <td>{{ f.tareas_completadas }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="panel">
          <h2>P8 · Promedio de distancia por usuario</h2>
          <table>
            <thead>
              <tr><th>Usuario</th><th>Promedio</th></tr>
            </thead>
            <tbody>
              <tr v-for="f in promediosUsuarios" :key="f.nombre_usuario">
                <td>{{ f.nombre_usuario }}</td>
                <td>{{ metros(f.promedio_distancia_metros) }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="panel">
          <h2>P5 · Concentración espacial de pendientes</h2>
          <p class="ayuda">
            Agrupación K-Means (ST_ClusterKMeans) sobre los puntos de las tareas pendientes.
          </p>
          <table>
            <thead>
              <tr><th>Cluster</th><th>Pendientes</th><th>Sectores</th></tr>
            </thead>
            <tbody>
              <tr v-for="c in clusters" :key="c.cluster_id">
                <td>{{ c.cluster_id }}</td>
                <td>{{ c.tareas_pendientes }}</td>
                <td>{{ c.sectores }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <div class="panel">
        <h2>Mapa territorial</h2>
        <p class="ayuda">
          Marcadores: sectores georreferenciados · Punto naranjo: tu ubicación registrada ·
          Círculos: concentración de tareas pendientes (P5).
        </p>
        <MapaSectores :sectores="sectores" :usuario="perfil" :clusters="clusters" />
      </div>
    </template>
  </section>
</template>
```
**Checkpoints Fase 3** (con backend corriendo y `npm run dev` en `frontend/`,
app en http://localhost:5173):
1. Login con admin/admin123; en DevTools → Application → Local Storage está el
   token; en Network las peticiones llevan `Authorization`.
2. Ciclo completo de tarea: crear → editar → completar (aparece el sello) →
   eliminar. Al filtrar, cambian los query params en Network (el filtrado es SQL).
3. Registro marcando un punto en el mapa; verifica en pgAdmin con
   `SELECT ST_AsText(ubicacion) FROM usuario;`
4. Estadísticas: las 8 respuestas visibles, el botón 2 km / 5 km cambia P3/P7,
   y los círculos del mapa coinciden con la tabla de clusters (P5).

Errores comunes: mapa gris (falta el CSS de leaflet o conexión a internet para
las teselas), íconos rotos (saltarse `leafletBase.js`), CORS (usaste una
baseURL absoluta en vez del proxy), 404 al recargar `/tareas` (solo pasa en
producción; lo arregla el `try_files` de nginx en la Fase 4).

---

# FASE 4 — Despliegue completo con Docker

`backend/Dockerfile`: multi-etapa — compila con Maven en una imagen y corre en otra que solo tiene el JRE (imagen final liviana).

**Archivo: `backend/Dockerfile`**

```dockerfile
# Etapa 1: compilar con Maven
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -q
COPY src ./src
RUN mvn package -DskipTests -q

# Etapa 2: imagen liviana solo con el JAR
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

`frontend/nginx.conf`: sirve los estáticos de Vue y hace proxy de `/api` al contenedor del backend (mismo origen = sin CORS); `try_files` permite recargar cualquier ruta del router.

**Archivo: `frontend/nginx.conf`**

```nginx
# Servidor de produccion del frontend.
# - Sirve la aplicacion Vue compilada (archivos estaticos)
# - Redirige /api al contenedor del backend (mismo origen: sin CORS)
# - try_files devuelve index.html para cualquier ruta: necesario para
#   que el router de Vue (history mode) funcione al recargar la pagina
server {
    listen 80;

    location /api/ {
        proxy_pass http://backend:8080/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
}
```

**Archivo: `frontend/Dockerfile`**

```dockerfile
# Etapa 1: compilar la aplicacion Vue
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Etapa 2: servir con nginx (produccion)
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
```

**Archivo: `frontend/.dockerignore`**

```text
node_modules
dist
```

`docker-compose.yml` FINAL (reemplaza al de la Fase 1): los `.sql` montados en `initdb.d` inicializan la BD sola la primera vez; el healthcheck evita que el backend arranque antes que la BD; dentro de la red, los servicios se resuelven por nombre (`db`, `backend`).

**Archivo: `docker-compose.yml`**

```yaml
# ============================================================
# CONTROL 2 - TALLER DE BASE DE DATOS 1-2026
# Despliegue completo: base de datos + backend + frontend
#   - db:       PostgreSQL 16 + PostGIS 3.4. Al crearse por primera
#               vez ejecuta automaticamente dbCreate.sql y loadData.sql
#               (carpeta /docker-entrypoint-initdb.d)
#   - backend:  API Spring Boot (se compila dentro del contenedor)
#   - frontend: aplicacion Vue compilada, servida por nginx, que ademas
#               redirige /api al backend
# Uso: docker compose up -d --build
# App: http://localhost:8081  |  API: http://localhost:8080
# ============================================================
services:
  db:
    image: postgis/postgis:16-3.4
    restart: always
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: tareas_db
    ports:
      - "5435:5432"
    volumes:
      - ./dbCreate.sql:/docker-entrypoint-initdb.d/01-dbCreate.sql:ro
      - ./loadData.sql:/docker-entrypoint-initdb.d/02-loadData.sql:ro
      - datos_db:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d tareas_db"]
      interval: 5s
      timeout: 5s
      retries: 12

  backend:
    build: ./backend
    restart: always
    environment:
      DB_URL: jdbc:postgresql://db:5432/tareas_db
      DB_USER: postgres
      DB_PASSWORD: postgres
      CORS_ORIGIN: http://localhost:8081
      JWT_SECRET: clave-secreta-control2-tbd-usach-2026-cambiar-en-produccion-9f8e7d6c5b4a
    ports:
      - "8080:8080"
    depends_on:
      db:
        condition: service_healthy

  frontend:
    build: ./frontend
    restart: always
    ports:
      - "8081:80"
    depends_on:
      - backend

volumes:
  datos_db:
```
**Checkpoint final (el que vale nota):**

```bash
docker compose down -v          # borra todo, incluido el volumen de datos
docker compose up -d --build    # reconstruye desde cero (la 1a vez tarda minutos)
docker compose ps               # db "healthy", backend y frontend "running"
```

Aplicación: http://localhost:8081 · API: http://localhost:8080 ·
BD: localhost:5435. Después, la prueba definitiva: en un computador limpio,
clonar el repo y seguir SOLO el README. Si falta un paso, el README está
incompleto — esa es la regla crítica de evaluación.

---

# FASE 5 — Documentación, entrega y defensa

1. **README.md** en la raíz (el "corazón de la entrega"): arquitectura y
   tecnologías, manual de instalación paso a paso (opción Docker y opción
   desarrollo), documentación de la API con ejemplos JSON, tabla
   requisito → dónde está implementado, credenciales de prueba. Usa el del
   proyecto de referencia como estructura y escríbelo con tus palabras.
2. Copia también al repo: `dbCreate.sql`, `loadData.sql`, `runStatements.sql`
   (la entrega exige el script de BD) y `GUIA_DE_DEFENSA.md` para estudiar.
3. Carpeta `Presentacion/` con las diapositivas (PDF o PPTX): arquitectura,
   modelo de datos, seguridad (JWT + BCrypt + prepared statements + CSRF
   justificado), demo, y una consulta espacial explicada.
4. Ensaya la demo de 3 minutos: registro con mapa → tarea que vence en 2 días
   → notificación del trigger → completar → estadísticas cambian → psql con
   ST_DWithin.
5. Repasa la guía de defensa: por cada pregunta del final, tapa la respuesta
   y contéstala en voz alta.

---

# Apéndice — comandos de supervivencia

```bash
docker compose ps                        # estado de los servicios
docker compose logs -f backend           # logs del backend en vivo
docker compose down -v                   # reset total (incluye datos)
docker exec -it <cont> psql -U postgres -d tareas_db   # entrar a la BD
```

En psql: `\dt` lista tablas, `\d tarea` describe una tabla (índices, FKs,
triggers), `SELECT ST_AsText(ubicacion) FROM usuario;` muestra puntos legibles.

Si un checkpoint no pasa y llevas más de 30 minutos atascado: mándame el error
exacto, el paso en que vas y el archivo que acabas de agregar.
