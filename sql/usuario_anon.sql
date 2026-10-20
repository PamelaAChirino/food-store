-- ============================================================================
-- Trabajo Práctico Unidad 5 - Parte D: Anonimización de Datos y Verificación
-- Script: usuario_anon.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================
--
-- NOTA DE ADAPTACIÓN: la consigna pide agrupar por "rol" y "mes de alta".
-- El esquema real de Food Store no tiene una tabla "usuario" genérica (se usa
-- "cliente", ver nota en simulacro_incidente.sql) ni una columna de fecha de
-- alta en cliente. Como proxy razonable y verificable se usa el mes del
-- PRIMER PEDIDO de cada cliente (MIN(pedido.fecha)) como "mes de alta" --
-- es el dato más cercano a "cuándo empezó a operar" que el modelo real
-- registra. Un cliente sin pedidos queda con mes_alta = NULL (se documenta
-- como caso borde, no se descarta).
-- El "rol" sigue el mismo criterio sintético ya usado en la Clase 2
-- (alternancia determinista por id_cliente), documentado también en
-- BITACORA.md.
-- ============================================================================

-- 1. Construcción / actualización de usuario_anon con datos sintéticos
--    deterministas, incluyendo el mes de alta (proxy: primer pedido)
DROP TABLE IF EXISTS usuario_anon CASCADE;

CREATE TABLE usuario_anon AS
SELECT
    c.id_cliente AS id_usuario,
    'Usuario_' || c.id_cliente AS usuario_anonimizado,
    'user_' || md5(c.email) || '@anon.local' AS email_anonimizado,
    CASE
        WHEN c.id_cliente % 2 = 0 THEN 'rol_app_lectura'
        ELSE 'rol_app_escritura'
    END AS rol,
    DATE_TRUNC('month', MIN(p.fecha))::date AS mes_alta
FROM cliente c
LEFT JOIN pedido p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.email;

-- 2. Consulta de agregación sobre la tabla ANONIMIZADA (usuario_anon):
--    cantidad de usuarios por rol y por mes de alta
SELECT
    rol,
    mes_alta,
    COUNT(*) AS total_usuarios
FROM usuario_anon
GROUP BY rol, mes_alta
ORDER BY rol, mes_alta;

-- 3. Consulta equivalente de agregación sobre la tabla REAL (cliente + pedido)
SELECT
    CASE
        WHEN c.id_cliente % 2 = 0 THEN 'rol_app_lectura'
        ELSE 'rol_app_escritura'
    END AS rol,
    DATE_TRUNC('month', MIN(p.fecha))::date AS mes_alta,
    COUNT(*) AS total_usuarios
FROM cliente c
LEFT JOIN pedido p ON p.id_cliente = c.id_cliente
GROUP BY
    CASE
        WHEN c.id_cliente % 2 = 0 THEN 'rol_app_lectura'
        ELSE 'rol_app_escritura'
    END,
    c.id_cliente
ORDER BY rol, mes_alta;

-- Nota: la consulta del punto 3 muestra el detalle por cliente (una fila por
-- combinación real) para poder inspeccionarla; la agregación final
-- comparable con el punto 2 se arma en la sección 4.

-- ============================================================================
-- 4. Verificación de equivalencia (ambos EXCEPT deben retornar 0 filas)
-- ============================================================================
WITH real_por_cliente AS (
    SELECT
        c.id_cliente,
        CASE WHEN c.id_cliente % 2 = 0 THEN 'rol_app_lectura' ELSE 'rol_app_escritura' END AS rol,
        DATE_TRUNC('month', MIN(p.fecha))::date AS mes_alta
    FROM cliente c
    LEFT JOIN pedido p ON p.id_cliente = c.id_cliente
    GROUP BY c.id_cliente
),
real_agregado AS (
    SELECT rol, mes_alta, COUNT(*) AS total_usuarios
    FROM real_por_cliente
    GROUP BY rol, mes_alta
),
anon_agregado AS (
    SELECT rol, mes_alta, COUNT(*) AS total_usuarios
    FROM usuario_anon
    GROUP BY rol, mes_alta
)
(SELECT * FROM anon_agregado EXCEPT SELECT * FROM real_agregado)
UNION ALL
(SELECT * FROM real_agregado EXCEPT SELECT * FROM anon_agregado);
-- 0 filas => equivalencia confirmada en ambas direcciones
