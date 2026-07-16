
-- Consultas espaciales PostGIS (runStatements.sql)
--
-- POLITICA DE PRIVACIDAD: las preguntas formuladas "del usuario"
-- se responden con los datos DEL USUARIO AUTENTICADO (en la API el
-- id sale del token JWT; aqui se usa :id_usuario = 1 como ejemplo).
-- La pregunta 6 ("cada usuario") es un REPORTE AGREGADO global.
--
-- NOTA: el cast ::geography hace que ST_Distance devuelva METROS
-- reales sobre el elipsoide (con geometry 4326 saldrian grados).
-- ============================================================

-- ============================================================
-- P1. ¿Cuantas tareas ha hecho el usuario por sector?
-- ============================================================
SELECT s.nombre AS sector,
       COUNT(t.id_tarea) AS tareas_completadas
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
WHERE t.id_usuario = 1
  AND t.completada = TRUE
GROUP BY s.nombre
ORDER BY tareas_completadas DESC, s.nombre;

-- ============================================================
-- P2. ¿Cual es la tarea mas cercana al usuario (que este pendiente)?
-- Operador KNN <-> para ordenar por cercania (usa el indice GIST).
-- El desempate por fecha_vencimiento e id_tarea hace la respuesta
-- DETERMINISTA cuando dos tareas comparten la misma zona.
-- ============================================================
SELECT t.id_tarea,
       t.titulo,
       s.nombre AS sector,
       t.fecha_vencimiento,
       ROUND(ST_Distance(u.ubicacion::geography,
                         s.ubicacion::geography)::numeric, 1) AS distancia_metros
FROM tarea t
JOIN sector s ON s.id_sector = t.id_sector
JOIN usuario u ON u.id_usuario = 1
WHERE t.id_usuario = 1
  AND t.completada = FALSE
ORDER BY u.ubicacion <-> s.ubicacion, t.fecha_vencimiento, t.id_tarea
LIMIT 1;

-- ============================================================
-- P3. ¿Cual es el sector con mas tareas completadas en un radio de
-- 2 kilometros del usuario?
-- ST_DWithin filtra en metros y puede usar el indice espacial.
-- Desempate: a igual cantidad, gana la zona mas cercana.
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
ORDER BY tareas_completadas DESC,
         ST_Distance(u.ubicacion::geography, s.ubicacion::geography) ASC
LIMIT 1;

-- ============================================================
-- P4. ¿Cual es el promedio de distancia de las tareas completadas
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
-- P5. ¿En que sectores geograficos se concentran la mayoria de las
-- tareas pendientes? (agrupacion espacial con ST_ClusterKMeans)
--
-- Se agrupan las ZONAS DISTINTAS que tienen pendientes (una fila por
-- zona) y luego se suman las tareas de cada grupo. Dos detalles
-- importantes:
--   1) k se ajusta con LEAST(k, nro de zonas): ST_ClusterKMeans FALLA
--      si k > filas del grupo (usuarios con 1 o 2 zonas pendientes).
--   2) al agrupar zonas distintas se evita el aviso "duplicate inputs"
--      que aparece si se clusterizan puntos repetidos (una fila por tarea).
-- Devuelve ademas radio_metros: la distancia REAL del centro del grupo a su
-- zona mas lejana, o sea la extension geografica del grupo. No lleva factores
-- de ajuste: el circulo que se dibuja pasa exactamente por la zona mas lejana.
-- Un grupo de una sola zona da radio 0 (extension nula); dibujarlo con un
-- minimo visible es una decision de presentacion, no del dato.
-- ============================================================
WITH zonas AS (
    SELECT s.id_sector, s.nombre, s.ubicacion,
           COUNT(*) AS pendientes
    FROM tarea t
    JOIN sector s ON s.id_sector = t.id_sector
    WHERE t.completada = FALSE AND t.id_usuario = 1
    GROUP BY s.id_sector, s.nombre, s.ubicacion
), agrupadas AS (
    SELECT z.*,
           ST_ClusterKMeans(z.ubicacion,
                            (SELECT LEAST(3, COUNT(*))::int FROM zonas)) OVER () AS cluster_id
    FROM zonas z
), grupos AS (
    SELECT a.cluster_id,
           SUM(a.pendientes) AS tareas_pendientes,
           STRING_AGG(a.nombre, ' | ' ORDER BY a.pendientes DESC, a.nombre) AS sectores,
           ST_Centroid(ST_Collect(a.ubicacion)) AS centro
    FROM agrupadas a
    GROUP BY a.cluster_id
)
SELECT g.cluster_id,
       g.tareas_pendientes,
       g.sectores,
       ST_Y(g.centro) AS latitud_centro,
       ST_X(g.centro) AS longitud_centro,
       ROUND(MAX(ST_Distance(g.centro::geography,
                             a.ubicacion::geography))::numeric, 0)
       AS radio_metros
FROM grupos g
JOIN agrupadas a ON a.cluster_id = g.cluster_id
GROUP BY g.cluster_id, g.tareas_pendientes, g.sectores, g.centro
ORDER BY g.tareas_pendientes DESC, g.cluster_id;

-- ============================================================
-- P6. ¿Cuantas tareas ha realizado CADA usuario por sector?
-- Reporte agregado global (la unica pregunta del enunciado que no
-- esta acotada al usuario de la sesion). Expone solo CONTEOS: nunca
-- el titulo, la descripcion ni la ubicacion de tareas ajenas.
-- ============================================================
SELECT u.nombre_usuario AS usuario,
       s.nombre AS sector,
       COUNT(t.id_tarea) AS tareas_completadas
FROM tarea t
JOIN usuario u ON u.id_usuario = t.id_usuario
JOIN sector s  ON s.id_sector  = t.id_sector
WHERE t.completada = TRUE
GROUP BY u.nombre_usuario, s.nombre
ORDER BY u.nombre_usuario, tareas_completadas DESC, s.nombre;

-- ============================================================
-- P7. ¿Cual es el sector con mas tareas completadas dentro de un
-- radio de 5 km desde la ubicacion del usuario?
-- Identica a P3 cambiando el radio: por eso el endpoint recibe radioKm.
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
ORDER BY tareas_completadas DESC,
         ST_Distance(u.ubicacion::geography, s.ubicacion::geography) ASC
LIMIT 1;

-- ============================================================
-- P8. ¿Cual es el promedio de distancia entre las tareas completadas
-- y el punto registrado del usuario?
-- Es la misma metrica de P4; se muestra con el usuario 2 para dejar
-- explicito que la consulta se evalua por cada sesion.
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
-- EXTRA: ST_ClosestPoint (funcion mencionada por el enunciado).
-- Devuelve el punto de la zona mas cercano al usuario. Con zonas
-- puntuales coincide con el propio punto de la zona; la funcion se
-- deja demostrada porque el modelo admite crecer a poligonos.
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
