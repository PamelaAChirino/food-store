-- Carga de detalle de pedidos (pedido_producto) para el TP4.
--
-- Decision documentada: se deshabilita el trigger trg_pedido_producto_venta
-- para esta carga historica masiva (simula 200.000 pedidos ya hechos). Ese
-- trigger valida activo/stock pensado para ventas una por una en tiempo
-- real; aplicado fila por fila sobre este volumen agotaria el stock de
-- muchos productos a mitad de la carga y abortaria toda la transaccion.
-- Se rehabilita apenas termina, para que siga protegiendo ventas nuevas.
--
-- Nota tecnica: el id_producto aleatorio se genera en una CTE con random()
-- en el SELECT list directo (no en una subconsulta/JOIN no correlacionados),
-- porque ese patron ya demostro evaluarse una sola vez para todas las filas
-- (mismo bug que en la carga de productos/categorias de la Semana 3).

ALTER TABLE pedido_producto DISABLE TRIGGER trg_pedido_producto_venta;

BEGIN;

WITH lineas AS (
    SELECT pe.id_pedido,
           (1 + floor(random() * 50000))::bigint AS id_producto_rand,
           (1 + floor(random() * 5))::int AS cantidad
    FROM pedido pe
    CROSS JOIN generate_series(1, 3) AS ln(n)
)
INSERT INTO pedido_producto (id_pedido, id_producto, cantidad, precio_unitario)
SELECT l.id_pedido, l.id_producto_rand, l.cantidad, p.precio
FROM lineas l
JOIN producto p ON p.id_producto = l.id_producto_rand
ON CONFLICT (id_pedido, id_producto) DO NOTHING;

ANALYZE pedido_producto;

COMMIT;

ALTER TABLE pedido_producto ENABLE TRIGGER trg_pedido_producto_venta;

SELECT COUNT(*) AS total_lineas FROM pedido_producto;
SELECT COUNT(DISTINCT id_producto) AS productos_distintos_usados FROM pedido_producto;
