PRAGMA foreign_keys = ON;
-- =====================================================================
-- Consigna 2.a · Cargar la instantánea del servidor en la tablet
-- Correr desde la carpeta movil/:  sqlite3 foodstore_movil.db < cargar_snapshot.sql
-- Antes, en psql (PostgreSQL de PRUEBAS):
--   \copy (SELECT * FROM v_snapshot_movil) TO 'movil/servidor_snapshot.csv' CSV HEADER
-- =====================================================================

-- 1) Vaciar la instantánea anterior e importar la nueva
DELETE FROM snapshot_servidor;
.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor

-- 2) Refrescar el catálogo local (upsert). Las lápidas (eliminado = 't')
--    NO se borran: la fila queda marcada para que los borradores viejos
--    sigan teniendo a qué apuntar y el catálogo deje de mostrarla.
BEGIN;
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, copiado_en)
SELECT id, nombre, precio_centavos, stock,
       CASE disponible WHEN 't' THEN 1 ELSE 0 END,
       CASE eliminado  WHEN 't' THEN 1 ELSE 0 END,
       fecha_snapshot
FROM snapshot_servidor
WHERE true
ON CONFLICT (id) DO UPDATE SET
    nombre          = excluded.nombre,
    precio_centavos = excluded.precio_centavos,
    stock_visto     = excluded.stock_visto,
    disponible      = excluded.disponible,
    eliminado       = excluded.eliminado,
    copiado_en      = excluded.copiado_en;
COMMIT;

-- 3) Dejar anotada la fecha de la copia
SELECT 'Instantánea cargada' AS info, count(*) AS productos, max(fecha_snapshot) AS fecha_copia
FROM snapshot_servidor;
