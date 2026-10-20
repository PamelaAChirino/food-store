-- ============================================================================
-- Trabajo Práctico - Parte 3: Monitoreo y Mantenimiento
-- Script: maintenance.sql
-- ============================================================================
-- Corrección (Unidad 6 - revisión): la versión original ejecutaba ANALYZE
-- sobre una lista fija de tablas ('producto', 'pedido', 'pedido_producto',
-- 'cliente') con una justificación genérica que no citaba ningún valor real
-- del PASO 1. La consigna exige explícitamente que la acción de
-- mantenimiento esté justificada por la observación previa del estado real
-- de las tablas, no por una lista hardcodeada que puede quedar
-- desactualizada (por ejemplo, si 'categoria' empieza a acumular tuplas
-- muertas y nunca se la incluye porque no estaba en la lista original).
--
-- La corrección reemplaza la lista fija por un bloque PL/pgSQL que lee el
-- resultado del PASO 1 (pg_stat_user_tables) y ejecuta ANALYZE únicamente
-- sobre las tablas cuyo porcentaje de tuplas muertas supera un umbral
-- (10%), documentando en el mensaje de salida *cuál* fue el valor
-- observado que disparó la acción sobre cada tabla. Así la Parte 2 queda
-- atada en código -- no solo en comentario -- a lo que mostró la Parte 1.
-- ============================================================================

-- PASO 1: Revisión y diagnóstico previo del estado de las tablas
-- Permite observar el porcentaje de tuplas muertas antes de tomar una acción
SELECT relname AS tabla,
       n_live_tup,
       n_dead_tup,
       COALESCE(round(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2), 0) AS porcentaje_muertas
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- PASO 2: Acción de mantenimiento segura y justificada, atada al PASO 1
-- Justificación:
-- Se ejecuta ANALYZE (no VACUUM FULL, prohibido como mantenimiento
-- periódico por la consigna) únicamente sobre las tablas donde el PASO 1
-- mostró un porcentaje de tuplas muertas por encima del umbral del 10%.
-- ANALYZE es seguro para producción porque no toma bloqueos exclusivos de
-- tabla (a diferencia de VACUUM FULL) y permite que la aplicación siga
-- operando mientras se actualizan las estadísticas del planificador. El
-- umbral evita trabajo innecesario sobre tablas que el PASO 1 ya mostró
-- sanas, y evita depender de una lista de nombres fija que puede quedar
-- desactualizada si cambia el patrón de uso de la base.
DO $$
DECLARE
    r RECORD;
    umbral CONSTANT numeric := 10.0;
    pct numeric;
BEGIN
    FOR r IN
        SELECT relname, n_live_tup, n_dead_tup
        FROM pg_stat_user_tables
    LOOP
        pct := COALESCE(round(r.n_dead_tup * 100.0 / NULLIF(r.n_live_tup + r.n_dead_tup, 0), 2), 0);
        IF pct > umbral THEN
            RAISE NOTICE 'ANALYZE %: % %% de tuplas muertas observado en PASO 1 (umbral %%%), se analiza.',
                r.relname, pct, umbral;
            EXECUTE format('ANALYZE VERBOSE %I', r.relname);
        ELSE
            RAISE NOTICE 'Se omite %: % %% de tuplas muertas (por debajo del umbral %%%), no requiere ANALYZE ahora.',
                r.relname, pct, umbral;
        END IF;
    END LOOP;
END $$;
