-- =====================================================================
-- Consigna 2.c · Paso 2: cambios en la COPIA DE PRUEBAS del servidor
-- Los hace el administrador en PostgreSQL (no la tablet).
-- No tocan pedidos ni stock.
-- =====================================================================
BEGIN;
-- C2: sube el precio de la hamburguesa (5500 -> 6000)
UPDATE producto SET precio = 6000.00, actualizado_en = now() WHERE id = 1;
-- C4: baja lógica del choripán (la fila queda, eliminado = true)
UPDATE producto SET eliminado = TRUE, disponible = FALSE, actualizado_en = now() WHERE id = 5;
COMMIT;

SELECT id, nombre, precio, stock, disponible, eliminado FROM producto WHERE id IN (1, 4, 5) ORDER BY id;
