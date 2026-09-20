-- =============================================================================
-- FOOD STORE - queries.sql
-- Consultas de negocio y analíticas de las Semanas 3 y 4, usadas como fuente
-- de la carga de trabajo real para el plan de indexado de la Semana 5.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- SEMANA 3 — consultas con filtro simple sobre una tabla
-- -----------------------------------------------------------------------------

-- Q1: Búsqueda de productos activos dentro de un rango de precios y categoría
-- específica (listado de catálogo).
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE id_categoria = (SELECT id_categoria FROM categoria WHERE nombre = 'Pizzas')
  AND activo = TRUE
  AND precio BETWEEN 1000 AND 3000
ORDER BY precio;

-- Q2: Historial completo de pedidos de un cliente específico, ordenados por
-- fecha (pantalla "mis pedidos").
SELECT pe.id_pedido, pe.fecha, p.nombre AS producto, pp.cantidad, pp.precio_unitario
FROM cliente cl
JOIN pedido pe ON pe.id_cliente = cl.id_cliente
JOIN pedido_producto pp ON pp.id_pedido = pe.id_pedido
JOIN producto p ON p.id_producto = pp.id_producto
WHERE cl.email = :email
ORDER BY pe.fecha DESC;

-- Q3: Reporte de ventas agrupado por forma de pago dentro de un rango de
-- fechas (caja / conciliación).
SELECT c.nombre AS categoria, SUM(pp.cantidad * pp.precio_unitario) AS facturacion
FROM categoria c
JOIN producto p ON p.id_categoria = c.id_categoria
JOIN pedido_producto pp ON pp.id_producto = p.id_producto
JOIN pedido pe ON pe.id_pedido = pp.id_pedido
WHERE c.activo = TRUE
  AND pe.fecha >= :desde AND pe.fecha < :hasta
GROUP BY c.nombre
ORDER BY facturacion DESC;

-- Q4 (Semana 5 — Parte A): búsqueda de productos vigentes por nombre
-- (buscador del catálogo).
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE nombre LIKE :texto || '%' AND activo = TRUE;

-- Q5 (Semana 5 — Parte A): pedidos filtrados por forma de pago (reporte de
-- caja). Se documenta igual que las demás porque el índice propuesto para
-- esta consulta terminó descartado — ver indices.sql e informe_mediciones.md.
SELECT id_pedido, fecha, id_cliente
FROM pedido
WHERE forma_pago = :forma_pago;

-- Q6 (Semana 5 — Parte A): productos más vendidos (ranking para el panel de
-- administración). Índice propuesto también descartado — ver
-- informe_mediciones.md.
SELECT id_producto, SUM(cantidad) AS unidades_vendidas
FROM pedido_producto
GROUP BY id_producto
ORDER BY unidades_vendidas DESC
LIMIT 10;


-- -----------------------------------------------------------------------------
-- SEMANA 4 — consultas analíticas con 3+ tablas (JOIN, agregación, ventana)
-- -----------------------------------------------------------------------------

-- Q7: Facturación por categoría y mes (reporte gerencial). Base de la vista
-- materializada mv_facturacion_categoria_mes de la Semana 5.
SELECT c.nombre AS categoria,
       date_trunc('month', pe.fecha) AS mes,
       SUM(pp.cantidad * pp.precio_unitario) AS facturacion
FROM categoria c
JOIN producto p ON p.id_categoria = c.id_categoria
JOIN pedido_producto pp ON pp.id_producto = p.id_producto
JOIN pedido pe ON pe.id_pedido = pp.id_pedido
WHERE c.activo = TRUE
GROUP BY c.nombre, date_trunc('month', pe.fecha)
ORDER BY c.nombre, mes;

-- Q8: Ranking de clientes por gasto total, con función de ventana (empates
-- comparten puesto).
WITH totales AS (
    SELECT pe.id_cliente, SUM(pp.cantidad * pp.precio_unitario) AS total_gastado
    FROM pedido pe
    JOIN pedido_producto pp ON pp.id_pedido = pe.id_pedido
    GROUP BY pe.id_cliente
)
SELECT cl.nombre, cl.apellido, t.total_gastado,
       RANK() OVER (ORDER BY t.total_gastado DESC) AS puesto
FROM cliente cl
JOIN totales t ON t.id_cliente = cl.id_cliente
ORDER BY puesto;

-- Q9: mismo ranking que Q8, resuelto con subconsulta correlacionada en vez
-- de función de ventana (verificado equivalente a Q8 con EXCEPT).
WITH totales AS (
    SELECT pe.id_cliente, SUM(pp.cantidad * pp.precio_unitario) AS total_gastado
    FROM pedido pe
    JOIN pedido_producto pp ON pp.id_pedido = pe.id_pedido
    GROUP BY pe.id_cliente
)
SELECT cl.nombre, cl.apellido, t.total_gastado,
       (SELECT COUNT(*) + 1 FROM totales o
         WHERE o.total_gastado > t.total_gastado) AS puesto
FROM cliente cl
JOIN totales t ON t.id_cliente = cl.id_cliente
ORDER BY puesto;
