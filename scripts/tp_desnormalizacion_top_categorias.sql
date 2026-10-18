-- ============================================================================
-- Trabajo Práctico Unidad 4 - Parte 2: Desnormalización Controlada (Top Categorías)
-- Script: tp_desnormalizacion_top_categorias.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================

-- Creación de la estructura desnormalizada y sincronización
DROP MATERIALIZED VIEW IF EXISTS mv_top_categorias_dia;

CREATE MATERIALIZED VIEW mv_top_categorias_dia AS
SELECT ped.fecha::date                       AS fecha,
       c.nombre                              AS categoria,
       SUM(pp.cantidad * pp.precio_unitario) AS total_vendido
FROM pedido_producto pp
JOIN producto  pr  ON pr.id_producto  = pp.id_producto
JOIN categoria c   ON c.id_categoria  = pr.id_categoria
JOIN pedido    ped ON ped.id_pedido   = pp.id_pedido
GROUP BY ped.fecha::date, c.nombre
WITH DATA;

CREATE UNIQUE INDEX ux_mv_top_cat_dia
    ON mv_top_categorias_dia (fecha, categoria);

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_categorias_dia;

-- ============================================================================
-- 1) EXPLAIN ANALYZE de la consulta original
-- ============================================================================
EXPLAIN ANALYZE
SELECT c.nombre AS categoria,
       SUM(pp.cantidad * pp.precio_unitario) AS total_vendido
FROM pedido_producto pp
JOIN producto pr ON pr.id_producto = pp.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido ped ON ped.id_pedido = pp.id_pedido
WHERE ped.fecha >= '2026-09-15'::date AND ped.fecha < '2026-09-15'::date + INTERVAL '1 day'
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

-- ============================================================================
-- 2) EXPLAIN ANALYZE de la consulta optimizada (leyendo de la vista)
-- ============================================================================
EXPLAIN ANALYZE
SELECT categoria, total_vendido
FROM mv_top_categorias_dia
WHERE fecha = '2026-09-15'
ORDER BY total_vendido DESC
LIMIT 5;

-- ============================================================================
-- 3) Script de auditoría (debe retornar 0 filas)
-- ============================================================================
SELECT
    v.categoria,
    v.total_vendido AS valor_materializado,
    COALESCE(r.total_real, 0) AS valor_real
FROM mv_top_categorias_dia v
FULL OUTER JOIN (
    SELECT c.nombre AS categoria, SUM(pp.cantidad * pp.precio_unitario) AS total_real
    FROM pedido_producto pp
    JOIN producto pr ON pr.id_producto = pp.id_producto
    JOIN categoria c ON c.id_categoria = pr.id_categoria
    JOIN pedido ped ON ped.id_pedido = pp.id_pedido
    WHERE ped.fecha >= '2026-09-15'::date AND ped.fecha < '2026-09-15'::date + INTERVAL '1 day'
    GROUP BY c.nombre
) r ON r.categoria = v.categoria
WHERE v.fecha = '2026-09-15'
  AND (v.total_vendido IS DISTINCT FROM r.total_real);

-- ============================================================================
-- 3b) Auditoría ampliada: compara TODAS las fechas y detecta categorías
--     presentes en la fuente pero ausentes (o desincronizadas) en la vista
--     materializada (debe retornar 0 filas cuando la vista está sincronizada)
--
-- Nota: el JOIN se hace por (fecha, categoria) en conjunto -- igual que la
-- clave del índice único de la vista -- y NO solo por categoria como en el
-- punto 3. Si se filtra por fecha recién en el WHERE externo (después del
-- JOIN), una categoría que no tiene ninguna fila en la vista para esa fecha
-- puntual puede emparejarse con una fila de OTRA fecha de la misma
-- categoría, y el filtro externo descarta esa fila -- la auditoría queda
-- en 0 filas aunque falten datos reales. Verificado empíricamente: con una
-- categoría nueva en el día sin refrescar la vista, el script del punto 3
-- no detecta el faltante; este sí.
-- ============================================================================
SELECT
    COALESCE(v.fecha, r.fecha)         AS fecha,
    COALESCE(v.categoria, r.categoria) AS categoria,
    v.total_vendido                    AS valor_materializado,
    COALESCE(r.total_real, 0)          AS valor_real
FROM mv_top_categorias_dia v
FULL OUTER JOIN (
    SELECT ped.fecha::date AS fecha, c.nombre AS categoria,
           SUM(pp.cantidad * pp.precio_unitario) AS total_real
    FROM pedido_producto pp
    JOIN producto  pr  ON pr.id_producto  = pp.id_producto
    JOIN categoria c   ON c.id_categoria  = pr.id_categoria
    JOIN pedido    ped ON ped.id_pedido   = pp.id_pedido
    GROUP BY ped.fecha::date, c.nombre
) r ON r.fecha = v.fecha AND r.categoria = v.categoria
WHERE v.total_vendido IS DISTINCT FROM COALESCE(r.total_real, 0)
ORDER BY fecha, categoria;