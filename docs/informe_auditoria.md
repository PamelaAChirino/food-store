# Informe de Auditoría — Parte B (Unidad 5)

## 1. Configuración activada

Se activaron, sobre el servidor PostgreSQL de desarrollo, los siguientes parámetros (vía `ALTER SYSTEM` + `pg_reload_conf()`, equivalente a editar `postgresql.conf` y recargar):

| Parámetro | Valor | Motivo |
|---|---|---|
| `log_connections` | `on` | Registra cada conexión entrante (quién se conecta, desde dónde) |
| `log_disconnections` | `on` | Registra el cierre de sesión y su duración |
| `log_statement` | `mod` | Registra las sentencias que modifican datos (`INSERT`, `UPDATE`, `DELETE`, DDL) — deja afuera los `SELECT`, que no son el objetivo de esta auditoría |
| `log_line_prefix` | `%m [%p] user=%u db=%d host=%h` | Agrega timestamp, PID, usuario, base y origen a cada línea, para que el log sea legible sin tener que cruzar con otra fuente |

## 2. Secuencia de prueba ejecutada

1. Lectura: `SELECT * FROM cliente LIMIT 1;`
2. Inserción: `INSERT INTO categoria (nombre) VALUES ('Prueba Auditoria U5') ...`
3. Actualización: `UPDATE cliente SET telefono = ... WHERE id_cliente = 2;`
4. Intento de inicio de sesión fallido: conexión como `app_web` con contraseña incorrecta (dos intentos, para ver el patrón repetido en el log)

Fragmento de log capturado: [`log_auditoria_prueba.txt`](./log_auditoria_prueba.txt).

Nota: la lectura (`SELECT`) no aparece en el fragmento porque `log_statement = mod` la excluye a propósito — es el comportamiento esperado, no un faltante.

## 3. Qué es útil del log, y qué queda fuera de alcance

**Útil para auditoría (quién / qué / cuándo / desde dónde):** cada línea trae usuario (`user=`), base (`db=`), origen (`host=`) y timestamp con zona horaria (`%m`). La sentencia de modificación queda completa (`LOG: statement: UPDATE ...`), y el intento fallido de login queda marcado como `FATAL: password authentication failed`, con el archivo y la línea de `pg_hba.conf` que lo evaluó — alcanza para reconstruir quién intentó entrar, con qué usuario, y si fue aceptado o no.

**Fuera de alcance de este mecanismo nativo:** `log_statement` registra la sentencia tal como se envió, pero no el valor de cada fila afectada antes y después del cambio — si un `UPDATE` afecta 500 filas, el log muestra la sentencia una sola vez, no el detalle fila por fila de qué cambió en cada una. Tampoco distingue, dentro de una transacción con varias sentencias, cuáles pertenecían al mismo `BEGIN/COMMIT`. Para ese nivel de detalle (fila por fila, antes/después, con el mismo formato estructurado), la extensión `pgaudit` permite configurar una auditoría por sesión u objeto con más granularidad que `log_statement`, a costa de generar mucho más volumen de log. La tabla `log_auditoria` con triggers que ya tiene el proyecto (JSONB con antes/después) es, de hecho, la forma en que este equipo cubrió esa brecha a nivel de aplicación, sin necesidad de instalar `pgaudit`.

## 4. ¿El log es en sí mismo un activo sensible?

Sí. El fragmento capturado ya expone qué usuarios existen, desde qué host se conectan y qué operaciones ejecutan sobre tablas con datos de clientes — es información útil para alguien que quiera mapear el sistema antes de atacarlo, y en un entorno con `log_statement` más amplio (`all`) podría llegar a contener valores de columnas sensibles dentro de la sentencia misma. Debería poder leerlo solo el rol de administración de la base (`admin_datos` a nivel de aplicación, o el usuario del sistema operativo dueño del proceso `postgres` a nivel de archivo) — nunca los roles de aplicación (`app_web`) ni usuarios sin necesidad operativa de diagnóstico. En el sistema de archivos, el log ya queda con permisos `640` para el usuario `postgres` y el grupo `adm` (verificado con `ls -la` sobre el directorio de log), lo cual es consistente con ese criterio.

---

## Anexo — Auditoría complementaria a nivel de aplicación (trigger + JSONB)

El punto 3 de este informe menciona que `log_statement` no guarda el detalle fila por fila de qué cambió en cada `UPDATE`. Ese hueco se cubrió con un mecanismo complementario, a nivel de aplicación, que sí guarda ese detalle: la tabla `log_auditoria` (ver `sql/auditoria_test.sql`).

**Objetivo:** garantizar trazabilidad fila por fila de las operaciones críticas sobre las tablas sensibles del sistema Food Store (`cliente` y `pedido`) — qué usuario realizó cada cambio, qué operación (`INSERT`/`UPDATE`/`DELETE`) y el estado anterior y posterior de los datos.

**Estrategia de implementación:**
1. **Tabla de auditoría (`log_auditoria`)**, con campos `JSONB` para guardar instantáneas de los registros modificados sin depender de la estructura exacta de la tabla afectada.
2. **Función PL/pgSQL `fn_auditar_cambios`** (`SECURITY DEFINER`), que registra usuario actual, timestamp con zona horaria y la operación.
3. **Triggers** `AFTER INSERT OR UPDATE OR DELETE` sobre `cliente` y `pedido`.

**Pruebas y resultado:** se ejecutaron actualizaciones sobre `cliente` y se verificó que `log_auditoria` registró correctamente el estado anterior y posterior en formato JSONB, con precisión de milisegundos.

Este mecanismo es el que, en la Parte C, permite confirmar con evidencia concreta si un cambio autorizado realmente ocurrió o no.
