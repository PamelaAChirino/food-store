-- ============================================================================
-- Trabajo Práctico Unidad 5 - Parte C: Simulacro de Incidente de Acceso Indebido
-- Script: simulacro_incidente.sql
-- Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
-- ============================================================================
-- Reescrito para seguir la secuencia exacta que pide la consigna (varios
-- logins fallidos contra fn_autenticar, un login exitoso, una lectura masiva
-- de la tabla "usuario", y un intento de escalamiento de privilegios), que
-- la primera versión de este script no cubría: usaba SET ROLE directo sin
-- pasar por fn_autenticar y no incluía ningún intento de escalamiento.
--
-- Además corrige un hallazgo real detectado al verificar la versión anterior:
-- su "Escenario 3" (admin_datos actualizando cliente) se documentaba como
-- "modificación autorizada" exitosa, pero al ejecutarlo contra los permisos
-- reales de roles.sql falla con "permission denied": admin_datos hereda
-- rol_soporte y rol_reportes, y ninguno de los dos tiene UPDATE sobre
-- ninguna tabla (ambos son de solo lectura). El informe original afirmaba
-- algo que el propio esquema de permisos no permite.
-- ============================================================================

-- 0. Asegurar una contraseña conocida para el usuario de prueba (entorno de
--    desarrollo únicamente)
SELECT fn_resetear_password('mrodrig', 'ClaveSegura2026!');

-- ----------------------------------------------------------------------------
-- 1) Varios intentos fallidos de inicio de sesión contra fn_autenticar
-- ----------------------------------------------------------------------------
SELECT fn_autenticar('mrodrig', 'password_incorrecta_1');
SELECT fn_autenticar('mrodrig', 'password_incorrecta_2');
SELECT fn_autenticar('mrodrig', 'password_incorrecta_3');

-- ----------------------------------------------------------------------------
-- 2) Inicio de sesión exitoso
-- ----------------------------------------------------------------------------
SELECT fn_autenticar('mrodrig', 'ClaveSegura2026!');

-- ----------------------------------------------------------------------------
-- 3) Lectura masiva de la tabla "usuario"
-- app_web SÍ tiene SELECT legítimo sobre columnas no sensibles de usuario
-- (lo necesita para su propio flujo de login/perfil). La lectura masiva no
-- es un error de permisos -- es un USO ANÓMALO de un permiso legítimo, que
-- el control de acceso por sí solo no puede bloquear. Esto es justamente lo
-- que la auditoría de la Parte B debe permitir detectar después.
-- ----------------------------------------------------------------------------
SET ROLE app_web;
SELECT id_usuario, nombre_usuario, nombre_completo, email, rol, activo, fecha_alta
FROM usuario;
RESET ROLE;

-- Nota: un intento de SELECT * (incluyendo password_hash) SÍ falla, porque
-- ese permiso nunca se otorgó a nivel de columna. Se deja como evidencia de
-- que la restricción de columna cumple su función incluso durante el abuso
-- del permiso de lectura:
-- SET ROLE app_web; SELECT * FROM usuario; RESET ROLE;
-- => ERROR: permission denied for table usuario

-- ----------------------------------------------------------------------------
-- 4) Intento de escalamiento: otorgarle a un rol de bajo privilegio
--    membresía en admin_datos
-- ----------------------------------------------------------------------------
SET ROLE app_web;
GRANT admin_datos TO app_web;
RESET ROLE;

-- ----------------------------------------------------------------------------
-- VERIFICACIÓN DEL ESCALAMIENTO (debe fallar)
-- ----------------------------------------------------------------------------
-- Resultado real obtenido: ERROR: permission denied to grant role "admin_datos"
-- El esquema de permisos de la Parte A funciona como se espera: app_web no
-- tiene la opción ADMIN sobre admin_datos, así que el intento de
-- escalamiento es rechazado por el motor. No se detectó ningún defecto que
-- permitiera el escalamiento.

-- ----------------------------------------------------------------------------
-- VERIFICACIÓN EN BITÁCORA DE AUTENTICACIÓN
-- ----------------------------------------------------------------------------
SELECT id_log, nombre_usuario, exitoso, fecha_hora
FROM log_autenticacion
ORDER BY id_log;
