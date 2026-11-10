# Bitácora de Uso de IA — Unidades 4 a 8 (Segunda Entrega TPI Food Store)

- **Integrantes del Equipo**: Pamela Chirino, Lucas Agüero, Mayra Mulé
- **Fecha de Cierre**: Noviembre de 2026
- **Alcance**: consolida el registro de interacciones con IA de las Unidades 4, 5, 6, 7 y 8. El detalle de la Unidad 5 (Partes A-D) ya estaba documentado acá; se agregan el resto. Las declaraciones formales de uso de IA (DUIA) de cada unidad están en `duia.md`, `docs/DUIA_TP8.md` y, para la Unidad 7, en `informe_u7.pdf` del repositorio `nosql-mongo`.

---

## Unidad 4 — Normalización avanzada y redundancia

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| Analizar las dependencias funcionales de `control_lote_almacen` y proponer la descomposición a FNBC. | Identificó correctamente DF1 (`{lote_id, deposito_id} → {responsable_control_id}`) y DF2 (`{responsable_control_id} → {deposito_id}`, la que rompe FNBC), y propuso la descomposición en `responsable_deposito_fnbc` + `control_lote_fnbc` con vista de compatibilidad. | Se verificaron las clausuras y claves candidatas a mano antes de aceptar la descomposición. Se agregó, además de lo propuesto por la IA, la verificación de equivalencia con `EXCEPT` cruzado (no estaba en la propuesta original) y el plan de reversión explícito en `specs/spec_migracion_fnbc.md`, por ser obligatorio según la consigna. |
| Proponer un caso de desnormalización controlada para un panel de reportes lento. | Sugirió una vista materializada con índice único sobre `(fecha, categoria)` para `REFRESH CONCURRENTLY`. | Se midió el plan de ejecución antes y después (`EXPLAIN ANALYZE`) en vez de aceptar la mejora como afirmada: el costo bajó de ~1286 a ~37 y el tiempo real de ~1,63 ms a ~0,25 ms, confirmando la propuesta con evidencia real. |

## Unidad 5 — Administración y seguridad

### Registro de interacciones y validación (Partes A a D)

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| Diseñar roles y permisos de mínimo privilegio para Food Store, adaptados a las tablas reales (`cliente`, `producto`, `categoria`, `pedido`, `pedido_producto`, `usuario`). | Generó `sql/roles.sql`: 4 roles de grupo NOLOGIN, 2 roles de login, permisos finos por tabla, permiso a nivel de columna sobre `cliente`, `ALTER DEFAULT PRIVILEGES`. | Se revisaron los nombres de columnas reales. **Se detectó un error de sintaxis real**: la limpieza inicial usaba `DROP ROLE IF EXISTS ... CASCADE`, que no es válido en PostgreSQL (`CASCADE` no existe para `DROP ROLE`); el script fallaba al reejecutarse sobre una base donde los roles ya existían. Se corrigió reemplazándolo por `DROP OWNED BY ... CASCADE` + `DROP ROLE IF EXISTS`, y se verificó que el script es idempotente (dos ejecuciones seguidas sin error). |
| Auditar `roles.sql` y proponer mejoras. | Entre otras cosas, propuso simplificar `rol_reportes` y `rol_soporte` con `GRANT ALL ON ALL TABLES IN SCHEMA public` en vez de limitarlos a `SELECT`, para "cubrir cualquier necesidad futura del área". | **Rechazado.** Ambos roles son de solo consulta por diseño (reportes y soporte no deberían poder modificar datos); otorgarles `ALL` viola directamente el principio de mínimo privilegio que es el objetivo central de la Parte A. Se mantuvo `SELECT` únicamente. |
| Generar la función `fn_autenticar` y `fn_resetear_password` (prerrequisito de Clase 1/2 que el equipo no conservó). | Función que valida usuario/contraseña contra una tabla `usuario` con `password_hash` (vía `pgcrypto`/`crypt`), registra cada intento en `log_autenticacion`, e incrementa/resetea un contador de intentos fallidos. | Como los artefactos originales de clase no se conservaron, se reconstruyeron desde cero (dejando esta constancia, tal como pide la consigna). Se probaron en PostgreSQL real: 3 intentos con contraseña incorrecta quedan registrados como fallidos y uno con la correcta como exitoso, confirmado contra `log_autenticacion`. |
| Crear la tabla `log_auditoria` (JSONB), función de trigger y disparadores sobre `cliente`/`pedido`. | Generó `sql/auditoria_test.sql` e `docs/informe_auditoria.md`. | Se ejecutó en Postgres comprobando que un `UPDATE` sobre `cliente` queda registrado con estado anterior y posterior en JSONB. **Nota de alcance**: esta auditoría a nivel de aplicación no reemplaza el requisito de la Parte B (parámetros de log del servidor); se armaron ambas por separado. |
| Generar escenarios de prueba de violación de permisos con roles restringidos. | Primera versión (`incidente_simulacro.sql`) con 3 escenarios usando `SET ROLE` directo, sin pasar por `fn_autenticar` ni incluir un intento de escalamiento de rol. | **Corrección humana significativa** (ver punto 2 más abajo): se detectó que el Escenario 3 original afirmaba que `admin_datos` podía actualizar `cliente` ("modificación autorizada"), pero al ejecutarlo contra los permisos reales de `roles.sql` **falla** con `permission denied`. Se reescribió el script completo (`sql/simulacro_incidente.sql`) siguiendo la secuencia exacta de la consigna: logins fallidos/exitoso vía `fn_autenticar`, lectura masiva de `usuario`, intento de escalamiento con `GRANT admin_datos TO app_web`. |
| A partir del log anonimizado del simulacro (sin contexto adicional), reconstruir qué ocurrió y proponer una hipótesis de contención. | Reconstrucción que identificó correctamente el intento de escalamiento bloqueado, pero se abstuvo de afirmar el resultado de los 4 intentos de login (el log de sentencias no muestra el valor de retorno de `fn_autenticar`) y de calificar la lectura de `usuario` como "masiva" (el log no muestra cantidad de filas devueltas). | Se contrastó cada punto de la reconstrucción contra la evidencia real en `log_autenticacion` y en los resultados de la consulta (ver `docs/informe_incidente.md`, punto 5). La reconstrucción no afirmó nada que el log no sustentara; donde le faltaba evidencia, lo señaló en vez de inventar un dato. |
| Construir `usuario_anon` con datos sintéticos deterministas y verificar equivalencia de agregados por rol y mes de alta. | Script `sql/usuario_anon.sql`, agrupando por `rol` y `date_trunc('month', fecha_alta)`. | Se ejecutaron ambas consultas (sobre `usuario_anon` y sobre `usuario`) y el `EXCEPT` entre ambas dio 0 filas — equivalencia confirmada, no solo afirmada. Ver `docs/verificacion_equivalencia.md`. |

---

### Caso más significativo de error de la IA (Unidad 5)

El caso más significativo fue el del **Escenario 3 del simulacro de incidente original**: la IA generó un script que ejecutaba `UPDATE cliente ... ` bajo el rol `admin_datos` y lo documentó, tanto en el comentario del script como en el informe, como una "modificación autorizada" exitosa. Al verificar ese mismo script contra los permisos efectivamente definidos en `roles.sql` (`admin_datos` hereda `rol_soporte` y `rol_reportes`, ambos exclusivamente de lectura), la operación **falla con `permission denied`**. La IA generó una afirmación de éxito que su propio script, ejecutado contra su propio diseño de permisos, contradice. Se detectó al ejecutar el script contra una base de PostgreSQL real en vez de aceptar el resultado documentado sin correrlo — exactamente el tipo de validación humana que esta consigna pide practicar.

### Nota sobre el historial de Git (Unidad 5)

El repositorio original mezclaba partes de esta Unidad 5 con reconstrucciones hechas en una sesión de verificación posterior, sin ramas separadas por parte. Como mejora para futuros trabajos, se reitera la conveniencia de usar ramas (`feature/parte-a`, `feature/parte-b`, etc.) desde el inicio, integrando a la rama principal solo una vez verificado cada bloque — en vez de verificar y corregir todo al final, como ocurrió acá.

## Unidad 6 — Mantenimiento

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| Revisar `health_check.sql` y los scripts de respaldo entregados originalmente por el equipo. | Los scripts parecían correctos por lectura. | **Se detectó un bug real al ejecutar, no al leer**: `health_check.sql` usaba el literal `'food_store'` (con guion bajo) en vez de `'foodstore'` (nombre real de la base), rompiendo 1 consulta con error directo y dejando otra en silencio con 0 filas. Se corrigió y se agregó un "smoke test" que falla ruidosamente si el nombre de base no coincide. |
| Armar el simulacro de restauración (RTO/RPO) y automatizarlo. | Generó `scripts/restore_test.sh` con `dropdb`+`createdb`+`pg_restore`+validaciones. | Se corrió contra datos reales con volumen representativo (~115.000 filas) varias veces, no se aceptó el tiempo estimado por la IA: el RTO (0,71 s) y el RPO (2 s) del informe final son los que esas corridas reales reportaron. |

## Unidad 7 — NoSQL

(Desarrollado en el repositorio separado `nosql-mongo`; detalle completo de prompts en `informe_u7.pdf` de ese repositorio.)

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| Comparar PostgreSQL y MongoDB para el almacenamiento de pedidos de Food Store. | Afirmó que el modelo documental embebido "suele traducirse en lecturas más rápidas" al evitar *joins*, y que MongoDB no aplica integridad referencial por defecto. | Ambas afirmaciones se contrastaron con mediciones reales, no se aceptaron tal cual: la de integridad referencial se confirmó (inserción con `id_producto` inexistente aceptada por Mongo, rechazada por un trigger real en Postgres); la de velocidad de lectura **no se confirmó** a la escala probada (~1-2 ms en ambos motores con la conexión ya abierta). |

## Unidad 8 — Bases de datos móviles e integración

| Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|---|---|---|
| Especificar en Kiro el esquema SQLite de la tablet y su mecanismo de sincronización con el servidor. | Generó `docs/kiro_tp8/{requirements,design,tasks}.md` y los scripts de `movil/` (schema, carga de snapshot, semáforo, casos de conflicto). | Se verificó la regla de oro ("el móvil propone, el servidor dispone") revisando que ningún script de `movil/` modifique stock, y se corrieron los 4 casos de conflicto contra una base SQLite real. |
| Hacer un code review final asistido por IA de todos los scripts de la cursada. | Encontró 6 hallazgos (H1-H6), entre ellos que `PRAGMA foreign_keys` es por conexión (si no se activa, una FK inválida pasa sin error) y que restaurar solo la tabla `producto` del respaldo de U6 rompe `v_snapshot_movil` por la FK a `categoria`. | Cada hallazgo se verificó ejecutándolo contra una base real, no se aceptó por lectura (`docs/evidencia/verificaciones_code_review.txt`). H5 (trigger de `stock_visto` propuesto por la IA) se **descartó**: implementarlo rompía la regla de oro de que la tablet no decide stock. |
