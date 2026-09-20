-- =============================================================================
-- TRABAJO PRÁCTICO N.º 3 - FOOD STORE - Parte 2
-- PARTE 2: Análisis de Rendimiento y Optimización
-- Motor: PostgreSQL
-- Integrantes: Chirino Pamela, Agüero Lucas y Mule Mayra
-- =============================================================================

-- =========================================================
-- Consulta 1: Búsqueda de pedidos por rango de fechas
-- =========================================================

-- Limpieza preventiva
DROP INDEX IF EXISTS idx_pedido_fecha;

-- 1. Medición SIN ÍNDICE 
EXPLAIN ANALYZE
SELECT id_pedido, fecha, forma_pago, id_cliente
FROM pedido
WHERE fecha BETWEEN '2026-01-01' AND '2026-03-31';

-- 2. Propuesta de mejora: Índice B-Tree sobre la columna filtrada (fecha)
CREATE INDEX idx_pedido_fecha ON pedido(fecha);

-- 3. Medición CON ÍNDICE 
EXPLAIN ANALYZE
SELECT id_pedido, fecha, forma_pago, id_cliente
FROM pedido
WHERE fecha BETWEEN '2026-01-01' AND '2026-03-31';

-- =========================================================
-- Consulta 2: Historial de pedidos por cliente
-- =========================================================

-- Limpieza preventiva
DROP INDEX IF EXISTS idx_pedido_cliente;

-- 1. Medición SIN ÍNDICE 
EXPLAIN ANALYZE
SELECT id_pedido, fecha, forma_pago
FROM pedido
WHERE id_cliente = 500;

-- 2. Propuesta de mejora: Índice B-Tree sobre la clave foránea id_cliente
CREATE INDEX idx_pedido_cliente ON pedido(id_cliente);

-- 3. Medición CON ÍNDICE 
EXPLAIN ANALYZE
SELECT id_pedido, fecha, forma_pago
FROM pedido
WHERE id_cliente = 500;

-- =========================================================
-- Caso 3: Historial de ventas por producto
-- =========================================================

-- Limpieza preventiva
DROP INDEX IF EXISTS idx_pedido_producto_producto;

-- 1. Medición SIN ÍNDICE 
EXPLAIN ANALYZE
SELECT id_pedido, id_producto, cantidad, precio_unitario
FROM pedido_producto
WHERE id_producto = 10;

-- 2. Propuesta de mejora: Índice B-Tree sobre la clave foránea id_producto
CREATE INDEX idx_pedido_producto_producto ON pedido_producto(id_producto);

-- 3. Medición CON ÍNDICE 
EXPLAIN ANALYZE
SELECT id_pedido, id_producto, cantidad, precio_unitario
FROM pedido_producto
WHERE id_producto = 10;