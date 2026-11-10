PRAGMA foreign_keys = ON;
-- =====================================================================
-- Caso C4 · Después de recargar: el choripán no aparece en el catálogo,
-- pero su fila (lápida) sigue en producto_cache.
-- =====================================================================
.headers on
.mode box
SELECT 'catálogo visible' AS vista, id, nombre FROM producto_cache
WHERE disponible = 1 AND eliminado = 0 ORDER BY id;

SELECT 'fila en producto_cache' AS vista, id, nombre, disponible, eliminado, copiado_en
FROM producto_cache WHERE id = 5;
