-- ============================================================================
-- Trabajo Práctico Unidad 5 - Prerrequisito (Clase 1 y 2): tabla de usuarios
-- de aplicación y funciones de autenticación sobre Food Store
-- Script: 00_prerrequisito_autenticacion.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================
--
-- NOTA DE RECONSTRUCCIÓN: la consigna de la Unidad 5 asume que el equipo ya
-- cuenta, de la Clase 1/2, con una tabla de usuarios de aplicación y con las
-- funciones fn_autenticar y fn_resetear_password. Esos artefactos no se
-- conservaron de clases anteriores, así que se reconstruyen acá como paso
-- previo a la Parte A, dejando constancia en BITACORA.md.
--
-- Diseño: se trata de usuarios INTERNOS de Food Store (operadores de la
-- aplicación: soporte, reportes, carga de pedidos), no de clientes finales
-- -- el esquema real de "cliente" (schema.sql) no tiene ni necesita login
-- propio. Cada usuario de "usuario" tiene asignado uno de los roles de
-- grupo de la Parte A (rol_app_lectura / rol_app_escritura / rol_reportes /
-- rol_soporte), lo que permite que la Parte C (lectura masiva de "usuario",
-- intento de escalamiento a admin_datos) se apoye directamente en el mismo
-- esquema de permisos verificado en la Parte A.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS usuario (
    id_usuario         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_usuario      VARCHAR(50) NOT NULL UNIQUE,
    nombre_completo     VARCHAR(150) NOT NULL,
    email               VARCHAR(255) NOT NULL UNIQUE,
    password_hash       TEXT NOT NULL,
    rol                 VARCHAR(50) NOT NULL,   -- nombre del rol de grupo asignado (Parte A)
    activo              BOOLEAN NOT NULL DEFAULT TRUE,
    fecha_alta          TIMESTAMPTZ NOT NULL DEFAULT now(),
    intentos_fallidos   INT NOT NULL DEFAULT 0,
    ultimo_intento      TIMESTAMPTZ
);

-- Registro de intentos de autenticación, independiente de log_auditoria
-- (Parte B, que registra cambios de datos) -- este registra intentos de
-- LOGIN, exitosos o no.
CREATE TABLE IF NOT EXISTS log_autenticacion (
    id_log          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_usuario  VARCHAR(50) NOT NULL,
    exitoso         BOOLEAN NOT NULL,
    fecha_hora      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- fn_autenticar: valida usuario + password contra el hash guardado (bcrypt
-- vía pgcrypto). Registra SIEMPRE el intento en log_autenticacion.
CREATE OR REPLACE FUNCTION fn_autenticar(p_usuario VARCHAR, p_password TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_hash TEXT;
    v_ok   BOOLEAN := FALSE;
BEGIN
    SELECT password_hash INTO v_hash
    FROM usuario
    WHERE nombre_usuario = p_usuario AND activo = TRUE;

    IF v_hash IS NOT NULL AND v_hash = crypt(p_password, v_hash) THEN
        v_ok := TRUE;
    END IF;

    INSERT INTO log_autenticacion (nombre_usuario, exitoso) VALUES (p_usuario, v_ok);

    IF v_ok THEN
        UPDATE usuario SET intentos_fallidos = 0, ultimo_intento = now()
        WHERE nombre_usuario = p_usuario;
    ELSE
        UPDATE usuario SET intentos_fallidos = intentos_fallidos + 1, ultimo_intento = now()
        WHERE nombre_usuario = p_usuario;
    END IF;

    RETURN v_ok;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- fn_resetear_password: fija una contraseña nueva para un usuario existente.
CREATE OR REPLACE FUNCTION fn_resetear_password(p_usuario VARCHAR, p_password_nuevo TEXT)
RETURNS VOID AS $$
BEGIN
    UPDATE usuario
       SET password_hash = crypt(p_password_nuevo, gen_salt('bf')),
           intentos_fallidos = 0
     WHERE nombre_usuario = p_usuario;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Alta de usuarios de prueba, uno por cada rol de grupo de la Parte A
INSERT INTO usuario (nombre_usuario, nombre_completo, email, password_hash, rol, fecha_alta) VALUES
    ('jgarcia',   'Julia Garcia',     'jgarcia@foodstore.test',   crypt('ClaveInicial123', gen_salt('bf')), 'rol_app_lectura',   '2026-08-11'),
    ('mrodrig',   'Marcos Rodriguez', 'mrodrig@foodstore.test',   crypt('ClaveInicial123', gen_salt('bf')), 'rol_app_escritura', '2026-08-26'),
    ('lsoporte',  'Lucia Soporte',    'lsoporte@foodstore.test',  crypt('ClaveInicial123', gen_salt('bf')), 'rol_soporte',       '2026-09-10'),
    ('preportes', 'Pablo Reportes',   'preportes@foodstore.test', crypt('ClaveInicial123', gen_salt('bf')), 'rol_reportes',      '2026-09-30'),
    ('adatos',    'Admin Datos',      'adatos@foodstore.test',    crypt('ClaveInicial123', gen_salt('bf')), 'rol_soporte',       '2026-10-10')
ON CONFLICT (nombre_usuario) DO NOTHING;
