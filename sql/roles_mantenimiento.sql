-- ============================================================================
-- Trabajo Práctico Unidad 6 - Roles de Mantenimiento (mínimo privilegio)
-- Script: roles_mantenimiento.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================
-- Contexto / corrección: SPEC_U6.md (Parte 1) especifica dos roles de
-- ejecución para las tareas rutinarias de respaldo y monitoreo -- mant_backup
-- y mant_monitor -- pero ninguno de los scripts entregados originalmente los
-- creaba: backup_food_store.ps1 se conectaba con "-U mant_backup" (línea 13)
-- contra un rol que no existía en ninguna base del clúster. Este script
-- cierra ese hueco, siguiendo el mismo patrón de mínimo privilegio ya usado
-- en sql/roles.sql (Unidad 5).
--
-- Nota de sintaxis (ya corregida una vez en Unidad 5): PostgreSQL no admite
-- "DROP ROLE ... CASCADE"; se usa DROP OWNED BY ... CASCADE y luego
-- DROP ROLE IF EXISTS.
-- ============================================================================

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT rolname FROM pg_roles WHERE rolname IN ('mant_backup', 'mant_monitor')
    LOOP
        EXECUTE 'DROP OWNED BY ' || quote_ident(r.rolname) || ' CASCADE';
        EXECUTE 'DROP ROLE IF EXISTS ' || quote_ident(r.rolname);
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- mant_backup: solo necesita poder CONECTARSE y LEER todos los datos para que
-- pg_dump pueda volcar la base completa. No necesita permisos de escritura,
-- ni de administración de roles, ni ser superusuario.
-- pg_read_all_data es un rol predefinido de PostgreSQL (desde la v14) que
-- otorga SELECT implícito sobre todas las tablas, vistas y secuencias de
-- todas las bases -- exactamente lo mínimo que pg_dump necesita y nada más.
-- ----------------------------------------------------------------------------
CREATE ROLE mant_backup WITH LOGIN PASSWORD 'cambiar_en_produccion_2026' NOSUPERUSER NOCREATEDB NOCREATEROLE;
GRANT CONNECT ON DATABASE foodstore TO mant_backup;
GRANT pg_read_all_data TO mant_backup;

-- ----------------------------------------------------------------------------
-- mant_monitor: solo necesita leer las vistas de estadísticas del sistema
-- (pg_stat_database, pg_stat_user_tables, pg_stat_activity) que usa
-- health_check.sql. pg_monitor es el rol predefinido de PostgreSQL pensado
-- exactamente para esto -- da acceso de lectura a las vistas de monitoreo
-- sin dar acceso a los datos de negocio (no hereda pg_read_all_data).
-- ----------------------------------------------------------------------------
CREATE ROLE mant_monitor WITH LOGIN PASSWORD 'cambiar_en_produccion_2026' NOSUPERUSER NOCREATEDB NOCREATEROLE;
GRANT CONNECT ON DATABASE foodstore TO mant_monitor;
GRANT pg_monitor TO mant_monitor;

-- ----------------------------------------------------------------------------
-- Nota de seguridad (consistente con el criterio "Cero Contraseñas" de
-- SPEC_U6.md, punto 3): la contraseña de arriba es solo para crear el rol
-- por única vez. Los scripts operativos (backup_foodstore.ps1/.sh,
-- health_check.sql) NUNCA la incluyen -- se conectan vía .pgpass, que es
-- donde debe cambiarse por una contraseña real antes de usar en producción:
--   localhost:5432:foodstore:mant_backup:<password_real>
--   localhost:5432:foodstore:mant_monitor:<password_real>
-- ----------------------------------------------------------------------------

-- Verificación (igual que en sql/roles.sql de Unidad 5): \du y
-- pg_roles.rolcanlogin confirman que ambos roles existen, pueden iniciar
-- sesión, y NO son superusuario.
-- Salida real capturada en docs/verificacion_roles_mantenimiento.txt
