-- =============================================================================
-- TRABAJO PRÁCTICO N.º 3 - FOOD STORE - Parte 1
-- Parte 1: Script de Poblamiento Masivo (generate_series)
-- Motor: PostgreSQL
-- Integrantes: Chirino Pamela, Agüero Lucas y Mule Mayra
-- =============================================================================
/* 
=============================================================================
SCRIPT DE AUXILIO / RESET (Descomentar solo para vaciar la base y repoblar)
=============================================================================
ROLLBACK;
1- TRUNCATE TABLE pedido_producto, pedido, producto, cliente, categoria RESTART IDENTITY CASCADE;
2- ALTER TABLE pedido_producto DISABLE TRIGGER ALL;
3 - (Acá ejecutás el script de carga masiva)
4- ALTER TABLE pedido_producto ENABLE TRIGGER ALL;
=============================================================================
*/


BEGIN;

-- 1. Insertar categorías base si no existen
INSERT INTO categoria (nombre, descripcion, activo)
SELECT 'Categoría ' || g, 'Descripción de categoría ' || g, TRUE
FROM generate_series(1, 10) AS g
ON CONFLICT DO NOTHING;

-- 2. Insertar 20.000 Clientes
INSERT INTO cliente (nombre, apellido, telefono, email)
SELECT 
    'Cliente_' || g AS nombre,
    'Apellido_' || g AS apellido,
    '+549261' || (1000000 + g) AS telefono,
    'usuario_' || g || '@example.com' AS email
FROM generate_series(1, 20000) AS g;

-- 3. Insertar 50.000 Productos (stock entre 1 y 200 para evitar bloqueos por stock 0)
INSERT INTO producto (nombre, descripcion, precio, stock, activo, id_categoria)
SELECT 
    'Producto ' || g AS nombre,
    'Descripción del producto ' || g AS descripcion,
    (ROUND((random() * 4500 + 500)::numeric, 2)) AS precio,
    (floor(random() * 200) + 1)::int AS stock,
    TRUE AS activo,
    ((g % (SELECT COUNT(*) FROM categoria)) + 1)::bigint AS id_categoria
FROM generate_series(1, 50000) AS g;

-- 4. Insertar 200.000 Pedidos
INSERT INTO pedido (fecha, forma_pago, id_cliente)
SELECT 
    NOW() - (random() * interval '365 days') AS fecha,
    (ARRAY['EFECTIVO', 'TARJETA', 'TRANSFERENCIA']::forma_pago_enum[])[floor(random() * 3 + 1)] AS forma_pago,
    (floor(random() * 20000 + 1))::bigint AS id_cliente
FROM generate_series(1, 200000) AS g;

-- 5. Insertar Detalle de Pedidos
INSERT INTO pedido_producto (id_pedido, id_producto, cantidad, precio_unitario)
SELECT 
    p.id_pedido,
    (floor(random() * 50000 + 1))::bigint AS id_producto,
    (floor(random() * 5 + 1))::int AS cantidad,
    (ROUND((random() * 4500 + 500)::numeric, 2)) AS precio_unitario
FROM (
    SELECT generate_series(1, 200000) AS id_pedido, generate_series(1, 2)
) p
ON CONFLICT (id_pedido, id_producto) DO NOTHING;

COMMIT;

-- Actualizar estadísticas de rendimiento en PostgreSQL
ANALYZE cliente;
ANALYZE producto;
ANALYZE pedido;
ANALYZE pedido_producto;
ANALYZE categoria;