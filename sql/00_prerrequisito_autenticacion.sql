-- ============================================================================
-- Trabajo Práctico Unidad 5 - Prerrequisito (Clase 1 y 2): Autenticación de
-- aplicación sobre Food Store
-- Script: 00_prerrequisito_autenticacion.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================
--
-- NOTA DE RECONSTRUCCIÓN: la consigna de la Unidad 5 asume que el equipo ya
-- cuenta, de la Clase 2, con las funciones fn_autenticar y fn_resetear_password.
-- Esos artefactos no se conservaron de las clases anteriores, así que se
-- reconstruyen acá como paso previo a la Parte A, dejando constancia de la
-- reconstrucción en BITACORA.md (punto explícito que pide la consigna).
--
-- Diseño: Food Store no modela un login propio por cliente en el esquema real
-- (schema.sql no tiene columna de contraseña). Se agrega una tabla mínima
-- credencial_acceso, separada de cliente, para no tocar el modelo de datos
-- de negocio ya entregado y verificado en TPs anteriores. Guarda únicamente
-- el hash de la contraseña (pgcrypto, bcrypt vía crypt()/gen_salt()), nunca
-- la contraseña en texto plano.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS credencial_acceso (
    id_credencial    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email            VARCHAR(255) NOT NULL UNIQUE,
    password_hash    TEXT NOT NULL,
    intentos_fallidos INT NOT NULL DEFAULT 0,
    bloqueada        BOOLEAN NOT NULL DEFAULT FALSE,
    creada_en        TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizada_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Tabla de intentos de login, independiente del log_auditoria de cambios de
-- datos (Parte B) -- esta registra intentos de AUTENTICACIÓN, exitosos o no.
CREATE TABLE IF NOT EXISTS intento_login (
    id_intento   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email        VARCHAR(255) NOT NULL,
    exitoso      BOOLEAN NOT NULL,
    fecha_hora   TIMESTAMPTZ NOT NULL DEFAULT now(),
    origen       TEXT DEFAULT current_setting('application_name', true)
);

-- fn_autenticar: valida email + password contra el hash guardado. Registra
-- SIEMPRE el intento (exitoso o no) en intento_login. Bloquea la credencial
-- después de 5 intentos fallidos consecutivos.
CREATE OR REPLACE FUNCTION fn_autenticar(p_email VARCHAR, p_password TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_hash        TEXT;
    v_bloqueada   BOOLEAN;
    v_ok          BOOLEAN := FALSE;
BEGIN
    SELECT password_hash, bloqueada INTO v_hash, v_bloqueada
    FROM credencial_acceso
    WHERE email = p_email;

    IF NOT FOUND OR v_bloqueada THEN
        INSERT INTO intento_login (email, exitoso) VALUES (p_email, FALSE);
        RETURN FALSE;
    END IF;

    v_ok := (v_hash = crypt(p_password, v_hash));

    IF v_ok THEN
        UPDATE credencial_acceso
           SET intentos_fallidos = 0, actualizada_en = now()
         WHERE email = p_email;
    ELSE
        UPDATE credencial_acceso
           SET intentos_fallidos = intentos_fallidos + 1,
               bloqueada = (intentos_fallidos + 1 >= 5),
               actualizada_en = now()
         WHERE email = p_email;
    END IF;

    INSERT INTO intento_login (email, exitoso) VALUES (p_email, v_ok);
    RETURN v_ok;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- fn_resetear_password: fija una contraseña nueva y desbloquea la credencial.
CREATE OR REPLACE FUNCTION fn_resetear_password(p_email VARCHAR, p_password_nueva TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE credencial_acceso
       SET password_hash = crypt(p_password_nueva, gen_salt('bf')),
           intentos_fallidos = 0,
           bloqueada = FALSE,
           actualizada_en = now()
     WHERE email = p_email;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Alta de credenciales de prueba para dos clientes existentes (si los hay)
INSERT INTO credencial_acceso (email, password_hash)
SELECT c.email, crypt('ClaveInicial123', gen_salt('bf'))
FROM cliente c
WHERE NOT EXISTS (SELECT 1 FROM credencial_acceso ca WHERE ca.email = c.email)
LIMIT 2
ON CONFLICT (email) DO NOTHING;
