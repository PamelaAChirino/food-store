# Bitácora de Uso de IA / OpenCode — Unidad 5 (Trabajo Práctico Food Store)

- **Integrantes del equipo**: Pamela Chirino, Lucas Agüero, Mayra Mulé
- **Fecha de cierre**: Octubre de 2026

---

## 1. Registro de interacciones y validación (Partes A a D)

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación / corrección humana aplicada |
|---|---|---|
| Reconstruir `fn_autenticar` y `fn_resetear_password` (prerrequisito de Clase 2, no conservado de clases anteriores) | Propuso una tabla `credencial_acceso` separada de `cliente` (para no tocar el modelo de negocio ya validado), hash con `pgcrypto`/`crypt()`, bloqueo tras 5 intentos fallidos y registro en `intento_login` | Se verificó que el hash nunca guarda la contraseña en texto plano y que el bloqueo funciona; se probó con una contraseña incorrecta y una correcta antes de usarlo en la Parte C |
| Diseñar y generar el script de roles, esquema, seguridad a nivel de columna y privilegios por defecto adaptado a las tablas reales (`cliente`, `producto`, `categoria`, `pedido`, `pedido_producto`) | Generó `sql/roles.sql` y la especificación inicial en `docs/kiro_roles_spec/requirements.md` y `design.md` | Se revisaron los nombres de columnas reales para que el permiso a nivel de columna sobre `cliente` apuntara a campos existentes |
| Auditar `roles.sql` y proponer mejoras (punto 4 de la Parte A) | **La IA propuso ampliar `rol_soporte`/`rol_reportes` con `UPDATE` para que `admin_datos` pudiera resolver operaciones de mantenimiento sin pedir otro rol** | **El equipo decidió NO aplicarlo**: ampliar esos roles con `UPDATE` es un permiso más amplio del necesario y contradice el principio de mínimo privilegio que es el objetivo de la Parte A. Se mantuvo `admin_datos` de solo lectura. Esta decisión fue la que después expuso el bug real descripto en la fila siguiente |
| Verificar con `\du` y `information_schema.role_table_grants` que cada rol tiene exactamente los privilegios previstos | Devolvió la salida completa de ambas consultas | Se adjuntó en `docs/verificacion_permisos.txt`; se confirmó que las tablas creadas después de `roles.sql` (`credencial_acceso`, `log_auditoria`, `usuario_anon`) heredan la política automáticamente por `ALTER DEFAULT PRIVILEGES` |
| Crear tabla `log_auditoria` (JSONB), función `fn_auditar_cambios` y triggers para auditoría dinámica | Generó `sql/auditoria_test.sql` y el informe correspondiente | Se ejecutó un `UPDATE` sobre `cliente` en DBeaver y se comprobó que `log_auditoria` registró correctamente el estado anterior y posterior |
| Activar parámetros de auditoría del servidor (`log_connections`, `log_disconnections`, `log_statement`) y ejecutar una secuencia de prueba | Propuso `log_statement = 'mod'` (modificaciones, no lecturas) y un `log_line_prefix` con usuario/base/host | Se corrió la secuencia real (lectura, inserción, actualización, login fallido) y se confirmó en el log que las lecturas efectivamente no quedan registradas en este nivel — se documentó como límite conocido, no como falla |
| Generar el escenario de simulacro de incidente siguiendo la secuencia exacta de la consigna (login fallido/exitoso vía `fn_autenticar`, lectura masiva, intento de escalamiento) | Generó `sql/simulacro_incidente.sql` | **Se corrigió la versión anterior del script**, que no usaba `fn_autenticar` y no incluía el intento de escalamiento real (ver "Caso más significativo" abajo) |
| Reconstruir el incidente a partir del log anonimizado, sin contexto adicional | Identificó correctamente el patrón de intentos fallidos + éxito, pero atribuyó el `GRANT` al usuario `postgres` en lugar de a `app_web` (porque `SET ROLE` no queda en el log con `log_statement = mod`), y no detectó la lectura masiva de `cliente` (tampoco queda logueada) | Se contrastó por escrito contra lo realmente ejecutado en `docs/informe_incidente.md`; se identificaron ambos puntos ciegos como limitación del nivel de log, no como invención de la IA |
| Crear/actualizar `usuario_anon` con datos sintéticos deterministas y consulta de agregación equivalente sobre la tabla real | Propuso agrupar por `rol` y por fecha de alta | Se ajustó: `cliente` no tiene columna de fecha de alta ni tabla `usuario`; se usó el mes del primer pedido como proxy razonable, documentado explícitamente, y se verificó con `EXCEPT` en ambas direcciones (0 filas) |

---

## 2. Caso más significativo de error o imprecisión de la IA

El caso más significativo no fue un error de sintaxis, sino uno de **completitud**: la primera versión que se recibió del simulacro de incidente (Parte C) no reproducía la secuencia que pide la consigna. No usaba `fn_autenticar` para los intentos de login (hacía `SET ROLE` directo), no incluía ningún intento de escalamiento de privilegios, y el único "intento no autorizado" que probaba (un `UPDATE` de `admin_datos` sobre `cliente`) en realidad **fallaba contra los permisos reales de `roles.sql`** — el informe decía "operación exitosa" cuando el motor devolvía `permission denied`. Esto se detectó recién al correr el script contra una base de verificación real: el motor rechazó la operación que el informe daba por lograda. La causa raíz fue la decisión (correcta, documentada en la fila de auditoría de roles de la tabla anterior) de no ampliarle `UPDATE` a `admin_datos` — una decisión acertada de seguridad que el script y el informe del incidente no habían actualizado en consecuencia. Se corrigió reescribiendo el simulacro para que seguir la secuencia exacta de la consigna (login vía `fn_autenticar`, lectura masiva, intento real de `GRANT admin_datos TO app_web`) y re-verificando cada paso contra PostgreSQL antes de documentar un resultado.

---

## 3. Nota sobre historial de Git y buenas prácticas

El repositorio refleja el avance modular del trabajo práctico, con commits separados por parte (prerrequisito de autenticación, Parte A, Parte B, Parte C, Parte D, bitácora y reestructuración de carpetas). Como mejora para futuros proyectos, se mantiene la observación ya registrada en la Unidad 4: conviene establecer ramas de trabajo independientes (`feature/parte-a`, `feature/parte-b`, etc.) desde el inicio, para integrar sobre `master` solo cuando cada parte está verificada, en lugar de verificar directamente sobre la rama principal.
