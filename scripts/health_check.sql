-- ============================================================================
-- Trabajo Práctico - Parte 3: Monitoreo y Mantenimiento
-- Script: health_check.sql
-- ============================================================================
-- Corrección (Unidad 6 - revisión): las 4 consultas usaban el literal
-- 'food_store' (con guion bajo) en vez de 'foodstore', que es el nombre
-- real de la base del proyecto (ver TPUnidad_6_Mantenimiento_FoodStore.pdf
-- y schema.sql). Verificado de forma empírica contra la base real:
--   - Consulta 1 (tamaño de base): rompía con
--     ERROR: database "food_store" does not exist
--   - Consulta 2 (conexiones/transacciones): no rompía, pero devolvía 0
--     filas de forma silenciosa -- parecía "sin actividad" cuando en
--     realidad el filtro WHERE datname = 'food_store' simplemente no
--     coincidía con ninguna fila de pg_stat_database.
-- Es decir, 2 de los 4 controles exigidos por la consigna fallaban o
-- mentían. Las 4 consultas quedan corregidas abajo con 'foodstore'.
-- ============================================================================

-- 1. Control de Tamaño de la Base de Datos
SELECT pg_size_pretty(pg_database_size('foodstore')) AS tamano_base_datos;

-- 2. Actividad de Conexiones y Transacciones
SELECT numbackends AS conexiones_activas,
       xact_commit AS transacciones_commits,
       xact_rollback AS transacciones_rollbacks
FROM pg_stat_database
WHERE datname = 'foodstore';

-- 3. Estado de Tablas (Identificación de tuplas muertas para ver necesidad de Vacuum)
SELECT relname AS tabla,
       n_live_tup AS tuplas_vivas,
       n_dead_tup AS tuplas_muertas,
       last_autovacuum,
       last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

-- 4. Consultas Activas (Excluyendo conexiones en estado 'idle')
SELECT pid,
       state,
       now() - query_start AS duracion,
       query
FROM pg_stat_activity
WHERE datname = 'foodstore' AND state <> 'idle';
