-- ============================================================================
-- Trabajo Práctico Unidad 5 - Parte D: Anonimización de usuario y verificación
-- Script: usuario_anon.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================
-- Nota de adaptación: la consigna genérica habla de anonimizar la tabla
-- "usuario". Food Store no tenía originalmente una tabla de usuarios de
-- aplicación (solo "cliente", sin rol ni credenciales); se construyó
-- "usuario" como parte de la Parte A/C de esta misma Unidad 5, para poder
-- usar fn_autenticar y simular el incidente de la Parte C. Esta parte D
-- anonimiza esa tabla.
-- ============================================================================

-- 1. Construcción de la tabla usuario_anon con datos sintéticos deterministas
DROP TABLE IF EXISTS usuario_anon CASCADE;

CREATE TABLE usuario_anon AS
SELECT
    id_usuario,
    -- Anonimización determinista del nombre de usuario (no reversible)
    'usuario_' || md5(nombre_usuario) AS nombre_usuario_anonimizado,
    -- Nombre completo reemplazado por un rótulo genérico con el id
    'Usuario #' || id_usuario AS nombre_completo_anonimizado,
    -- Email anonimizado preservando dominio genérico (no el real)
    'user_' || md5(email) || '@anon.local' AS email_anonimizado,
    rol,
    activo,
    fecha_alta
FROM usuario;

-- 2. Consulta de agregación sobre la tabla ANONIMIZADA (usuario_anon)
--    Cantidad de usuarios por rol y por mes de alta
SELECT
    rol,
    date_trunc('month', fecha_alta)::date AS mes_alta,
    COUNT(*) AS total_usuarios
FROM usuario_anon
GROUP BY rol, date_trunc('month', fecha_alta)
ORDER BY mes_alta, rol;

-- 3. Consulta equivalente de agregación sobre la tabla REAL (usuario)
SELECT
    rol,
    date_trunc('month', fecha_alta)::date AS mes_alta,
    COUNT(*) AS total_usuarios
FROM usuario
GROUP BY rol, date_trunc('month', fecha_alta)
ORDER BY mes_alta, rol;

-- 4. Verificación de equivalencia total (ambos EXCEPT deben dar 0 filas)
(
    SELECT rol, date_trunc('month', fecha_alta)::date AS mes_alta, COUNT(*) AS total_usuarios
    FROM usuario_anon GROUP BY rol, date_trunc('month', fecha_alta)
)
EXCEPT
(
    SELECT rol, date_trunc('month', fecha_alta)::date AS mes_alta, COUNT(*) AS total_usuarios
    FROM usuario GROUP BY rol, date_trunc('month', fecha_alta)
);
