PRAGMA foreign_keys = ON;
-- =====================================================================
-- Consigna 2.c · Paso 1: borradores de los casos C2 a C5
-- Se arman con la instantánea INICIAL (precios y stock "vistos").
-- Cada borrador queda con su solicitud PENDIENTE en cola_sync.
-- Todavía NO se corre el semáforo: primero cambia el servidor.
-- =====================================================================
.headers on
.mode box

BEGIN;
-- C2: 2 hamburguesas (después se sube el precio en el servidor)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c2c2c2c2-0000-4ddd-8ddd-000000000001', 'cliente_feria_c2', 'TARJETA');
INSERT INTO item_borrador
SELECT 'c2c2c2c2-0000-4ddd-8ddd-000000000001', id, 2, precio_centavos FROM producto_cache WHERE id = 1;
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('5a5a5a5a-0000-4bbb-9bbb-0000000000c2', 'c2c2c2c2-0000-4ddd-8ddd-000000000001');

-- C3: 50 empanadas (en el servidor quedan 40)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c3c3c3c3-0000-4ddd-8ddd-000000000001', 'cliente_feria_c3', 'EFECTIVO');
INSERT INTO item_borrador
SELECT 'c3c3c3c3-0000-4ddd-8ddd-000000000001', id, 50, precio_centavos FROM producto_cache WHERE id = 4;
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('5a5a5a5a-0000-4bbb-9bbb-0000000000c3', 'c3c3c3c3-0000-4ddd-8ddd-000000000001');

-- C4: 1 choripán (después se da de baja en el servidor)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c4c4c4c4-0000-4ddd-8ddd-000000000001', 'cliente_feria_c4', 'TRANSFERENCIA');
INSERT INTO item_borrador
SELECT 'c4c4c4c4-0000-4ddd-8ddd-000000000001', id, 1, precio_centavos FROM producto_cache WHERE id = 5;
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('5a5a5a5a-0000-4bbb-9bbb-0000000000c4', 'c4c4c4c4-0000-4ddd-8ddd-000000000001');

-- C5: 3 aguas + 1 papas (no cambia nada)
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('c5c5c5c5-0000-4ddd-8ddd-000000000001', 'cliente_feria_c5', 'EFECTIVO');
INSERT INTO item_borrador
SELECT 'c5c5c5c5-0000-4ddd-8ddd-000000000001', id, CASE id WHEN 7 THEN 3 ELSE 1 END, precio_centavos
FROM producto_cache WHERE id IN (6, 7);
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('5a5a5a5a-0000-4bbb-9bbb-0000000000c5', 'c5c5c5c5-0000-4ddd-8ddd-000000000001');
COMMIT;

SELECT b.usuario, i.producto_id, p.nombre, i.cantidad, i.precio_centavos_visto, c.solicitud_uuid, c.estado
FROM pedido_borrador b
JOIN item_borrador i  ON i.id_local = b.id_local
JOIN producto_cache p ON p.id = i.producto_id
JOIN cola_sync c      ON c.id_local = b.id_local
WHERE b.usuario LIKE 'cliente_feria_c%'
ORDER BY b.usuario, i.producto_id;
