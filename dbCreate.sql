
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
-- Un sector es una ZONA DE OPERACIONES: un foco de obra fisico en la
-- ciudad (ej: "Semaforo danado - Plaza de Armas"). Por eso tiene un
-- punto georreferenciado unico (SRID 4326). Las tareas son los
-- quehaceres concretos que se ejecutan en esa zona.
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
DECLARE
    v_mensaje VARCHAR(255);
BEGIN
    IF NOT NEW.completada
       AND NEW.fecha_vencimiento <= CURRENT_DATE + INTERVAL '3 days' THEN

        v_mensaje := 'La tarea "' || NEW.titulo || '" vence el ' ||
                     TO_CHAR(NEW.fecha_vencimiento, 'DD-MM-YYYY');

        -- Sin este NOT EXISTS, cada edicion de la fecha de vencimiento
        -- insertaba OTRO aviso identico: editar dos veces la misma tarea
        -- dejaba tres notificaciones repetidas en la campana. Si la fecha
        -- cambia, el mensaje cambia y si corresponde se genera un aviso nuevo.
        IF NOT EXISTS (SELECT 1 FROM notificacion n
                       WHERE n.id_tarea = NEW.id_tarea
                         AND n.mensaje  = v_mensaje) THEN
            INSERT INTO notificacion (mensaje, id_usuario, id_tarea)
            VALUES (v_mensaje, NEW.id_usuario, NEW.id_tarea);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_notificar_vencimiento ON tarea;
CREATE TRIGGER trg_notificar_vencimiento
AFTER INSERT OR UPDATE OF fecha_vencimiento ON tarea
FOR EACH ROW
EXECUTE FUNCTION fn_notificar_vencimiento();
