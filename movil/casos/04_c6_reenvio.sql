PRAGMA foreign_keys = ON;
-- =====================================================================
-- Caso C6 · Reenviar la misma solicitud (mismo UUID que C5)
-- Esperado: UNIQUE constraint failed: cola_sync.solicitud_uuid
-- (el error es ESPERADO) y la cola no cambia.
-- =====================================================================
.headers on
.mode box
SELECT 'antes' AS momento, count(*) AS solicitudes FROM cola_sync;

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('5a5a5a5a-0000-4bbb-9bbb-0000000000c5', 'c5c5c5c5-0000-4ddd-8ddd-000000000001');

SELECT 'después' AS momento, count(*) AS solicitudes FROM cola_sync;
SELECT solicitud_uuid, estado, evaluada_en FROM cola_sync
WHERE solicitud_uuid = '5a5a5a5a-0000-4bbb-9bbb-0000000000c5';
