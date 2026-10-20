-- ============================================================================
-- Trabajo Práctico Unidad 5 - Parte A: Roles y Permisos de Mínimo Privilegio
-- Script: roles.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================

-- 1. Eliminación segura de roles existentes validando su existencia mediante PL/pgSQL
-- Nota de corrección: PostgreSQL NO admite "DROP ROLE ... CASCADE" (a diferencia
-- de DROP TABLE); solo DROP OWNED BY admite CASCADE. La versión original de este
-- bloque usaba DROP ROLE IF EXISTS ... CASCADE, que es un error de sintaxis y
-- aborta la limpieza (detectado al re-ejecutar el script sobre una base donde
-- los roles ya existían). Se reemplaza por el patrón correcto: primero se
-- transfieren/eliminan los objetos que el rol posee (DROP OWNED BY ... CASCADE),
-- y recién entonces se elimina el rol.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT rolname FROM pg_roles WHERE rolname IN ('app_web', 'admin_datos', 'rol_app_lectura', 'rol_app_escritura', 'rol_reportes', 'rol_soporte')
    LOOP
        EXECUTE 'DROP OWNED BY ' || quote_ident(r.rolname) || ' CASCADE';
        EXECUTE 'DROP ROLE IF EXISTS ' || quote_ident(r.rolname);
    END LOOP;
END $$;

-- 2. Creación de Roles de Grupo (Nologin)
CREATE ROLE rol_app_lectura NOLOGIN;
CREATE ROLE rol_app_escritura NOLOGIN;
CREATE ROLE rol_reportes NOLOGIN;
CREATE ROLE rol_soporte NOLOGIN;

-- 3. Creación de Roles de Login (Autenticación)
CREATE ROLE app_web WITH LOGIN PASSWORD 'app_web_password_2026';
CREATE ROLE admin_datos WITH LOGIN PASSWORD 'admin_datos_password_2026';

-- 4. Asignación de Permisos de Esquema
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura, rol_reportes, rol_soporte;

-- 5. Asignación Fina de Permisos sobre Tablas Reales de Food Store
GRANT SELECT ON producto, categoria TO rol_app_lectura;
GRANT SELECT (id_cliente, nombre, apellido, telefono, email) ON cliente TO rol_app_lectura;

GRANT SELECT, INSERT, UPDATE ON pedido, pedido_producto, cliente TO rol_app_escritura;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_app_escritura;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_reportes;
-- mv_top_categorias_dia se crea en scripts/tp_desnormalizacion_top_categorias.sql
-- (Unidad 4). Se otorga el permiso solo si ya existe, para que este script no
-- falle si se ejecuta de forma aislada sin haber corrido antes esa Unidad.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_top_categorias_dia') THEN
        EXECUTE 'GRANT SELECT ON mv_top_categorias_dia TO rol_reportes';
    END IF;
END $$;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_soporte;

-- 5.b. Permisos sobre la tabla "usuario" (agregada en esta Unidad 5 para dar
--      soporte a fn_autenticar y al simulacro de incidente de la Parte C).
--      Igual que con "cliente", se restringe a nivel de columna: ningún rol
--      de aplicación puede leer password_hash. app_web la necesita para su
--      propio flujo de login/perfil (lectura de usuarios propios); lo que
--      la Parte C demuestra es que ese permiso legítimo puede ser *abusado*
--      para una lectura masiva, lo cual el control de acceso por sí solo no
--      puede impedir -- por eso hace falta la auditoría de la Parte B.
GRANT SELECT (id_usuario, nombre_usuario, nombre_completo, email, rol, activo, fecha_alta)
    ON usuario TO rol_app_lectura;
GRANT SELECT ON usuario TO rol_reportes, rol_soporte;
-- usuario_anon se crea en la Parte D (sql/usuario_anon.sql); se otorga el
-- permiso solo si ya existe, por el mismo motivo que mv_top_categorias_dia.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'usuario_anon') THEN
        EXECUTE 'GRANT SELECT ON usuario_anon TO rol_app_lectura, rol_reportes, rol_soporte';
    END IF;
END $$;

-- 6. Herencia de Roles de Grupo a Roles de Login
GRANT rol_app_lectura, rol_app_escritura TO app_web;
GRANT rol_soporte, rol_reportes TO admin_datos;

-- 7. Configuración de Privilegios por Defecto (ALTER DEFAULT PRIVILEGES)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO rol_app_lectura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO rol_app_escritura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO rol_reportes;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO rol_soporte;

-- ============================================================================
-- Verificación (Parte A, punto 3): \du y information_schema.role_table_grants
-- Salida real capturada en docs/verificacion_permisos.txt
-- ============================================================================
