PRAGMA foreign_keys = ON;
-- =====================================================================
-- Consigna 1.c · Probar la base de la tablet
-- Requiere: schema_sqlite.sql + cargar_snapshot.sql ya corridos.
-- Correr desde movil/:  sqlite3 foodstore_movil.db < pruebas_sqlite.sql
-- Los errores de la parte 3 son ESPERADOS (el script sigue corriendo).
-- =====================================================================
.headers on
.mode box

-- ---------------------------------------------------------------------
-- 1) Borrador completo con BEGIN … COMMIT (borrador + ítems + solicitud)
-- ---------------------------------------------------------------------
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('b0b0b0b0-1111-4aaa-8aaa-000000000001', 'cliente_feria_01', 'EFECTIVO');

-- El precio "visto" se copia del catálogo local en el momento de armar el pedido
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'b0b0b0b0-1111-4aaa-8aaa-000000000001', id, 1, precio_centavos
FROM producto_cache WHERE id IN (2, 3);           -- lomito + pizza

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('5a5a5a5a-0000-4bbb-9bbb-000000000001', 'b0b0b0b0-1111-4aaa-8aaa-000000000001');
COMMIT;

SELECT 'COMMIT ok' AS prueba, b.id_local, count(i.producto_id) AS items,
       sum(i.cantidad * i.precio_centavos_visto) AS total_centavos_visto, c.estado
FROM pedido_borrador b
JOIN item_borrador i ON i.id_local = b.id_local
JOIN cola_sync c     ON c.id_local = b.id_local
WHERE b.id_local = 'b0b0b0b0-1111-4aaa-8aaa-000000000001'
GROUP BY b.id_local, c.estado;

-- ... y otra operación deshecha con ROLLBACK (el cliente se arrepiente)
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('b0b0b0b0-1111-4aaa-8aaa-000000000099', 'cliente_feria_99', 'TARJETA');
INSERT INTO item_borrador VALUES ('b0b0b0b0-1111-4aaa-8aaa-000000000099', 1, 2, 550000);
SELECT 'dentro de la transacción' AS momento, count(*) AS borradores_99
FROM pedido_borrador WHERE id_local = 'b0b0b0b0-1111-4aaa-8aaa-000000000099';
ROLLBACK;
SELECT 'después del ROLLBACK' AS momento, count(*) AS borradores_99
FROM pedido_borrador WHERE id_local = 'b0b0b0b0-1111-4aaa-8aaa-000000000099';

-- ---------------------------------------------------------------------
-- 2) Caso C1 · Catálogo disponible SIN conexión al servidor
--    Solo lee producto_cache (archivo local). No hay ninguna conexión
--    a PostgreSQL en este script.
-- ---------------------------------------------------------------------
SELECT 'C1' AS caso, id, nombre,
       printf('$ %.2f', precio_centavos / 100.0) AS precio,
       stock_visto, copiado_en
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY nombre;

-- ---------------------------------------------------------------------
-- 3) Caso C7 · Datos inválidos: dan error y NO dejan filas nuevas
-- ---------------------------------------------------------------------
SELECT 'C7 antes' AS momento,
       (SELECT count(*) FROM pedido_borrador) AS borradores,
       (SELECT count(*) FROM item_borrador)   AS items,
       (SELECT count(*) FROM cola_sync)       AS solicitudes;

-- 3.a) Cantidad en 0 -> CHECK constraint failed
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c7c7c7c7-0000-4ccc-8ccc-000000000001', 'cliente_feria_c7', 'EFECTIVO');
INSERT INTO item_borrador VALUES ('c7c7c7c7-0000-4ccc-8ccc-000000000001', 1, 0, 550000);
ROLLBACK;   -- el ítem falló: se deshace también el encabezado

-- 3.b) Producto inexistente (id 999) -> FOREIGN KEY constraint failed
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c7c7c7c7-0000-4ccc-8ccc-000000000002', 'cliente_feria_c7', 'EFECTIVO');
INSERT INTO item_borrador VALUES ('c7c7c7c7-0000-4ccc-8ccc-000000000002', 999, 1, 100000);
ROLLBACK;

-- 3.c) Extra: forma de pago inválida -> CHECK constraint failed
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c7c7c7c7-0000-4ccc-8ccc-000000000003', 'cliente_feria_c7', 'CHEQUE');

SELECT 'C7 después' AS momento,
       (SELECT count(*) FROM pedido_borrador) AS borradores,
       (SELECT count(*) FROM item_borrador)   AS items,
       (SELECT count(*) FROM cola_sync)       AS solicitudes;
