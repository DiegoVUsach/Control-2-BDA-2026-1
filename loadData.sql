
-- Carga de datos de prueba (loadData.sql)
--
-- INTERPRETACION DEL MODELO: cada SECTOR es una "zona de
-- operaciones", un foco de obra fisico y georreferenciado en la
-- ciudad; las TAREAS son los quehaceres concretos que la cuadrilla
-- ejecuta en esa zona (comprar repuestos, instalar, pintar...).
--
-- Coordenadas reales de Santiago (SRID 4326).
-- IMPORTANTE: ST_MakePoint(longitud, latitud)
--
-- LAS FECHAS SON RELATIVAS A CURRENT_DATE: el set de datos nunca
-- "envejece", las notificaciones de vencimiento siempre se disparan
-- y las consultas dan el mismo resultado el dia de la defensa.
-- ============================================================

-- ============================================================
-- SECTORES: zonas de operaciones repartidas por Santiago
-- ============================================================
INSERT INTO sector (nombre, ubicacion) VALUES
('Semaforo danado - Plaza de Armas',              ST_SetSRID(ST_MakePoint(-70.6506, -33.4372), 4326)),  -- zona 1
('Bacheo calzada - Av. Matucana',                 ST_SetSRID(ST_MakePoint(-70.652, -33.446), 4326)),  -- zona 2
('Reparacion de veredas - Av. Providencia',       ST_SetSRID(ST_MakePoint(-70.6109, -33.4263), 4326)),  -- zona 3
('Poda y areas verdes - Parque Forestal',         ST_SetSRID(ST_MakePoint(-70.6344, -33.4269), 4326)),  -- zona 4
('Alumbrado publico - Barrio Ecuador',            ST_SetSRID(ST_MakePoint(-70.7069, -33.4569), 4326)),  -- zona 5
('Retiro de microbasural - Maipu',                ST_SetSRID(ST_MakePoint(-70.7622, -33.5093), 4326)),  -- zona 6
('Senaletica vial - Av. Apoquindo',               ST_SetSRID(ST_MakePoint(-70.5758, -33.4172), 4326)),  -- zona 7
('Ciclovia - Av. Vicuna Mackenna',                ST_SetSRID(ST_MakePoint(-70.5987, -33.5226), 4326)),  -- zona 8
('Luminarias quemadas - Barrio Republica',        ST_SetSRID(ST_MakePoint(-70.662, -33.446), 4326)),  -- zona 9
('Colector colapsado - Estacion Central',         ST_SetSRID(ST_MakePoint(-70.679, -33.452), 4326)),  -- zona 10
('Pavimento agrietado - Plaza Nunoa',             ST_SetSRID(ST_MakePoint(-70.597, -33.456), 4326)),  -- zona 11
('Semaforo intermitente - Grecia con Marathon',   ST_SetSRID(ST_MakePoint(-70.589, -33.462), 4326)),  -- zona 12
('Retiro de escombros - Puente Alto centro',      ST_SetSRID(ST_MakePoint(-70.575, -33.6), 4326)),  -- zona 13
('Alcantarillado - Quilicura norte',              ST_SetSRID(ST_MakePoint(-70.729, -33.367), 4326)),  -- zona 14
('Areas verdes - Cerro Santa Lucia',              ST_SetSRID(ST_MakePoint(-70.644, -33.44), 4326)),  -- zona 15
('Reparacion de calzada - Cerrillos',             ST_SetSRID(ST_MakePoint(-70.715, -33.5), 4326)),  -- zona 16
('Bacheo - Av. Departamental',                    ST_SetSRID(ST_MakePoint(-70.607, -33.49), 4326)),  -- zona 17
('Luminarias - La Florida sur',                   ST_SetSRID(ST_MakePoint(-70.582, -33.56), 4326)),  -- zona 18
('Socavon - Av. Dorsal, Renca',                   ST_SetSRID(ST_MakePoint(-70.715, -33.403), 4326));  -- zona 19

-- ============================================================
-- USUARIOS (cuadrillas municipales). Contrasenas BCrypt:
--   admin -> admin123 | resto -> clave123
-- ============================================================
INSERT INTO usuario (nombre_usuario, contrasena, ubicacion) VALUES
('admin',
 '$2a$10$f/4X0aEGKQZRNR9LFXu.4eECC1oeNpTCWZd2fhyd4iS2ukV6iRnOe',
 ST_SetSRID(ST_MakePoint(-70.6506, -33.4489), 4326)),  -- id 1 - USACH, Estacion Central
('mzapata',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.618, -33.4287), 4326)),  -- id 2 - Providencia
('cfuentes',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.753, -33.504), 4326)),  -- id 3 - Maipu
('jperez',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.598, -33.518), 4326)),  -- id 4 - La Florida
('vrojas',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.576, -33.417), 4326)),  -- id 5 - Las Condes
('rmorales',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.599, -33.457), 4326)),  -- id 6 - Nunoa
('avaldes',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.579, -33.596), 4326)),  -- id 7 - Puente Alto
('ktapia',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.728, -33.37), 4326)),  -- id 8 - Quilicura
('pgomez',
 '$2a$10$KlV8iaiIg.F9slLDCg7BhegBvbXKWWJFgwIvmoAgij6MhKp6uOj1a',
 ST_SetSRID(ST_MakePoint(-70.665, -33.47), 4326));  -- id 9 - Pedro Aguirre Cerda

-- ============================================================
-- TAREAS
-- ============================================================
INSERT INTO tarea (titulo, descripcion, fecha_vencimiento, completada, fecha_completada, id_usuario, id_sector) VALUES

-- ------------------------------------------------------------
-- admin (id_usuario = 1)
-- ------------------------------------------------------------
--   zona 1: Semaforo danado - Plaza de Armas  -> 2 completadas, 1 pendientes
('Levantar informe del choque', 'Registrar danos del poste chocado y fotografiar', CURRENT_DATE - 3, TRUE,  NOW() - INTERVAL '4 days', 1, 1),
('Solicitar repuestos del controlador', 'Pedir controlador y cableado a bodega central', CURRENT_DATE - 5, TRUE,  NOW() - INTERVAL '6 days', 1, 1),
('Retirar poste siniestrado', 'Corte y retiro del poste doblado', CURRENT_DATE + 2, FALSE, NULL, 1, 1),
--   zona 2: Bacheo calzada - Av. Matucana  -> 3 completadas, 0 pendientes
('Demarcar y senalizar el bache', 'Conos y senaletica provisoria en la calzada', CURRENT_DATE - 8, TRUE,  NOW() - INTERVAL '9 days', 1, 2),
('Fresado de la calzada danada', 'Retirar carpeta asfaltica suelta', CURRENT_DATE - 12, TRUE,  NOW() - INTERVAL '13 days', 1, 2),
('Aplicar mezcla asfaltica', 'Bacheo en caliente y compactado', CURRENT_DATE - 19, TRUE,  NOW() - INTERVAL '20 days', 1, 2),
--   zona 3: Reparacion de veredas - Av. Providencia  -> 6 completadas, 2 pendientes
('Retirar baldosas sueltas', 'Levantar pastelones danados por raices', CURRENT_DATE - 26, TRUE,  NOW() - INTERVAL '27 days', 1, 3),
('Nivelar y compactar base', 'Base estabilizada para el recambio', CURRENT_DATE - 33, TRUE,  NOW() - INTERVAL '34 days', 1, 3),
('Instalar baldosas nuevas', 'Reposicion de pastelones', CURRENT_DATE - 40, TRUE,  NOW() - INTERVAL '41 days', 1, 3),
('Podar raices invasoras', 'Poda de raices que levantan la vereda', CURRENT_DATE - 47, TRUE,  NOW() - INTERVAL '48 days', 1, 3),
('Reponer solerilla quebrada', 'Cambio de solerilla en el tramo', CURRENT_DATE - 54, TRUE,  NOW() - INTERVAL '55 days', 1, 3),
('Habilitar rampa accesible', 'Rampa de acceso universal en la esquina', CURRENT_DATE - 61, TRUE,  NOW() - INTERVAL '62 days', 1, 3),
('Limpiar y entregar el tramo', 'Barrido final y entrega a la comunidad', CURRENT_DATE + 3, FALSE, NULL, 1, 3),
('Fotografiar avance semanal', 'Registro fotografico para el informe', CURRENT_DATE + 12, FALSE, NULL, 1, 3),
--   zona 4: Poda y areas verdes - Parque Forestal  -> 2 completadas, 2 pendientes
('Retirar ramas caidas del temporal', 'Despeje de senderos del parque', CURRENT_DATE - 68, TRUE,  NOW() - INTERVAL '69 days', 1, 4),
('Podar platanos orientales', 'Poda solicitada por vecinos', CURRENT_DATE - 75, TRUE,  NOW() - INTERVAL '76 days', 1, 4),
('Reponer riego automatico', 'Cambio de aspersores danados', CURRENT_DATE + 19, FALSE, NULL, 1, 4),
('Mantener cesped sector norte', 'Corte y riego de refuerzo', CURRENT_DATE + 27, FALSE, NULL, 1, 4),
--   zona 5: Alumbrado publico - Barrio Ecuador  -> 8 completadas, 3 pendientes
('Catastrar luminarias apagadas', 'Recorrido nocturno de catastro', CURRENT_DATE - 82, TRUE,  NOW() - INTERVAL '83 days', 1, 5),
('Cambiar tres luminarias LED', 'Reemplazo en postes 12, 14 y 15', CURRENT_DATE - 89, TRUE,  NOW() - INTERVAL '90 days', 1, 5),
('Pintar postes intervenidos', 'Terminacion anticorrosiva', CURRENT_DATE - 96, TRUE,  NOW() - INTERVAL '97 days', 1, 5),
('Normalizar empalme electrico', 'Empalme con cableado expuesto', CURRENT_DATE - 103, TRUE,  NOW() - INTERVAL '104 days', 1, 5),
('Reponer tapa de camara electrica', 'Tapa robada en la esquina', CURRENT_DATE - 110, TRUE,  NOW() - INTERVAL '111 days', 1, 5),
('Medir consumo del tramo', 'Medicion para informe de eficiencia', CURRENT_DATE - 117, TRUE,  NOW() - INTERVAL '118 days', 1, 5),
('Reemplazar fotocelda', 'Fotocelda que no conmuta de noche', CURRENT_DATE - 124, TRUE,  NOW() - INTERVAL '125 days', 1, 5),
('Recambio de luminaria esquina', 'Luminaria quemada frente al colegio', CURRENT_DATE - 131, TRUE,  NOW() - INTERVAL '132 days', 1, 5),
('Revision nocturna de encendido', 'Verificar encendido del tramo completo', CURRENT_DATE + 35, FALSE, NULL, 1, 5),
('Retirar cableado en desuso', 'Retiro de cables colgantes', CURRENT_DATE + 44, FALSE, NULL, 1, 5),
('Actualizar catastro municipal', 'Cargar cambios al sistema municipal', CURRENT_DATE + 53, FALSE, NULL, 1, 5),
--   zona 6: Retiro de microbasural - Maipu  -> 1 completadas, 1 pendientes
('Notificar a vecinos del retiro', 'Aviso puerta a puerta y carteles', CURRENT_DATE - 138, TRUE,  NOW() - INTERVAL '139 days', 1, 6),
('Retirar escombros con maquinaria', 'Retroexcavadora y camiones tolva', CURRENT_DATE + 61, FALSE, NULL, 1, 6),
--   zona 8: Ciclovia - Av. Vicuna Mackenna  -> 0 completadas, 2 pendientes
('Repintar demarcacion tramo sur', 'Pintura reflectante en curvas', CURRENT_DATE + 70, FALSE, NULL, 1, 8),
('Instalar tachas reflectantes', 'Tachas en cruces conflictivos', CURRENT_DATE + 79, FALSE, NULL, 1, 8),
--   zona 9: Luminarias quemadas - Barrio Republica  -> 1 completadas, 0 pendientes
('Catastrar luminarias del pasaje', 'Recorrido nocturno del barrio', CURRENT_DATE - 145, TRUE,  NOW() - INTERVAL '146 days', 1, 9),
--   zona 15: Areas verdes - Cerro Santa Lucia  -> 2 completadas, 0 pendientes
('Retirar ramas del cerro', 'Despeje de senderos del cerro', CURRENT_DATE - 152, TRUE,  NOW() - INTERVAL '153 days', 1, 15),
('Reparar baranda del mirador', 'Cambio de baranda oxidada', CURRENT_DATE - 159, TRUE,  NOW() - INTERVAL '160 days', 1, 15),

-- ------------------------------------------------------------
-- mzapata (id_usuario = 2)
-- ------------------------------------------------------------
--   zona 1: Semaforo danado - Plaza de Armas  -> 5 completadas, 0 pendientes
('Levantar informe del choque', 'Registrar danos del poste chocado y fotografiar', CURRENT_DATE - 3, TRUE,  NOW() - INTERVAL '4 days', 2, 1),
('Solicitar repuestos del controlador', 'Pedir controlador y cableado a bodega central', CURRENT_DATE - 5, TRUE,  NOW() - INTERVAL '6 days', 2, 1),
('Retirar poste siniestrado', 'Corte y retiro del poste doblado', CURRENT_DATE - 8, TRUE,  NOW() - INTERVAL '9 days', 2, 1),
('Instalar poste nuevo', 'Montaje del poste y gabinete de control', CURRENT_DATE - 12, TRUE,  NOW() - INTERVAL '13 days', 2, 1),
('Programar ciclos y sincronizar', 'Sincronizar con los semaforos contiguos del eje', CURRENT_DATE - 19, TRUE,  NOW() - INTERVAL '20 days', 2, 1),
--   zona 3: Reparacion de veredas - Av. Providencia  -> 2 completadas, 1 pendientes
('Retirar baldosas sueltas', 'Levantar pastelones danados por raices', CURRENT_DATE - 26, TRUE,  NOW() - INTERVAL '27 days', 2, 3),
('Nivelar y compactar base', 'Base estabilizada para el recambio', CURRENT_DATE - 33, TRUE,  NOW() - INTERVAL '34 days', 2, 3),
('Instalar baldosas nuevas', 'Reposicion de pastelones', CURRENT_DATE + 2, FALSE, NULL, 2, 3),
--   zona 4: Poda y areas verdes - Parque Forestal  -> 3 completadas, 3 pendientes
('Retirar ramas caidas del temporal', 'Despeje de senderos del parque', CURRENT_DATE - 40, TRUE,  NOW() - INTERVAL '41 days', 2, 4),
('Podar platanos orientales', 'Poda solicitada por vecinos', CURRENT_DATE - 47, TRUE,  NOW() - INTERVAL '48 days', 2, 4),
('Reponer riego automatico', 'Cambio de aspersores danados', CURRENT_DATE - 54, TRUE,  NOW() - INTERVAL '55 days', 2, 4),
('Mantener cesped sector norte', 'Corte y riego de refuerzo', CURRENT_DATE + 3, FALSE, NULL, 2, 4),
('Reparar escano vandalizado', 'Cambio de tablones y pintura', CURRENT_DATE + 12, FALSE, NULL, 2, 4),
('Retirar arbol seco', 'Corte y extraccion de tocon', CURRENT_DATE + 19, FALSE, NULL, 2, 4),
--   zona 5: Alumbrado publico - Barrio Ecuador  -> 6 completadas, 2 pendientes
('Catastrar luminarias apagadas', 'Recorrido nocturno de catastro', CURRENT_DATE - 61, TRUE,  NOW() - INTERVAL '62 days', 2, 5),
('Cambiar tres luminarias LED', 'Reemplazo en postes 12, 14 y 15', CURRENT_DATE - 68, TRUE,  NOW() - INTERVAL '69 days', 2, 5),
('Pintar postes intervenidos', 'Terminacion anticorrosiva', CURRENT_DATE - 75, TRUE,  NOW() - INTERVAL '76 days', 2, 5),
('Normalizar empalme electrico', 'Empalme con cableado expuesto', CURRENT_DATE - 82, TRUE,  NOW() - INTERVAL '83 days', 2, 5),
('Reponer tapa de camara electrica', 'Tapa robada en la esquina', CURRENT_DATE - 89, TRUE,  NOW() - INTERVAL '90 days', 2, 5),
('Medir consumo del tramo', 'Medicion para informe de eficiencia', CURRENT_DATE - 96, TRUE,  NOW() - INTERVAL '97 days', 2, 5),
('Reemplazar fotocelda', 'Fotocelda que no conmuta de noche', CURRENT_DATE + 27, FALSE, NULL, 2, 5),
('Recambio de luminaria esquina', 'Luminaria quemada frente al colegio', CURRENT_DATE + 35, FALSE, NULL, 2, 5),
--   zona 6: Retiro de microbasural - Maipu  -> 0 completadas, 1 pendientes
('Notificar a vecinos del retiro', 'Aviso puerta a puerta y carteles', CURRENT_DATE + 44, FALSE, NULL, 2, 6),
--   zona 7: Senaletica vial - Av. Apoquindo  -> 1 completadas, 0 pendientes
('Catastro de senales danadas', 'Inventario fotografico del eje', CURRENT_DATE - 103, TRUE,  NOW() - INTERVAL '104 days', 2, 7),
--   zona 11: Pavimento agrietado - Plaza Nunoa  -> 2 completadas, 2 pendientes
('Catastrar grietas del pavimento', 'Medicion y registro de grietas', CURRENT_DATE - 110, TRUE,  NOW() - INTERVAL '111 days', 2, 11),
('Sellar grietas con asfalto', 'Sellado de fisuras del paseo', CURRENT_DATE - 117, TRUE,  NOW() - INTERVAL '118 days', 2, 11),
('Reponer baldosa de la plaza', 'Cambio de baldosas quebradas', CURRENT_DATE + 53, FALSE, NULL, 2, 11),
('Reparar juego infantil', 'Cambio de piezas del juego', CURRENT_DATE + 61, FALSE, NULL, 2, 11),
--   zona 15: Areas verdes - Cerro Santa Lucia  -> 1 completadas, 0 pendientes
('Retirar ramas del cerro', 'Despeje de senderos del cerro', CURRENT_DATE - 124, TRUE,  NOW() - INTERVAL '125 days', 2, 15),

-- ------------------------------------------------------------
-- cfuentes (id_usuario = 3)
-- ------------------------------------------------------------
--   zona 2: Bacheo calzada - Av. Matucana  -> 1 completadas, 0 pendientes
('Demarcar y senalizar el bache', 'Conos y senaletica provisoria en la calzada', CURRENT_DATE - 3, TRUE,  NOW() - INTERVAL '4 days', 3, 2),
--   zona 5: Alumbrado publico - Barrio Ecuador  -> 3 completadas, 2 pendientes
('Catastrar luminarias apagadas', 'Recorrido nocturno de catastro', CURRENT_DATE - 5, TRUE,  NOW() - INTERVAL '6 days', 3, 5),
('Cambiar tres luminarias LED', 'Reemplazo en postes 12, 14 y 15', CURRENT_DATE - 8, TRUE,  NOW() - INTERVAL '9 days', 3, 5),
('Pintar postes intervenidos', 'Terminacion anticorrosiva', CURRENT_DATE - 12, TRUE,  NOW() - INTERVAL '13 days', 3, 5),
('Normalizar empalme electrico', 'Empalme con cableado expuesto', CURRENT_DATE + 2, FALSE, NULL, 3, 5),
('Reponer tapa de camara electrica', 'Tapa robada en la esquina', CURRENT_DATE + 3, FALSE, NULL, 3, 5),
--   zona 6: Retiro de microbasural - Maipu  -> 2 completadas, 1 pendientes
('Notificar a vecinos del retiro', 'Aviso puerta a puerta y carteles', CURRENT_DATE - 19, TRUE,  NOW() - INTERVAL '20 days', 3, 6),
('Retirar escombros con maquinaria', 'Retroexcavadora y camiones tolva', CURRENT_DATE - 26, TRUE,  NOW() - INTERVAL '27 days', 3, 6),
('Instalar senaletica de no botar', 'Carteles disuasivos y cierre', CURRENT_DATE + 12, FALSE, NULL, 3, 6),
--   zona 10: Colector colapsado - Estacion Central  -> 1 completadas, 1 pendientes
('Inspeccionar el colector con camara', 'Video inspeccion del tramo', CURRENT_DATE - 33, TRUE,  NOW() - INTERVAL '34 days', 3, 10),
('Aislar y desviar aguas', 'Bypass provisorio del colector', CURRENT_DATE + 19, FALSE, NULL, 3, 10),
--   zona 16: Reparacion de calzada - Cerrillos  -> 5 completadas, 2 pendientes
('Demarcar la calzada danada', 'Conos y desvio del transito', CURRENT_DATE - 40, TRUE,  NOW() - INTERVAL '41 days', 3, 16),
('Fresar el tramo agrietado', 'Retiro de carpeta suelta', CURRENT_DATE - 47, TRUE,  NOW() - INTERVAL '48 days', 3, 16),
('Reponer carpeta asfaltica', 'Asfalto en caliente y compactado', CURRENT_DATE - 54, TRUE,  NOW() - INTERVAL '55 days', 3, 16),
('Reponer solera quebrada', 'Cambio de solera del tramo', CURRENT_DATE - 61, TRUE,  NOW() - INTERVAL '62 days', 3, 16),
('Sellar juntas del parche', 'Sello perimetral del parche', CURRENT_DATE - 68, TRUE,  NOW() - INTERVAL '69 days', 3, 16),
('Recepcionar el tramo', 'Acta de recepcion del tramo', CURRENT_DATE + 27, FALSE, NULL, 3, 16),
('Demarcar la calzada danada', 'Conos y desvio del transito', CURRENT_DATE + 35, FALSE, NULL, 3, 16),

-- ------------------------------------------------------------
-- jperez (id_usuario = 4)
-- ------------------------------------------------------------
--   zona 8: Ciclovia - Av. Vicuna Mackenna  -> 3 completadas, 2 pendientes
('Repintar demarcacion tramo sur', 'Pintura reflectante en curvas', CURRENT_DATE - 3, TRUE,  NOW() - INTERVAL '4 days', 4, 8),
('Instalar tachas reflectantes', 'Tachas en cruces conflictivos', CURRENT_DATE - 5, TRUE,  NOW() - INTERVAL '6 days', 4, 8),
('Despejar vegetacion del borde', 'Corte de arbustos que invaden la pista', CURRENT_DATE - 8, TRUE,  NOW() - INTERVAL '9 days', 4, 8),
('Reparar segregador quebrado', 'Cambio de segregadores danados', CURRENT_DATE + 2, FALSE, NULL, 4, 8),
('Nivelar tapa en la ciclovia', 'Tapa hundida en el kilometro 3', CURRENT_DATE + 3, FALSE, NULL, 4, 8),
--   zona 11: Pavimento agrietado - Plaza Nunoa  -> 2 completadas, 1 pendientes
('Catastrar grietas del pavimento', 'Medicion y registro de grietas', CURRENT_DATE - 12, TRUE,  NOW() - INTERVAL '13 days', 4, 11),
('Sellar grietas con asfalto', 'Sellado de fisuras del paseo', CURRENT_DATE - 19, TRUE,  NOW() - INTERVAL '20 days', 4, 11),
('Reponer baldosa de la plaza', 'Cambio de baldosas quebradas', CURRENT_DATE + 12, FALSE, NULL, 4, 11),
--   zona 12: Semaforo intermitente - Grecia con Marathon  -> 1 completadas, 2 pendientes
('Diagnosticar el semaforo intermitente', 'Revision del controlador', CURRENT_DATE - 26, TRUE,  NOW() - INTERVAL '27 days', 4, 12),
('Cambiar tarjeta del controlador', 'Recambio de tarjeta danada', CURRENT_DATE + 19, FALSE, NULL, 4, 12),
('Sincronizar con el eje Grecia', 'Programacion de ciclos', CURRENT_DATE + 27, FALSE, NULL, 4, 12),
--   zona 13: Retiro de escombros - Puente Alto centro  -> 0 completadas, 1 pendientes
('Cercar el foco de escombros', 'Cierre del sitio con malla', CURRENT_DATE + 35, FALSE, NULL, 4, 13),
--   zona 17: Bacheo - Av. Departamental  -> 4 completadas, 2 pendientes
('Catastrar baches del eje', 'Inventario de baches del tramo', CURRENT_DATE - 33, TRUE,  NOW() - INTERVAL '34 days', 4, 17),
('Senalizar el desvio', 'Desvio de transito por la obra', CURRENT_DATE - 40, TRUE,  NOW() - INTERVAL '41 days', 4, 17),
('Aplicar bacheo en caliente', 'Reparacion de la calzada', CURRENT_DATE - 47, TRUE,  NOW() - INTERVAL '48 days', 4, 17),
('Reponer tapa de sumidero', 'Tapa faltante en la esquina', CURRENT_DATE - 54, TRUE,  NOW() - INTERVAL '55 days', 4, 17),
('Repintar linea segregadora', 'Demarcacion del eje', CURRENT_DATE + 44, FALSE, NULL, 4, 17),
('Limpiar sumideros del tramo', 'Retiro de hojas y basura', CURRENT_DATE + 53, FALSE, NULL, 4, 17),

-- ------------------------------------------------------------
-- vrojas (id_usuario = 5)
-- ------------------------------------------------------------
--   zona 3: Reparacion de veredas - Av. Providencia  -> 4 completadas, 2 pendientes
('Retirar baldosas sueltas', 'Levantar pastelones danados por raices', CURRENT_DATE - 3, TRUE,  NOW() - INTERVAL '4 days', 5, 3),
('Nivelar y compactar base', 'Base estabilizada para el recambio', CURRENT_DATE - 5, TRUE,  NOW() - INTERVAL '6 days', 5, 3),
('Instalar baldosas nuevas', 'Reposicion de pastelones', CURRENT_DATE - 8, TRUE,  NOW() - INTERVAL '9 days', 5, 3),
('Podar raices invasoras', 'Poda de raices que levantan la vereda', CURRENT_DATE - 12, TRUE,  NOW() - INTERVAL '13 days', 5, 3),
('Reponer solerilla quebrada', 'Cambio de solerilla en el tramo', CURRENT_DATE + 2, FALSE, NULL, 5, 3),
('Habilitar rampa accesible', 'Rampa de acceso universal en la esquina', CURRENT_DATE + 3, FALSE, NULL, 5, 3),
--   zona 4: Poda y areas verdes - Parque Forestal  -> 1 completadas, 0 pendientes
('Retirar ramas caidas del temporal', 'Despeje de senderos del parque', CURRENT_DATE - 19, TRUE,  NOW() - INTERVAL '20 days', 5, 4),
--   zona 5: Alumbrado publico - Barrio Ecuador  -> 3 completadas, 0 pendientes
('Catastrar luminarias apagadas', 'Recorrido nocturno de catastro', CURRENT_DATE - 26, TRUE,  NOW() - INTERVAL '27 days', 5, 5),
('Cambiar tres luminarias LED', 'Reemplazo en postes 12, 14 y 15', CURRENT_DATE - 33, TRUE,  NOW() - INTERVAL '34 days', 5, 5),
('Pintar postes intervenidos', 'Terminacion anticorrosiva', CURRENT_DATE - 40, TRUE,  NOW() - INTERVAL '41 days', 5, 5),
--   zona 7: Senaletica vial - Av. Apoquindo  -> 2 completadas, 1 pendientes
('Catastro de senales danadas', 'Inventario fotografico del eje', CURRENT_DATE - 47, TRUE,  NOW() - INTERVAL '48 days', 5, 7),
('Reponer senal ceda el paso', 'Senal retirada en cruce con El Golf', CURRENT_DATE - 54, TRUE,  NOW() - INTERVAL '55 days', 5, 7),
('Enderezar poste de no estacionar', 'Poste inclinado por choque', CURRENT_DATE + 12, FALSE, NULL, 5, 7),
--   zona 11: Pavimento agrietado - Plaza Nunoa  -> 1 completadas, 1 pendientes
('Catastrar grietas del pavimento', 'Medicion y registro de grietas', CURRENT_DATE - 61, TRUE,  NOW() - INTERVAL '62 days', 5, 11),
('Sellar grietas con asfalto', 'Sellado de fisuras del paseo', CURRENT_DATE + 19, FALSE, NULL, 5, 11),
--   zona 12: Semaforo intermitente - Grecia con Marathon  -> 1 completadas, 2 pendientes
('Diagnosticar el semaforo intermitente', 'Revision del controlador', CURRENT_DATE - 68, TRUE,  NOW() - INTERVAL '69 days', 5, 12),
('Cambiar tarjeta del controlador', 'Recambio de tarjeta danada', CURRENT_DATE + 27, FALSE, NULL, 5, 12),
('Sincronizar con el eje Grecia', 'Programacion de ciclos', CURRENT_DATE + 35, FALSE, NULL, 5, 12),

-- ------------------------------------------------------------
-- rmorales (id_usuario = 6)
-- ------------------------------------------------------------
--   zona 3: Reparacion de veredas - Av. Providencia  -> 1 completadas, 0 pendientes
('Retirar baldosas sueltas', 'Levantar pastelones danados por raices', CURRENT_DATE - 3, TRUE,  NOW() - INTERVAL '4 days', 6, 3),
--   zona 4: Poda y areas verdes - Parque Forestal  -> 5 completadas, 0 pendientes
('Retirar ramas caidas del temporal', 'Despeje de senderos del parque', CURRENT_DATE - 5, TRUE,  NOW() - INTERVAL '6 days', 6, 4),
('Podar platanos orientales', 'Poda solicitada por vecinos', CURRENT_DATE - 8, TRUE,  NOW() - INTERVAL '9 days', 6, 4),
('Reponer riego automatico', 'Cambio de aspersores danados', CURRENT_DATE - 12, TRUE,  NOW() - INTERVAL '13 days', 6, 4),
('Mantener cesped sector norte', 'Corte y riego de refuerzo', CURRENT_DATE - 19, TRUE,  NOW() - INTERVAL '20 days', 6, 4),
('Reparar escano vandalizado', 'Cambio de tablones y pintura', CURRENT_DATE - 26, TRUE,  NOW() - INTERVAL '27 days', 6, 4),
--   zona 6: Retiro de microbasural - Maipu  -> 1 completadas, 1 pendientes
('Notificar a vecinos del retiro', 'Aviso puerta a puerta y carteles', CURRENT_DATE - 33, TRUE,  NOW() - INTERVAL '34 days', 6, 6),
('Retirar escombros con maquinaria', 'Retroexcavadora y camiones tolva', CURRENT_DATE + 2, FALSE, NULL, 6, 6),
--   zona 7: Senaletica vial - Av. Apoquindo  -> 1 completadas, 1 pendientes
('Catastro de senales danadas', 'Inventario fotografico del eje', CURRENT_DATE - 40, TRUE,  NOW() - INTERVAL '41 days', 6, 7),
('Reponer senal ceda el paso', 'Senal retirada en cruce con El Golf', CURRENT_DATE + 3, FALSE, NULL, 6, 7),
--   zona 8: Ciclovia - Av. Vicuna Mackenna  -> 2 completadas, 2 pendientes
('Repintar demarcacion tramo sur', 'Pintura reflectante en curvas', CURRENT_DATE - 47, TRUE,  NOW() - INTERVAL '48 days', 6, 8),
('Instalar tachas reflectantes', 'Tachas en cruces conflictivos', CURRENT_DATE - 54, TRUE,  NOW() - INTERVAL '55 days', 6, 8),
('Despejar vegetacion del borde', 'Corte de arbustos que invaden la pista', CURRENT_DATE + 12, FALSE, NULL, 6, 8),
('Reparar segregador quebrado', 'Cambio de segregadores danados', CURRENT_DATE + 19, FALSE, NULL, 6, 8),
--   zona 11: Pavimento agrietado - Plaza Nunoa  -> 2 completadas, 1 pendientes
('Catastrar grietas del pavimento', 'Medicion y registro de grietas', CURRENT_DATE - 61, TRUE,  NOW() - INTERVAL '62 days', 6, 11),
('Sellar grietas con asfalto', 'Sellado de fisuras del paseo', CURRENT_DATE - 68, TRUE,  NOW() - INTERVAL '69 days', 6, 11),
('Reponer baldosa de la plaza', 'Cambio de baldosas quebradas', CURRENT_DATE + 27, FALSE, NULL, 6, 11),
--   zona 12: Semaforo intermitente - Grecia con Marathon  -> 4 completadas, 2 pendientes
('Diagnosticar el semaforo intermitente', 'Revision del controlador', CURRENT_DATE - 75, TRUE,  NOW() - INTERVAL '76 days', 6, 12),
('Cambiar tarjeta del controlador', 'Recambio de tarjeta danada', CURRENT_DATE - 82, TRUE,  NOW() - INTERVAL '83 days', 6, 12),
('Sincronizar con el eje Grecia', 'Programacion de ciclos', CURRENT_DATE - 89, TRUE,  NOW() - INTERVAL '90 days', 6, 12),
('Revisar detector de vehiculos', 'Espira detectora sin lectura', CURRENT_DATE - 96, TRUE,  NOW() - INTERVAL '97 days', 6, 12),
('Reponer lente rojo del semaforo', 'Lente quebrado por vandalismo', CURRENT_DATE + 35, FALSE, NULL, 6, 12),
('Verificar funcionamiento en punta', 'Observacion en hora punta', CURRENT_DATE + 44, FALSE, NULL, 6, 12),
--   zona 15: Areas verdes - Cerro Santa Lucia  -> 1 completadas, 1 pendientes
('Retirar ramas del cerro', 'Despeje de senderos del cerro', CURRENT_DATE - 103, TRUE,  NOW() - INTERVAL '104 days', 6, 15),
('Reparar baranda del mirador', 'Cambio de baranda oxidada', CURRENT_DATE + 53, FALSE, NULL, 6, 15),

-- ------------------------------------------------------------
-- avaldes (id_usuario = 7)
-- ------------------------------------------------------------
--   zona 8: Ciclovia - Av. Vicuna Mackenna  -> 1 completadas, 1 pendientes
('Repintar demarcacion tramo sur', 'Pintura reflectante en curvas', CURRENT_DATE - 3, TRUE,  NOW() - INTERVAL '4 days', 7, 8),
('Instalar tachas reflectantes', 'Tachas en cruces conflictivos', CURRENT_DATE + 2, FALSE, NULL, 7, 8),
--   zona 11: Pavimento agrietado - Plaza Nunoa  -> 2 completadas, 0 pendientes
('Catastrar grietas del pavimento', 'Medicion y registro de grietas', CURRENT_DATE - 5, TRUE,  NOW() - INTERVAL '6 days', 7, 11),
('Sellar grietas con asfalto', 'Sellado de fisuras del paseo', CURRENT_DATE - 8, TRUE,  NOW() - INTERVAL '9 days', 7, 11),
--   zona 13: Retiro de escombros - Puente Alto centro  -> 3 completadas, 1 pendientes
('Cercar el foco de escombros', 'Cierre del sitio con malla', CURRENT_DATE - 12, TRUE,  NOW() - INTERVAL '13 days', 7, 13),
('Retirar escombros con camion', 'Carguio y traslado a botadero', CURRENT_DATE - 19, TRUE,  NOW() - INTERVAL '20 days', 7, 13),
('Instalar carteles disuasivos', 'Senaletica de prohibicion', CURRENT_DATE - 26, TRUE,  NOW() - INTERVAL '27 days', 7, 13),
('Limpiar y nivelar el terreno', 'Nivelacion final del sitio', CURRENT_DATE + 3, FALSE, NULL, 7, 13),
--   zona 18: Luminarias - La Florida sur  -> 5 completadas, 2 pendientes
('Catastrar postes apagados', 'Recorrido nocturno del sector', CURRENT_DATE - 33, TRUE,  NOW() - INTERVAL '34 days', 7, 18),
('Cambiar luminarias del pasaje', 'Recambio de tres luminarias', CURRENT_DATE - 40, TRUE,  NOW() - INTERVAL '41 days', 7, 18),
('Reparar tablero electrico', 'Tablero con humedad', CURRENT_DATE - 47, TRUE,  NOW() - INTERVAL '48 days', 7, 18),
('Podar arboles que tapan la luz', 'Poda de copa que bloquea luminarias', CURRENT_DATE - 54, TRUE,  NOW() - INTERVAL '55 days', 7, 18),
('Confirmar encendido del tramo', 'Ronda de verificacion nocturna', CURRENT_DATE - 61, TRUE,  NOW() - INTERVAL '62 days', 7, 18),
('Pintar postes intervenidos', 'Terminacion anticorrosiva', CURRENT_DATE + 12, FALSE, NULL, 7, 18),
('Catastrar postes apagados', 'Recorrido nocturno del sector', CURRENT_DATE + 19, FALSE, NULL, 7, 18),

-- ------------------------------------------------------------
-- ktapia (id_usuario = 8)
-- ------------------------------------------------------------
--   zona 5: Alumbrado publico - Barrio Ecuador  -> 2 completadas, 1 pendientes
('Catastrar luminarias apagadas', 'Recorrido nocturno de catastro', CURRENT_DATE - 3, TRUE,  NOW() - INTERVAL '4 days', 8, 5),
('Cambiar tres luminarias LED', 'Reemplazo en postes 12, 14 y 15', CURRENT_DATE - 5, TRUE,  NOW() - INTERVAL '6 days', 8, 5),
('Pintar postes intervenidos', 'Terminacion anticorrosiva', CURRENT_DATE + 2, FALSE, NULL, 8, 5),
--   zona 9: Luminarias quemadas - Barrio Republica  -> 1 completadas, 0 pendientes
('Catastrar luminarias del pasaje', 'Recorrido nocturno del barrio', CURRENT_DATE - 8, TRUE,  NOW() - INTERVAL '9 days', 8, 9),
--   zona 14: Alcantarillado - Quilicura norte  -> 4 completadas, 1 pendientes
('Video inspeccion del colector', 'Camara por la camara norte', CURRENT_DATE - 12, TRUE,  NOW() - INTERVAL '13 days', 8, 14),
('Destapar camara colapsada', 'Hidrolavado y retiro de raices', CURRENT_DATE - 19, TRUE,  NOW() - INTERVAL '20 days', 8, 14),
('Reemplazar tapa de camara', 'Tapa quebrada en la calzada', CURRENT_DATE - 26, TRUE,  NOW() - INTERVAL '27 days', 8, 14),
('Reparar tramo de alcantarillado', 'Cambio de tramo danado', CURRENT_DATE - 33, TRUE,  NOW() - INTERVAL '34 days', 8, 14),
('Reponer pavimento sobre la zanja', 'Relleno y carpeta asfaltica', CURRENT_DATE + 3, FALSE, NULL, 8, 14),
--   zona 19: Socavon - Av. Dorsal, Renca  -> 6 completadas, 2 pendientes
('Cercar el socavon', 'Cierre de emergencia del socavon', CURRENT_DATE - 40, TRUE,  NOW() - INTERVAL '41 days', 8, 19),
('Inspeccionar la matriz de agua', 'Revision con la sanitaria', CURRENT_DATE - 47, TRUE,  NOW() - INTERVAL '48 days', 8, 19),
('Excavar y reparar la matriz', 'Reparacion de la matriz rota', CURRENT_DATE - 54, TRUE,  NOW() - INTERVAL '55 days', 8, 19),
('Rellenar y compactar', 'Relleno estructural de la excavacion', CURRENT_DATE - 61, TRUE,  NOW() - INTERVAL '62 days', 8, 19),
('Reponer la carpeta asfaltica', 'Asfalto sobre la reparacion', CURRENT_DATE - 68, TRUE,  NOW() - INTERVAL '69 days', 8, 19),
('Reabrir la calzada al transito', 'Retiro de cierre y senaletica', CURRENT_DATE - 75, TRUE,  NOW() - INTERVAL '76 days', 8, 19),
('Cercar el socavon', 'Cierre de emergencia del socavon', CURRENT_DATE + 12, FALSE, NULL, 8, 19),
('Inspeccionar la matriz de agua', 'Revision con la sanitaria', CURRENT_DATE + 19, FALSE, NULL, 8, 19),

-- ------------------------------------------------------------
-- pgomez (id_usuario = 9)
-- ------------------------------------------------------------
--   zona 9: Luminarias quemadas - Barrio Republica  -> 0 completadas, 1 pendientes
('Catastrar luminarias del pasaje', 'Recorrido nocturno del barrio', CURRENT_DATE + 2, FALSE, NULL, 9, 9);
