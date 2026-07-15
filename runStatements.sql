-- ============================================================
-- CONTROL 2 - TALLER DE BASE DE DATOS 1-2026
-- Consultas espaciales PostGIS (runStatements.sql)
--
-- POLITICA DE PRIVACIDAD: todas las preguntas se responden con
-- los datos DEL USUARIO AUTENTICADO (en la API el id sale del
-- token JWT; aqui se usa id_usuario = 1 como ejemplo). Las
-- preguntas formuladas "por cada usuario" (6 y 8) se responden
-- con la misma consulta evaluada en la sesion de cada usuario.
-- NOTA: ::geography => distancias en METROS reales.
-- ============================================================

-- ============================================================
-- ¿Cuantas tareas ha hecho el usuario por sector?
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
-- ¿Cual es la tarea mas cercana al usuario (que este pendiente)?
-- Operador KNN <-> para ordenar por cercania (usa el indice GIST)
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
-- ¿Cual es el sector con mas tareas completadas en un radio de
-- 2 kilometros del usuario? (ST_DWithin filtra en metros usando
-- el indice espacial)
-- ============================================================
SELECT s.nombre AS sector,
       COUNT(t.id_tarea) AS tareas_completadas,
       ROUND(ST_Distance(u.ubicacion::geography,
                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
JOIN usuario u ON u.id_usuario = 1
WHERE t.completada = TRUE
  AND t.id_usuario = 1
  AND ST_DWithin(u.ubicacion::geography, s.ubicacion::geography, 2000)
GROUP BY s.nombre, u.ubicacion, s.ubicacion
ORDER BY tareas_completadas DESC
LIMIT 1;

-- ============================================================
-- ¿Cual es el promedio de distancia de las tareas completadas
-- respecto a la ubicacion del usuario?
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
-- ¿En que sectores geograficos se concentran la mayoria de las
-- tareas pendientes? (agrupacion espacial con ST_ClusterKMeans)
-- Devuelve ademas un radio en metros que ENCIERRA los puntos de
-- cada grupo (para dibujar circulos correctos en el mapa).
-- ============================================================
WITH pendientes AS (
    SELECT t.id_tarea, s.nombre, s.ubicacion,
           ST_ClusterKMeans(s.ubicacion, 3) OVER () AS cluster_id
    FROM tarea t
    JOIN sector s ON s.id_sector = t.id_sector
    WHERE t.completada = FALSE AND t.id_usuario = 1
), grupos AS (
    SELECT cluster_id,
           COUNT(*) AS tareas_pendientes,
           STRING_AGG(DISTINCT nombre, ' | ') AS sectores,
           ST_Centroid(ST_Collect(ubicacion)) AS centro
    FROM pendientes
    GROUP BY cluster_id
)
SELECT g.cluster_id, g.tareas_pendientes, g.sectores,
       ST_Y(g.centro) AS latitud_centro,
       ST_X(g.centro) AS longitud_centro,
       ROUND(GREATEST(400,
             MAX(ST_Distance(g.centro::geography,
                             p.ubicacion::geography)) * 1.25)::numeric, 0)
       AS radio_metros
FROM grupos g
JOIN pendientes p USING (cluster_id)
GROUP BY g.cluster_id, g.tareas_pendientes, g.sectores, g.centro
ORDER BY g.tareas_pendientes DESC;

-- ============================================================
-- ¿Cuantas tareas ha realizado cada usuario por sector?
-- Bajo la politica de privacidad, cada usuario consulta SOLO lo
-- suyo: es la primera consulta de este archivo, evaluada con el
-- id de la sesion de cada usuario (aqui, otro ejemplo con id 2).
-- ============================================================
SELECT s.nombre AS sector,
       COUNT(t.id_tarea) AS tareas_completadas
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
WHERE t.id_usuario = 2
  AND t.completada = TRUE
GROUP BY s.nombre
ORDER BY tareas_completadas DESC;

-- ============================================================
-- ¿Cual es el sector con mas tareas completadas dentro de un
-- radio de 5 km desde la ubicacion del usuario?
-- ============================================================
SELECT s.nombre AS sector,
       COUNT(t.id_tarea) AS tareas_completadas,
       ROUND(ST_Distance(u.ubicacion::geography,
                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
JOIN usuario u ON u.id_usuario = 1
WHERE t.completada = TRUE
  AND t.id_usuario = 1
  AND ST_DWithin(u.ubicacion::geography, s.ubicacion::geography, 5000)
GROUP BY s.nombre, u.ubicacion, s.ubicacion
ORDER BY tareas_completadas DESC
LIMIT 1;

-- ============================================================
-- ¿Cual es el promedio de distancia entre las tareas completadas
-- y el punto registrado del usuario?
-- Misma consulta del promedio, evaluada por cada sesion (privada);
-- ejemplo con el usuario 2.
-- ============================================================
SELECT ROUND(AVG(ST_Distance(u.ubicacion::geography,
                             s.ubicacion::geography))::numeric, 1)
       AS promedio_distancia_metros
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
JOIN usuario u ON u.id_usuario = 2
WHERE t.id_usuario = 2
  AND t.completada = TRUE;

-- ============================================================
-- EXTRA: punto mas cercano con ST_ClosestPoint (funcion pedida
-- por el enunciado) entre las zonas con pendientes del usuario 1
-- ============================================================
SELECT s.nombre AS sector,
       ST_AsText(ST_ClosestPoint(s.ubicacion, u.ubicacion)) AS punto_mas_cercano,
       ROUND(ST_Distance(u.ubicacion::geography,
                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
FROM sector s
JOIN usuario u ON u.id_usuario = 1
WHERE EXISTS (SELECT 1 FROM tarea t
              WHERE t.id_sector = s.id_sector
                AND t.completada = FALSE
                AND t.id_usuario = 1)
ORDER BY u.ubicacion <-> s.ubicacion
LIMIT 1;
