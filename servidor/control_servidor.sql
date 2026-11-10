-- =====================================================================
-- Consigna 2.c · Control en PostgreSQL: pedidos y stock NO cambian
-- Se corre ANTES de los casos y DESPUÉS de todo. Las dos salidas tienen
-- que ser iguales: la tablet no crea pedidos ni descuenta stock.
-- =====================================================================
SELECT (SELECT count(*) FROM pedido)          AS cant_pedidos,
       (SELECT count(*) FROM detalle_pedido)  AS cant_detalles,
       (SELECT sum(stock) FROM producto)      AS stock_total,
       (SELECT md5(string_agg(id || ':' || stock, ',' ORDER BY id)) FROM producto) AS huella_stock;
