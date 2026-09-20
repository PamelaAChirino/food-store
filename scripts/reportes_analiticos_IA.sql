--=============================================================================

-- BASE DE DATOS II - TRABAJO PRÁCTICO 4

-- Alumnos: Pamela Chirino, Lucas Agüero, Mayra Mulé

-- =============================================================================



-- =============================================================================

-- PARTE 1: CONSULTAS ANALÍTICAS LENTAS (LABORATORIO)

-- =============================================================================



-- 1.1 Facturación por categoría y mes (Consulta Base sin filtro)

EXPLAIN ANALYZE

SELECT 

    c.nombre AS categoria,

    TO_CHAR(pe.fecha, 'YYYY-MM') AS mes,

    SUM(pp.cantidad * pp.precio_unitario) AS total_facturado

FROM categoria c

JOIN producto p ON p.id_categoria = c.id_categoria

JOIN pedido_producto pp ON pp.id_producto = p.id_producto

JOIN pedido pe ON pe.id_pedido = pp.id_pedido

GROUP BY c.nombre, TO_CHAR(pe.fecha, 'YYYY-MM')

ORDER BY mes, total_facturado DESC;



-- Prueba de índice sugerido por IA (Parte 1.2 - No mejoró por baja selectividad / caché)

CREATE INDEX IF NOT EXISTS idx_pedido_producto_producto ON pedido_producto(id_producto);





-- 1.2 Facturación por categoría en un mes específico (Con filtro de fecha)

EXPLAIN ANALYZE

SELECT 

    c.nombre AS categoria,

    TO_CHAR(pe.fecha, 'YYYY-MM') AS mes,

    SUM(pp.cantidad * pp.precio_unitario) AS total_facturado

FROM categoria c

JOIN producto p ON p.id_categoria = c.id_categoria

JOIN pedido_producto pp ON pp.id_producto = p.id_producto

JOIN pedido pe ON pe.id_pedido = pp.id_pedido

WHERE pe.fecha >= '2024-03-01' AND pe.fecha < '2024-04-01'

GROUP BY c.nombre, TO_CHAR(pe.fecha, 'YYYY-MM')

ORDER BY total_facturado DESC;



-- Prueba de índice sobre fecha sugerido por IA (Parte 1.2 - Empeoró por Bitmap Heap Scan)

CREATE INDEX IF NOT EXISTS idx_pedido_fecha ON pedido(fecha);





-- =============================================================================

-- PARTE 2: CONSULTA DE HISTORIAL DE CLIENTE (nested loops analizados)

-- =============================================================================



EXPLAIN ANALYZE

SELECT 

    cl.nombre,

    cl.apellido,

    pe.fecha,

    p.nombre AS producto,

    pp.cantidad,

    pp.precio_unitario

FROM cliente cl

JOIN pedido pe ON pe.id_cliente = cl.id_cliente

JOIN pedido_producto pp ON pp.id_pedido = pe.id_pedido

JOIN producto p ON p.id_producto = pp.id_producto

WHERE cl.email = 'usuario_12345@foodstore.com'

ORDER BY pe.fecha DESC;





-- =============================================================================

-- PARTE 3: RANKING DE CLIENTES Y VERIFICACIÓN DE EQUIVALENCIA (EXCEPT)

-- =============================================================================



-- Versión 1: Función de ventana RANK()

CREATE OR REPLACE VIEW v_ranking_rank AS

WITH totales AS (

    SELECT pe.id_cliente, SUM(pp.cantidad * pp.precio_unitario) AS total_gastado

    FROM pedido pe

    JOIN pedido_producto pp ON pp.id_pedido = pe.id_pedido

    GROUP BY pe.id_cliente

)

SELECT cl.nombre, cl.apellido, t.total_gastado,

       RANK() OVER (ORDER BY t.total_gastado DESC) AS puesto

FROM cliente cl

JOIN totales t ON t.id_cliente = cl.id_cliente;



-- Versión 2: Subconsulta correlacionada (Sin RANK)

CREATE OR REPLACE VIEW v_ranking_subconsulta AS

WITH totales AS (

    SELECT pe.id_cliente, SUM(pp.cantidad * pp.precio_unitario) AS total_gastado

    FROM pedido pe

    JOIN pedido_producto pp ON pp.id_pedido = pe.id_pedido

    GROUP BY pe.id_cliente

)

SELECT cl.nombre, cl.apellido, t.total_gastado,

       (SELECT COUNT(*) + 1 FROM totales o WHERE o.total_gastado > t.total_gastado) AS puesto

FROM cliente cl

JOIN totales t ON t.id_cliente = cl.id_cliente;



-- Verificación de equivalencia estricta (Debe devolver 0 filas en ambos sentidos)

(SELECT * FROM v_ranking_rank) EXCEPT (SELECT * FROM v_ranking_subconsulta);

(SELECT * FROM v_ranking_subconsulta) EXCEPT (SELECT * FROM v_ranking_rank);





-- =============================================================================

-- PARTE 4: ESTRATEGIA DE OPTIMIZACIÓN (PRE-AGREGACIÓN VÍA CTE)

-- =============================================================================



EXPLAIN ANALYZE

WITH ventas_preagregadas AS (

    SELECT 

        id_pedido,

        id_producto,

        SUM(cantidad * precio_unitario) AS subtotal

    FROM pedido_producto

    GROUP BY id_pedido, id_producto

)

SELECT 

    c.nombre AS categoria,

    TO_CHAR(pe.fecha, 'YYYY-MM') AS mes,

    SUM(vp.subtotal) AS total_facturado

FROM ventas_preagregadas vp

JOIN pedido pe ON pe.id_pedido = vp.id_pedido

JOIN producto p ON p.id_producto = vp.id_producto

JOIN categoria c ON c.id_categoria = p.id_categoria

GROUP BY c.nombre, TO_CHAR(pe.fecha, 'YYYY-MM')

ORDER BY mes, total_facturado DESC; 

