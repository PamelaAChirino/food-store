-- ============================================================================
-- Trabajo Práctico Unidad 5 - Parte C: Simulacro de Incidente de Seguridad
-- Script: simulacro_incidente.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================
-- Se ejecuta EXCLUSIVAMENTE contra el entorno de desarrollo propio.
--
-- Secuencia pedida por la consigna (Parte C, punto 1):
--   1) Varios intentos fallidos de inicio de sesión contra fn_autenticar
--   2) Un inicio de sesión exitoso
--   3) Una lectura masiva de la tabla "usuario" (en Food Store real: cliente,
--      ver nota de adaptación más abajo)
--   4) Un intento de otorgarle a un rol de bajo privilegio membresía en
--      admin_datos (escalamiento)
--
-- NOTA DE ADAPTACIÓN: la consigna nombra una tabla "usuario". El modelo real
-- de Food Store (ver schema.sql, TP1) no tiene una tabla "usuario" genérica;
-- los datos de personas equivalentes están en "cliente". Se usa "cliente" en
-- su lugar para la lectura masiva del punto 3, igual que se hizo en los TPs
-- anteriores de la materia cuando la consigna genérica no coincide 1:1 con el
-- esquema real del proyecto.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) y 2) Intentos de login contra fn_autenticar: varios fallidos y uno exitoso
-- ----------------------------------------------------------------------------
SELECT fn_autenticar('juan@test.com', 'password_incorrecta_1');
SELECT fn_autenticar('juan@test.com', 'password_incorrecta_2');
SELECT fn_autenticar('juan@test.com', 'password_incorrecta_3');
SELECT fn_autenticar('juan@test.com', 'ClaveInicial123');  -- exitoso

-- ----------------------------------------------------------------------------
-- 3) Lectura masiva de "cliente" (adaptación de "usuario", ver nota arriba)
--    Se ejecuta como app_web para que quede con el usuario de aplicación,
--    no con el superusuario de conexión.
-- ----------------------------------------------------------------------------
SET ROLE app_web;
SELECT * FROM cliente;
RESET ROLE;

-- ----------------------------------------------------------------------------
-- 4) ESCALAMIENTO: intento de otorgarle a un rol de bajo privilegio (app_web)
--    membresía en admin_datos.
--    RESULTADO ESPERADO si el diseño de permisos de la Parte A es correcto:
--    debe FALLAR -- app_web no tiene CREATEROLE ni ADMIN OPTION sobre
--    admin_datos, así que no puede otorgarse esa membresía a sí mismo ni a
--    nadie.
-- ----------------------------------------------------------------------------
SET ROLE app_web;
GRANT admin_datos TO app_web;
RESET ROLE;

-- ----------------------------------------------------------------------------
-- Verificación en la bitácora/auditoría de la base de datos: intentos de login
-- ----------------------------------------------------------------------------
SELECT id_intento, email, exitoso, fecha_hora
FROM intento_login
ORDER BY id_intento DESC
LIMIT 10;
