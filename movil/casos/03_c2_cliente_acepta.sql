PRAGMA foreign_keys = ON;
-- =====================================================================
-- Caso C2 · El cliente acepta el precio nuevo
-- Se actualiza el precio visto del borrador con el del catálogo recargado
-- y se genera una solicitud NUEVA (UUID nuevo). La vieja queda en
-- CONFLICTO como historial.
-- =====================================================================
BEGIN;
UPDATE item_borrador
SET precio_centavos_visto = (SELECT p.precio_centavos FROM producto_cache p
                             WHERE p.id = item_borrador.producto_id)
WHERE id_local = 'c2c2c2c2-0000-4ddd-8ddd-000000000001';

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('5a5a5a5a-0000-4bbb-9bbb-0000000002c2', 'c2c2c2c2-0000-4ddd-8ddd-000000000001');
COMMIT;
