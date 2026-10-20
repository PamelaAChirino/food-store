# Informe de Auditoría — Parte B (Unidad 5)

## 1. Parámetros de servidor activados

Se modificaron en `postgresql.conf` (PostgreSQL 16, entorno de desarrollo propio):

| Parámetro | Valor |
|---|---|
| `logging_collector` | `on` |
| `log_destination` | `stderr` |
| `log_connections` | `on` |
| `log_disconnections` | `on` |
| `log_statement` | `mod` (registra `INSERT`/`UPDATE`/`DELETE`/DDL; no registra `SELECT`) |
| `log_line_prefix` | `'%m [%p] usuario=%u base=%d origen=%h '` |

Se eligió `log_statement = 'mod'` como nivel permanente (en vez de `'all'`) porque registrar cada `SELECT` tiene un costo de I/O y de volumen de log considerable en una base con tráfico real; `'mod'` cubre lo que cambia el estado de los datos, que es lo auditable en el sentido de "quién modificó qué". Para la investigación puntual del incidente de la Parte C se subió momentáneamente a `'all'` — ver `informe_incidente.md`.

## 2. Secuencia de prueba y log capturado

Se ejecutó: una lectura (`SELECT count(*) FROM producto`), una inserción y una actualización sobre `categoria`, y un intento de login fallido contra el motor (usuario `app_web`, contraseña incorrecta, vía conexión TCP real). El fragmento capturado está en `log_auditoria_prueba.txt`.

## 3. Qué es útil del log y qué queda fuera de alcance

**Útil para auditoría (quién / qué / cuándo / desde dónde):** el log con estos parámetros identifica el usuario de conexión (`usuario=app_web`), la base, el timestamp con precisión de milisegundos, el origen (`host=` — IP o `[local]`), y el texto completo de la sentencia modificadora. Para el intento de login fallido, además, el motor registra el `FATAL` con el método de autenticación y la línea de `pg_hba.conf` que lo evaluó.

**Fuera de alcance de este mecanismo nativo:**
- **No hay detalle fila por fila.** El log muestra el `UPDATE categoria SET descripcion = ... WHERE nombre = ...` ejecutado, pero no qué valores tenía la fila *antes* del cambio, ni cuántas filas afectó realmente, ni el valor resultante. Eso es exactamente lo que agrega la extensión **pgaudit**: puede registrar, a nivel de objeto y de sesión, el detalle de cada operación con mayor granularidad y formato más estructurado (separando parámetros de la sentencia, por ejemplo), sin tener que subir `log_statement` a `'all'` para todo el tráfico.
- **No distingue el rol efectivo tras un `SET ROLE`.** El `usuario=` del log es el rol de la conexión, no el rol bajo el cual se ejecuta realmente una sentencia si hubo un cambio de rol en la sesión (confirmado empíricamente en la Parte C: todas las sentencias ejecutadas "como" `app_web` vía `SET ROLE` quedaban igual bajo el usuario de conexión real en el log).
- **Con `log_statement='mod'`, los `SELECT` no quedan registrados en absoluto** — incluida una lectura masiva de datos sensibles, que es precisamente el tipo de evento que una auditoría de seguridad querría poder reconstruir (confirmado también en la Parte C).

## 4. ¿El propio archivo de log es un activo sensible?

Sí. El log incluye el texto completo de las sentencias SQL ejecutadas, lo que en el caso de `INSERT`/`UPDATE` puede contener datos personales en texto plano (nombres, emails, teléfonos) tal como se escribieron en la sentencia — no solo metadatos. Debería poder leerlo únicamente la cuenta de sistema operativo bajo la que corre PostgreSQL (`postgres`, con permisos de archivo restringidos al propio usuario, como viene por defecto en `/var/lib/postgresql/.../log/`) y, dentro de la organización, solo personal de DBA/seguridad con necesidad de investigar incidentes — nunca el rol de aplicación (`app_web`) ni roles de uso general como `rol_soporte` o `rol_reportes`, que no deberían tener acceso al sistema de archivos del servidor en absoluto.
