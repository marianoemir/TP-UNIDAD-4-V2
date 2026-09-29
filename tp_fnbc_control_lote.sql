-- =============================================================================
-- TRABAJO PRÁCTICO UNIDAD 4 - PARTE 1 (FNBC)
-- Rol: Integrante 3
-- Archivo: tp_fnbc_control_lote.sql
-- Repositorio: TP-UNIDAD-4-V2
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ESQUEMA INICIAL E INSTANCIA DE EJEMPLO
-- -----------------------------------------------------------------------------

-- Creación de tablas base (Entidades principales)
CREATE TABLE IF NOT EXISTS lote (
    id_lote INT PRIMARY KEY,
    fecha_vencimiento DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS deposito (
    id_deposito INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL
);

-- Tabla universal/no normalizada a analizar
CREATE TABLE IF NOT EXISTS control_lote_almacen (
    id_lote INT NOT NULL REFERENCES lote(id_lote),
    id_deposito INT NOT NULL REFERENCES deposito(id_deposito),
    id_almacenero INT NOT NULL,
    nombre_almacenero VARCHAR(100) NOT NULL,
    turnos VARCHAR(50) NOT NULL,
    resultado_inspection VARCHAR(50) NOT NULL,
    PRIMARY KEY (id_lote, id_deposito, id_almacenero)
);

-- Carga de la instancia de prueba inicial
INSERT INTO lote (id_lote, fecha_vencimiento) VALUES
(101, '2026-12-31'),
(102, '2026-11-30');

INSERT INTO deposito (id_deposito, nombre) VALUES
(1, 'Depósito Central'),
(2, 'Depósito Norte');

INSERT INTO control_lote_almacen (id_lote, id_deposito, id_almacenero, nombre_almacenero, turnos, resultado_inspection) VALUES
(101, 1, 5, 'Carlos Gómez', 'Mañana/Tarde', 'Aprobado'),
(101, 2, 5, 'Carlos Gómez', 'Mañana/Tarde', 'Aprobado'),
(102, 1, 8, 'Ana Martínez', 'Noche', 'Rechazado');


-- -----------------------------------------------------------------------------
-- 2. DESCOMPOSICIÓN A FNBC (UP.SQL)
-- -----------------------------------------------------------------------------
-- Diagnóstico de Integrante 2:
-- Dependencia Funcional Violatoria: id_almacenero -> nombre_almacenero, turnos
-- Determinante: id_almacenero (No es superclave en control_lote_almacen)

-- Paso 1: Creación de tablas proyectadas en FNBC
CREATE TABLE IF NOT EXISTS almacenero (
    id_almacenero INT PRIMARY KEY,
    nombre_almacenero VARCHAR(100) NOT NULL,
    turnos VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS control_lote_almacen_fnbc (
    id_lote INT NOT NULL REFERENCES lote(id_lote),
    id_deposito INT NOT NULL REFERENCES deposito(id_deposito),
    id_almacenero INT NOT NULL REFERENCES almacenero(id_almacenero),
    resultado_inspection VARCHAR(50) NOT NULL,
    PRIMARY KEY (id_lote, id_deposito, id_almacenero)
);

-- Paso 2: Migración de datos sin destruir el origen
INSERT INTO almacenero (id_almacenero, nombre_almacenero, turnos)
SELECT DISTINCT id_almacenero, nombre_almacenero, turnos
FROM control_lote_almacen;

INSERT INTO control_lote_almacen_fnbc (id_lote, id_deposito, id_almacenero, resultado_inspection)
SELECT id_lote, id_deposito, id_almacenero, resultado_inspection
FROM control_lote_almacen;


-- -----------------------------------------------------------------------------
-- 3. VISTA DE COMPATIBILIDAD Y VERIFICACIÓN (DOS EXCEPT)
-- -----------------------------------------------------------------------------

-- Vista de compatibilidad para consultas heredadas
CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT 
    c.id_lote,
    c.id_deposito,
    c.id_almacenero,
    a.nombre_almacenero,
    a.turnos,
    c.resultado_inspection
FROM control_lote_almacen_fnbc c
JOIN almacenero a ON c.id_almacenero = a.id_almacenero;

-- VERIFICACIÓN BIDIRECCIONAL DE UNIÓN SIN PÉRDIDA

-- Check 1: Tuplas de la tabla original que falten en la vista (debe dar 0 filas)
SELECT id_lote, id_deposito, id_almacenero, nombre_almacenero, turnos, resultado_inspection
FROM control_lote_almacen
EXCEPT
SELECT id_lote, id_deposito, id_almacenero, nombre_almacenero, turnos, resultado_inspection
FROM v_control_lote_almacen;

-- Check 2: Tuplas espurias en la vista que no existan en la tabla original (debe dar 0 filas)
SELECT id_lote, id_deposito, id_almacenero, nombre_almacenero, turnos, resultado_inspection
FROM v_control_lote_almacen
EXCEPT
SELECT id_lote, id_deposito, id_almacenero, nombre_almacenero, turnos, resultado_inspection
FROM control_lote_almacen;


-- -----------------------------------------------------------------------------
-- 4. SCRIPT DE REVERSIÓN (DOWN.SQL)
-- -----------------------------------------------------------------------------
/*
-- Para probar o revertir la descomposición completa:
DROP VIEW IF EXISTS v_control_lote_almacen;
DROP TABLE IF EXISTS control_lote_almacen_fnbc;
DROP TABLE IF EXISTS almacenero;
DROP TABLE IF EXISTS control_lote_almacen;
DROP TABLE IF EXISTS deposito;
DROP TABLE IF EXISTS lote;
*/