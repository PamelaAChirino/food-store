-- ============================================================================
-- Trabajo Práctico Unidad 4 - Parte 1: FNBC y Descomposición sin pérdida
-- Script: control_lote_almacen.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================

BEGIN;

-- Esquema original (sin normalizar)
CREATE TABLE IF NOT EXISTS control_lote_almacen_legacy (
    lote_id                BIGINT NOT NULL,
    deposito_id            BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,
    PRIMARY KEY (lote_id, deposito_id)
);

-- Instancia de ejemplo provista por la cátedra
INSERT INTO control_lote_almacen_legacy VALUES
(501, 30, 801),
(502, 30, 801),
(503, 31, 802)
ON CONFLICT DO NOTHING;

-- Validación previa de la DF2 (responsable -> deposito)
SELECT responsable_control_id, COUNT(DISTINCT deposito_id) AS depositos
FROM control_lote_almacen_legacy
GROUP BY responsable_control_id
HAVING COUNT(DISTINCT deposito_id) > 1;

-- Descomposición a FNBC
CREATE TABLE IF NOT EXISTS responsable_deposito_fnbc (
    responsable_control_id BIGINT PRIMARY KEY,
    deposito_id            BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS control_lote_fnbc (
    lote_id                BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL
        REFERENCES responsable_deposito_fnbc(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- Migración de datos
INSERT INTO responsable_deposito_fnbc (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM control_lote_almacen_legacy
ON CONFLICT (responsable_control_id) DO NOTHING;

INSERT INTO control_lote_fnbc (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id
FROM control_lote_almacen_legacy
ON CONFLICT DO NOTHING;

-- Vista de compatibilidad
CREATE OR REPLACE VIEW v_control_lote_almacen_fnbc AS
SELECT cl.lote_id, rd.deposito_id, cl.responsable_control_id
FROM control_lote_fnbc cl
JOIN responsable_deposito_fnbc rd
  ON rd.responsable_control_id = cl.responsable_control_id;

COMMIT;

-- ============================================================================
-- Verificación de equivalencia (ambos EXCEPT deben retornar 0 filas)
-- ============================================================================
(SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen_legacy)
EXCEPT
(SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen_fnbc);

(SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen_fnbc)
EXCEPT
(SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen_legacy);

-- Chequeo opcional de la DF1 ({lote, deposito} -> responsable)
SELECT lote_id, deposito_id, COUNT(DISTINCT responsable_control_id) AS responsables
FROM v_control_lote_almacen_fnbc
GROUP BY lote_id, deposito_id
HAVING COUNT(DISTINCT responsable_control_id) > 1;