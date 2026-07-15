-- ============================================================
-- CONTROL 2 - TALLER DE BASE DE DATOS 1-2026
-- Carga de datos de prueba (loadData.sql)
--
-- INTERPRETACION DEL MODELO: cada SECTOR es una "zona de
-- operaciones", un foco de obra fisico y georreferenciado en la
-- ciudad; las TAREAS son los quehaceres concretos que la cuadrilla
-- ejecuta en esa zona (comprar repuestos, instalar, pintar...).
--
-- Coordenadas reales de Santiago (SRID 4326).
-- IMPORTANTE: ST_MakePoint(longitud, latitud)
-- ============================================================

-- ============================================================
-- SECTORES: zonas de operaciones
-- ============================================================
INSERT INTO sector (nombre, ubicacion) VALUES
('Semaforo danado - Plaza de Armas',       ST_SetSRID(ST_MakePoint(-70.6506, -33.4372), 4326)),
('Bacheo calzada - Av. Matucana',          ST_SetSRID(ST_MakePoint(-70.6520, -33.4460), 4326)),
('Reparacion de veredas - Av. Providencia',ST_SetSRID(ST_MakePoint(-70.6109, -33.4263), 4326)),
('Poda y areas verdes - Parque Forestal',  ST_SetSRID(ST_MakePoint(-70.6344, -33.4269), 4326)),
('Alumbrado publico - Barrio Ecuador',     ST_SetSRID(ST_MakePoint(-70.7069, -33.4569), 4326)),
('Retiro de microbasural - Maipu',         ST_SetSRID(ST_MakePoint(-70.7622, -33.5093), 4326)),
('Senaletica vial - Av. Apoquindo',        ST_SetSRID(ST_MakePoint(-70.5758, -33.4172), 4326)),
('Ciclovia - Av. Vicuna Mackenna',         ST_SetSRID(ST_MakePoint(-70.5987, -33.5226), 4326));

-- ============================================================
-- USUARIOS (cuadrilla). Contrasenas BCrypt:
--   admin -> admin123 | resto -> clave123
-- ============================================================
INSERT INTO usuario (nombre_usuario, contrasena, ubicacion) VALUES
('admin',
 '$2a$10$f/4X0aEGKQZRNR9LFXu.4eECC1oeNpTCWZd2fhyd4iS2ukV6iRnOe',
 ST_SetSRID(ST_MakePoint(-70.6506, -33.4489), 4326)), -- USACH, Estacion Central
('mzapata',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.6180, -33.4287), 4326)), -- Providencia
('cfuentes',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.7530, -33.5040), 4326)), -- Maipu
('jperez',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.5980, -33.5180), 4326)), -- La Florida
('vrojas',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.5760, -33.4170), 4326)); -- Las Condes

-- ============================================================
-- TAREAS: quehaceres de cada zona de operaciones
-- Fechas alrededor de julio 2026 (algunas vencen en pocos dias
-- para probar el trigger de notificaciones).
-- ============================================================
INSERT INTO tarea (titulo, descripcion, fecha_vencimiento, completada, fecha_completada, id_usuario, id_sector) VALUES
-- Zona 1: Semaforo danado - Plaza de Armas
('Levantar informe del choque',        'Registrar danos del poste chocado',            '2026-06-20', TRUE,  '2026-06-19 10:30:00', 1, 1),
('Solicitar repuestos del controlador','Pedir controlador y cableado a bodega',        '2026-06-25', TRUE,  '2026-06-24 15:00:00', 1, 1),
('Instalar poste nuevo',               'Montaje del poste y gabinete',                 '2026-07-16', FALSE, NULL,                  1, 1),
('Programar ciclos y sincronizar',     'Sincronizar con semaforos contiguos',          '2026-07-22', FALSE, NULL,                  1, 1),
('Revisar semaforo peatonal contiguo', 'Chequeo preventivo del cruce peatonal',        '2026-07-10', TRUE,  '2026-07-09 12:20:00', 2, 1),
-- Zona 2: Bacheo calzada - Av. Matucana
('Demarcar y senalizar el bache',      'Conos y senaletica provisoria',                '2026-06-18', TRUE,  '2026-06-17 09:00:00', 1, 2),
('Fresado de la calzada danada',       'Retirar carpeta asfaltica suelta',             '2026-06-28', TRUE,  '2026-06-27 17:40:00', 1, 2),
('Aplicar mezcla asfaltica',           'Bacheo en caliente y compactado',              '2026-07-17', FALSE, NULL,                  1, 2),
('Fiscalizar cierre perimetral',       'Verificar cierre de la obra',                  '2026-06-26', TRUE,  '2026-06-25 11:10:00', 3, 2),
-- Zona 3: Reparacion de veredas - Av. Providencia
('Retirar baldosas sueltas',           'Levantar pastelones danados por raices',       '2026-06-18', TRUE,  '2026-06-17 14:00:00', 2, 3),
('Nivelar y compactar base',           'Base estabilizada para recambio',              '2026-06-30', TRUE,  '2026-06-29 16:30:00', 2, 3),
('Instalar baldosas nuevas',           'Reposicion de pastelones',                     '2026-07-16', FALSE, NULL,                  2, 3),
-- Zona 4: Poda y areas verdes - Parque Forestal
('Retirar ramas caidas del temporal',  'Despeje de senderos',                          '2026-06-22', TRUE,  '2026-06-21 10:00:00', 1, 4),
('Podar platanos orientales',          'Poda solicitada por vecinos',                  '2026-06-24', TRUE,  '2026-06-23 15:50:00', 2, 4),
('Reponer riego automatico',           'Cambio de aspersores danados',                 '2026-07-20', FALSE, NULL,                  2, 4),
('Mantener cesped sector norte',       'Corte y riego de refuerzo',                    '2026-06-21', TRUE,  '2026-06-20 16:00:00', 5, 4),
-- Zona 5: Alumbrado publico - Barrio Ecuador
('Catastrar luminarias apagadas',      'Recorrido nocturno de catastro',               '2026-06-26', TRUE,  '2026-06-25 22:30:00', 1, 5),
('Cambiar tres luminarias LED',        'Reemplazo en postes 12, 14 y 15',              '2026-07-30', FALSE, NULL,                  1, 5),
('Pintar postes intervenidos',         'Terminacion anticorrosiva',                    '2026-08-05', FALSE, NULL,                  1, 5),
('Normalizar empalme electrico',       'Empalme con cableado expuesto',                '2026-07-12', TRUE,  '2026-07-11 13:45:00', 5, 5),
-- Zona 6: Retiro de microbasural - Maipu
('Notificar a vecinos del retiro',     'Aviso puerta a puerta y carteles',             '2026-06-19', TRUE,  '2026-06-18 13:40:00', 3, 6),
('Retirar escombros con maquinaria',   'Retroexcavadora y camiones',                   '2026-07-05', TRUE,  '2026-07-04 12:00:00', 3, 6),
('Instalar senaletica de no botar',    'Carteles disuasivos y cierre',                 '2026-07-21', FALSE, NULL,                  3, 6),
('Coordinar camion tolva',             'Agenda con contratista de retiro',             '2026-07-16', FALSE, NULL,                  4, 6),
-- Zona 7: Senaletica vial - Av. Apoquindo
('Catastro de senales danadas',        'Inventario fotografico del eje',               '2026-06-17', TRUE,  '2026-06-16 11:20:00', 5, 7),
('Reponer senal ceda el paso',         'Senal retirada en cruce con El Golf',          '2026-07-25', FALSE, NULL,                  5, 7),
('Enderezar poste de no estacionar',   'Poste inclinado por choque',                   '2026-07-19', FALSE, NULL,                  4, 7),
-- Zona 8: Ciclovia - Av. Vicuna Mackenna
('Repintar demarcacion tramo sur',     'Pintura reflectante en curvas',                '2026-08-02', FALSE, NULL,                  1, 8),
('Instalar tachas reflectantes',       'Tachas en cruces conflictivos',                '2026-07-18', FALSE, NULL,                  4, 8),
('Despejar vegetacion del borde',      'Corte de arbustos que invaden la pista',       '2026-06-29', TRUE,  '2026-06-28 09:30:00', 4, 8);
