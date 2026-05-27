-- =====================================================================
-- CONFIGURACIÓN INICIAL Y EXTENSIONES
-- =====================================================================
-- Habilitar la extensión geoespacial obligatoria para el Control 2
CREATE EXTENSION IF NOT EXISTS postgis;

-- Limpieza de tablas previas para permitir ejecuciones limpias (Idéntico a laboratorios)
DROP TABLE IF EXISTS TAREAS CASCADE;
DROP TABLE IF EXISTS SECTORES CASCADE;
DROP TABLE IF EXISTS USUARIOS CASCADE;

-- =====================================================================
-- 1. TABLA: USUARIOS
-- =====================================================================
CREATE TABLE USUARIO (
    id_usuario   SERIAL PRIMARY KEY,
    username     VARCHAR(80) UNIQUE NOT NULL,
    password     VARCHAR(80) NOT NULL, -- Soportará el hash encriptado por seguridad
    ubicacion    GEOMETRY(Point, 4326) NOT NULL -- SRID 4326 para coordenadas WGS84
);

-- =====================================================================
-- 2. TABLA: SECTORES
-- =====================================================================
CREATE TABLE SECTORES (
    id_sector         SERIAL PRIMARY KEY,
    nombre_sector     VARCHAR(80) NOT NULL,
    ubicacion_spatial GEOMETRY(Point, 4326) NOT NULL -- Punto de referencia del sector
);

-- =====================================================================
-- 3. TABLA: TAREAS
-- =====================================================================
CREATE TABLE TAREAS (
    id_tarea          SERIAL PRIMARY KEY,
    id_usuario        INT NOT NULL,
    id_sector         INT NOT NULL,
    titulo            VARCHAR(80) NOT NULL,
    descripcion       VARCHAR(80),
    fecha_vencimiento DATE NOT NULL,
    completada        BOOLEAN DEFAULT FALSE NOT NULL,
    
    -- Restricciones de Llaves Foráneas (Garantizan Integridad Referencial)
    CONSTRAINT fk_tareas_usuarios FOREIGN KEY (id_usuario) 
        REFERENCES USUARIOS(id_usuario) ON DELETE CASCADE,
        
    CONSTRAINT fk_tareas_sectores FOREIGN KEY (id_sector) 
        REFERENCES SECTORES(id_sector) ON DELETE CASCADE
);

-- =====================================================================
-- OPTIMIZACIÓN GEOESPACIAL: ÍNDICES ESPACIALES GIST
-- =====================================================================
-- Sin estos índices, funciones como ST_Distance 
-- o ST_Within harían un escaneo secuencial completo (Sec Scan), destruyendo el rendimiento.
CREATE INDEX idx_usuarios_ubicacion ON USUARIOS USING gist(ubicacion);
CREATE INDEX idx_sectores_ubicacion ON SECTORES USING gist(ubicacion_spatial);