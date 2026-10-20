-- ============================================================================
-- Trabajo Práctico Unidad 5 - Parte A: Roles y Permisos de Mínimo Privilegio
-- Script: roles.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================

-- 1. Eliminación segura de roles existentes validando su existencia mediante PL/pgSQL
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT rolname FROM pg_roles WHERE rolname IN ('app_web', 'admin_datos', 'rol_app_lectura', 'rol_app_escritura', 'rol_reportes', 'rol_soporte') 
    LOOP
        EXECUTE 'DROP ROLE IF EXISTS ' || quote_ident(r.rolname) || ' CASCADE';
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
GRANT SELECT ON mv_top_categorias_dia TO rol_reportes;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO rol_soporte;

-- 6. Herencia de Roles de Grupo a Roles de Login
GRANT rol_app_lectura, rol_app_escritura TO app_web;
GRANT rol_soporte, rol_reportes TO admin_datos;

-- 7. Configuración de Privilegios por Defecto (ALTER DEFAULT PRIVILEGES)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO rol_app_lectura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO rol_app_escritura;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO rol_reportes;