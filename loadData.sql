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
