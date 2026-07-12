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
