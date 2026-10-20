-- ============================================================================
-- Trabajo Práctico Unidad 5 - Parte B: Auditoría y Pruebas
-- Script: auditoria_test.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================

-- 1. Tabla de Log de Auditoría
CREATE TABLE IF NOT EXISTS log_auditoria (
    id_log BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario VARCHAR(100) NOT NULL DEFAULT CURRENT_USER,
    operacion VARCHAR(20) NOT NULL,
    tabla_afectada VARCHAR(50) NOT NULL,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    datos_anteriores JSONB,
    datos_nuevos JSONB
);

-- 2. Función genérica de auditoría para triggers
CREATE OR REPLACE FUNCTION fn_auditar_cambios()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO log_auditoria (usuario, operacion, tabla_afectada, datos_anteriores)
        VALUES (CURRENT_USER, 'DELETE', TG_TABLE_NAME, to_jsonb(OLD));
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_auditoria (usuario, operacion, tabla_afectada, datos_anteriores, datos_nuevos)
        VALUES (CURRENT_USER, 'UPDATE', TG_TABLE_NAME, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO log_auditoria (usuario, operacion, tabla_afectada, datos_nuevos)
        VALUES (CURRENT_USER, 'INSERT', TG_TABLE_NAME, to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Asignación de Triggers sobre tablas críticas
DROP TRIGGER IF EXISTS trg_auditoría_cliente ON cliente;
CREATE TRIGGER trg_auditoría_cliente
AFTER INSERT OR UPDATE OR DELETE ON cliente
FOR EACH ROW EXECUTE FUNCTION fn_auditar_cambios();

DROP TRIGGER IF EXISTS trg_auditoría_pedido ON pedido;
CREATE TRIGGER trg_auditoría_pedido
AFTER INSERT OR UPDATE OR DELETE ON pedido
FOR EACH ROW EXECUTE FUNCTION fn_auditar_cambios();

-- 4. Pruebas de Verificación (Simulación de Operaciones)
-- A) Actualización en cliente
UPDATE cliente 
SET telefono = '2610001122' 
WHERE id_cliente = 1;

-- B) Consulta del Log de Auditoría generado
SELECT 
    id_log, 
    usuario, 
    operacion, 
    tabla_afectada, 
    fecha_hora, 
    datos_anteriores->>'telefono' AS telefono_anterior,
    datos_nuevos->>'telefono' AS telefono_nuevo
FROM log_auditoria
ORDER BY id_log DESC;