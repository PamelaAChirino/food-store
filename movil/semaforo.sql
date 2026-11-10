PRAGMA foreign_keys = ON;
-- =====================================================================
-- Consigna 2.b · El semáforo (simulación de sincronización)
-- Compara cada solicitud PENDIENTE con snapshot_servidor (la última
-- instantánea de PostgreSQL) y guarda en cola_sync el estado y el motivo:
--   ROJO     RECHAZADO          producto inexistente, no disponible,
--                               dado de baja o sin stock suficiente
--   AMARILLO CONFLICTO          no hay rojo, pero cambió algún precio
--   VERDE    SIMULADO_APROBADO  todo coincide (¡NO es una venta!)
-- Solo toca solicitudes PENDIENTE: repetir la simulación no cambia nada.
-- No se conecta ni modifica nada en PostgreSQL.
-- Correr desde movil/:  sqlite3 foodstore_movil.db < semaforo.sql
-- =====================================================================
.headers on
.mode box

BEGIN;

WITH evaluacion AS (
    SELECT c.solicitud_uuid,
           count(i.producto_id)                                        AS items,
           -- ROJO: se cuenta cada ítem con algún problema
           sum(CASE WHEN s.id IS NULL           THEN 1 ELSE 0 END)     AS inexistentes,
           sum(CASE WHEN s.eliminado  = 't'     THEN 1 ELSE 0 END)     AS dados_de_baja,
           sum(CASE WHEN s.disponible = 'f'     THEN 1 ELSE 0 END)     AS no_disponibles,
           sum(CASE WHEN i.cantidad   > s.stock THEN 1 ELSE 0 END)     AS sin_stock,
           -- AMARILLO
           sum(CASE WHEN i.precio_centavos_visto <> s.precio_centavos
                    THEN 1 ELSE 0 END)                                 AS precios_cambiados,
           -- Motivo legible, un renglón por ítem con problema
           group_concat(
             CASE
               WHEN s.id IS NULL           THEN 'producto ' || i.producto_id || ' no existe en el servidor'
               WHEN s.eliminado  = 't'     THEN 'producto ' || i.producto_id || ' dado de baja'
               WHEN s.disponible = 'f'     THEN 'producto ' || i.producto_id || ' no disponible'
               WHEN i.cantidad   > s.stock THEN 'producto ' || i.producto_id || ' sin stock (pide '
                                                || i.cantidad || ', hay ' || s.stock || ')'
               WHEN i.precio_centavos_visto <> s.precio_centavos
                                           THEN 'producto ' || i.producto_id || ' cambió de precio ('
                                                || i.precio_centavos_visto || ' -> ' || s.precio_centavos || ' cent.)'
             END, '; ')                                                AS detalle,
           max(s.fecha_snapshot)                                       AS fecha_snapshot
    FROM cola_sync c
    LEFT JOIN item_borrador     i ON i.id_local = c.id_local
    LEFT JOIN snapshot_servidor s ON s.id       = i.producto_id
    WHERE c.estado = 'PENDIENTE'
    GROUP BY c.solicitud_uuid
)
UPDATE cola_sync
SET estado = CASE
                 WHEN e.items = 0
                   OR e.inexistentes + e.dados_de_baja + e.no_disponibles + e.sin_stock > 0
                                            THEN 'RECHAZADO'
                 WHEN e.precios_cambiados > 0 THEN 'CONFLICTO'
                 ELSE 'SIMULADO_APROBADO'
             END,
    motivo = CASE
                 WHEN e.items = 0 THEN 'borrador sin ítems'
                 WHEN e.detalle IS NULL THEN 'coincide con la instantánea del ' || e.fecha_snapshot
                 ELSE e.detalle
             END,
    evaluada_en = datetime('now', 'localtime')
FROM evaluacion e
WHERE cola_sync.solicitud_uuid = e.solicitud_uuid
  AND cola_sync.estado = 'PENDIENTE';

SELECT changes() AS solicitudes_evaluadas_ahora;

COMMIT;

-- Resultado del semáforo
SELECT CASE estado WHEN 'RECHAZADO'         THEN 'ROJO'
                   WHEN 'CONFLICTO'         THEN 'AMARILLO'
                   WHEN 'SIMULADO_APROBADO' THEN 'VERDE'
                   ELSE 'SIN EVALUAR' END AS semaforo,
       solicitud_uuid, id_local, estado, motivo
FROM cola_sync
ORDER BY creada_en, solicitud_uuid;
