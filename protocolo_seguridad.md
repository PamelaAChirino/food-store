# Protocolo de seguridad — proyecto Food Store

Condición no negociable para cualquier script (propio o generado por IA) que toque la base
del proyecto integrador. Motor: PostgreSQL. Entorno de trabajo: psql / DBeaver.

## 1. Copia

Nunca se trabaja sobre una base que tenga datos reales o de terceros. Antes de tocar nada:

```bash
createdb -T food_store copia_trabajo
psql -d copia_trabajo
```

Si `food_store` todavía no existe como plantilla, primero se crea y se carga con
`schema.sql` (y datos de prueba), y recién ahí se clona con `-T`.

**Cuándo se salta:** nunca. Todo experimento de este TP (constraints, triggers,
concurrencia) corre sobre `copia_trabajo`, no sobre la base "real" del proyecto.

## 2. Transacción

Todo script que escribe (INSERT, UPDATE, DELETE, o el bloque de prueba de un
CHECK/trigger nuevo) se corre primero dentro de una transacción que se puede
descartar:

```sql
BEGIN;
-- acá van los INSERT/UPDATE/DELETE de prueba
-- se inspecciona: filas afectadas, mensajes de error, resultado de un SELECT
ROLLBACK;  -- o COMMIT recién cuando se confirmó que el efecto es el esperado
```

**Cuándo se salta:** nunca. Ni siquiera para un UPDATE que "parece" trivial.

## 3. Respaldo

Antes de aplicar un cambio estructural (ALTER, CREATE TRIGGER, DROP, migración) sobre
`copia_trabajo`:

```bash
pg_dump copia_trabajo > respaldo_$(date +%Y%m%d_%H%M).sql
```

Esto permite volver atrás sin depender de que el ROLLBACK todavía esté disponible
(por ejemplo, si el cambio ya se commiteó por error).

**Cuándo se salta:** nunca. Todo DDL nuevo (los constraints y triggers de la Parte 1
de este TP) se respalda antes de aplicarse.

## Flujo resumido para cualquier script de IA sobre la base

1. Copia de trabajo lista (`copia_trabajo`).
2. `git diff` del script propuesto, línea por línea, antes de correrlo.
3. Respaldo (`pg_dump`) si el script incluye DDL.
4. `BEGIN` → aplicar → probar → `ROLLBACK` (o `COMMIT` si está todo verificado).
5. Commit con mensaje descriptivo de la regla de negocio que se garantiza.
