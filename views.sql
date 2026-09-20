-- ==========================================
-- ENTREGABLE: views.sql
-- Parte B — Base de Datos II (Food Store)
-- ==========================================

-- 1. Vista de productos vigentes con su categoría
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT 
    p.id_producto AS producto_id,
    p.nombre AS producto_nombre,
    p.precio,
    p.stock,
    c.id_categoria AS categoria_id,
    c.nombre AS categoria_nombre
FROM producto p
JOIN categoria c ON p.id_categoria = c.id_categoria
WHERE p.activo = TRUE;

-- 2. Vista de pedidos con los datos del usuario (Criterio de seguridad aplicado)
CREATE OR REPLACE VIEW v_pedidos_usuarios AS
SELECT 
    pd.id_pedido AS pedido_id,
    pd.fecha AS pedido_fecha,
    pd.forma_pago,
    u.id_cliente AS cliente_id,
    u.nombre AS cliente_nombre,
    u.apellido AS cliente_apellido,
    u.email AS cliente_email
    -- NOTA: Se aplica el criterio de seguridad omitiendo datos sensibles del cliente.
FROM pedido pd
JOIN cliente u ON pd.id_cliente = u.id_cliente;

-- 3. Vista de detalle de un pedido con el nombre del producto
CREATE OR REPLACE VIEW v_detalle_pedido_producto AS
SELECT 
    dp.id_pedido,
    dp.cantidad,
    dp.precio_unitario,
    p.id_producto AS producto_id,
    p.nombre AS producto_nombre
FROM pedido_producto dp
JOIN producto p ON dp.id_producto = p.id_producto;

-- ==========================================
-- PARTE C — Vista Materializada y Refresh
-- ==========================================

-- 1. Creación de la Vista Materializada (Reporte agregado de facturación por categoría y mes)
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT 
    c.id_categoria,
    c.nombre AS categoria_nombre,
    DATE_TRUNC('month', p.fecha) AS mes_anio,
    SUM(dp.cantidad * dp.precio_unitario) AS total_facturado,
    COUNT(DISTINCT p.id_pedido) AS total_pedidos
FROM categoria c
JOIN producto pr ON c.id_categoria = pr.id_categoria
JOIN pedido_producto dp ON pr.id_producto = dp.id_producto
JOIN pedido p ON dp.id_pedido = p.id_pedido
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', p.fecha)
WITH DATA;

-- 2. Creación del Índice Único Obligatorio (Permite REFRESH CONCURRENTLY a futuro sin bloquear lecturas)
CREATE UNIQUE INDEX idx_mv_facturacion_cat_mes 
ON mv_facturacion_categoria_mes (id_categoria, mes_anio);