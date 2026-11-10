# Especificación de Migración — FNBC de `control_lote_almacen` (Unidad 4)

## 1. Objetivo
Descomponer `control_lote_almacen(lote_id, deposito_id, responsable_control_id)` —que viola FNBC por la dependencia funcional `responsable_control_id → deposito_id`— en dos tablas que sí cumplen FNBC, migrando los datos existentes sin pérdida y sin tiempo de parada no reversible.

## 2. Dependencias funcionales relevadas
- **DF1:** `{lote_id, deposito_id} → {responsable_control_id}`
- **DF2:** `{responsable_control_id} → {deposito_id}` — esta es la que rompe FNBC, porque `responsable_control_id` no es superclave.

## 3. Esquema destino
- `responsable_deposito_fnbc(responsable_control_id PK, deposito_id NOT NULL)` — materializa la DF2.
- `control_lote_fnbc(lote_id, responsable_control_id FK, PRIMARY KEY (lote_id, responsable_control_id))` — materializa la DF1 sin repetir `deposito_id`.
- `v_control_lote_almacen_fnbc` — vista de compatibilidad que reconstruye la forma original (`lote_id, deposito_id, responsable_control_id`) vía JOIN, para que el código existente que lee la tabla legacy no se rompa durante la transición.

## 4. Plan de migración
Todo el DDL + la migración de datos corre dentro de una única transacción (`scripts/tp_fnbc_control_lote.sql`, `BEGIN; ... COMMIT;`):

1. Crear las tablas nuevas (`CREATE TABLE IF NOT EXISTS`, no destructivo).
2. `INSERT ... SELECT DISTINCT` desde `control_lote_almacen_legacy` hacia `responsable_deposito_fnbc`, con `ON CONFLICT (responsable_control_id) DO NOTHING` (idempotente: correr el script dos veces no duplica filas).
3. `INSERT ... SELECT DISTINCT` hacia `control_lote_fnbc`, mismo criterio de idempotencia.
4. Crear `v_control_lote_almacen_fnbc`.
5. La tabla legacy **no se borra** en este script — queda como respaldo en caliente hasta confirmar la migración (ver sección 6).

## 5. Verificación de equivalencia (sin pérdida)
Fuera de la transacción, dos `EXCEPT` cruzados entre la tabla legacy y la vista de compatibilidad:
```sql
(SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen_legacy)
EXCEPT
(SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen_fnbc);
-- y a la inversa
```
Ambas consultas deben devolver **0 filas**: confirma que el conjunto de datos reconstruido es exactamente el mismo que el original, en ambas direcciones (ni se perdió ni se inventó ninguna fila). Se agrega además un chequeo de la DF1 sobre el esquema nuevo (`HAVING COUNT(DISTINCT responsable_control_id) > 1` debe dar 0 filas).

## 6. Plan de reversión (rollback)
La migración se diseñó para ser reversible en dos niveles:

- **Durante la migración (falla a mitad de camino):** todo el DDL y las cargas están dentro de `BEGIN; ... COMMIT;`. Cualquier error antes del `COMMIT` revierte automáticamente con `ROLLBACK` — no quedan tablas a medio crear ni filas a medio insertar.
- **Después de confirmada (se decide volver atrás igual):** como `control_lote_almacen_legacy` no se elimina en este script, revertir es:
  ```sql
  DROP VIEW IF EXISTS v_control_lote_almacen_fnbc;
  DROP TABLE IF EXISTS control_lote_fnbc;
  DROP TABLE IF EXISTS responsable_deposito_fnbc;
  -- control_lote_almacen_legacy sigue intacta: no se perdió nada
  ```
  El código que dependía del esquema original sigue funcionando porque nunca dejó de existir.

## 7. Salvaguardas aplicadas
- Ninguna sentencia es destructiva sobre los datos originales (`CREATE TABLE IF NOT EXISTS`, `ON CONFLICT DO NOTHING`, sin `DROP`/`DELETE` sobre la legacy).
- La migración completa es idempotente: correr el script más de una vez no duplica ni corrompe datos.
- La equivalencia se verifica con `EXCEPT` cruzado, no se asume por lectura del código.
- El borrado definitivo de `control_lote_almacen_legacy` queda como paso manual posterior, explícitamente fuera de este script, una vez que el equipo confirme que ningún otro proceso la sigue usando.
