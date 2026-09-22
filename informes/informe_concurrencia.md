# Informe de concurrencia — Food Store

Base: `copia_trabajo` con el `schema.sql` del proyecto + datos mínimos de prueba
(categoría "Pizzas", producto "Muzzarella" con stock 10). Motor: PostgreSQL 16,
dos sesiones psql concurrentes (Sesión A y Sesión B).

---

## Escenario 1 — Lectura no repetible

**Cómo se reprodujo** (Sesión A y B, en orden):

```sql
-- Sesión A                                    -- Sesión B
BEGIN;
SELECT stock FROM producto
  WHERE nombre='Muzzarella';        -- 1ra lectura
                                                BEGIN;
                                                UPDATE producto SET stock = stock - 1
                                                  WHERE nombre='Muzzarella';
                                                COMMIT;
SELECT stock FROM producto
  WHERE nombre='Muzzarella';        -- 2da lectura, misma transacción
COMMIT;
```

**Qué se observó** (Read Committed, nivel por defecto):

| Paso | Sesión | Resultado |
|---|---|---|
| 1ra lectura de A | A | `stock = 10` |
| UPDATE + COMMIT | B | `UPDATE 1` |
| 2da lectura de A (misma tx) | A | `stock = 9` |

La misma consulta, dentro de la misma transacción de A, devolvió dos valores
distintos: lectura no repetible.

**Explicación:** bajo Read Committed, cada sentencia individual ve el snapshot
de datos confirmados *al momento de ejecutarse esa sentencia*, no el snapshot
del inicio de la transacción. Como B commiteó entre la 1ra y la 2da lectura de
A, la 2da lectura ve el cambio.

**Verificación en el motor con Repeatable Read:**

```sql
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT stock ...  -- 10
-- (B actualiza y commitea igual que antes)
SELECT stock ...  -- 10 de nuevo
COMMIT;
```

Repetido con `REPEATABLE READ`, la 2da lectura de A devolvió `10` (no cambió),
confirmando que ese nivel de aislamiento evita la lectura no repetible: toda la
transacción de A trabaja sobre un único snapshot tomado al inicio.

**Conclusión:** confirmado en el motor. `REPEATABLE READ` evita este escenario;
`READ COMMITTED` no.

---

## Escenario 2 — Lectura fantasma

**Cómo se reprodujo:**

```sql
-- Sesión A                                    -- Sesión B
BEGIN ISOLATION LEVEL READ COMMITTED;
SELECT COUNT(*) FROM producto
  WHERE activo = TRUE;              -- 1er conteo
                                                BEGIN;
                                                INSERT INTO producto
                                                  (nombre, precio, stock, id_categoria, activo)
                                                  VALUES ('Fugazzeta', 1200, 5, <id_pizzas>, TRUE);
                                                COMMIT;
SELECT COUNT(*) FROM producto
  WHERE activo = TRUE;              -- 2do conteo
COMMIT;
```

**Qué se observó** (Read Committed): 1er conteo = `1`, 2do conteo = `2`. B
insertó una fila nueva que cumple el WHERE de A, y A la ve al repetir la
consulta dentro de la misma transacción: lectura fantasma.

**Pedido de explicación:** el nivel que en teoría evita fantasmas es
`REPEATABLE READ` (o `SERIALIZABLE`).

**Verificación en el motor con Repeatable Read:** repitiendo el experimento
con `BEGIN ISOLATION LEVEL REPEATABLE READ;`, el 2do conteo de A dio `1`, igual
que el 1ro — no vio la fila nueva pese a que B la insertó y commiteó en el
medio.

**Conclusión — discrepancia registrada, no oculta:** el estándar SQL define
que `REPEATABLE READ` no garantiza evitar fantasmas (para eso exige
`SERIALIZABLE`). En PostgreSQL, sin embargo, `REPEATABLE READ` se implementa
con snapshot isolation: toda la transacción usa el snapshot tomado al
principio, así que un INSERT confirmado después por otra sesión directamente
no es visible para ninguna consulta posterior dentro de esa transacción — ni
siquiera un COUNT nuevo. En la práctica, en Postgres `REPEATABLE READ` sí
evitó el fantasma en este caso (comportamiento más fuerte que lo que exige el
estándar). Si una respuesta de IA dice "usá REPEATABLE READ porque el
estándar no lo garantiza contra fantasmas, necesitás SERIALIZABLE", conviene
matizarlo con esta particularidad del motor real.

---

## Escenario 3 — Espera por bloqueo

**Cómo se reprodujo:**

```sql
-- Sesión A                                    -- Sesión B
BEGIN;
SELECT stock FROM producto
  WHERE nombre='Muzzarella' FOR UPDATE;   -- A toma el lock de fila
                                                BEGIN;
                                                SELECT stock FROM producto
                                                  WHERE nombre='Muzzarella' FOR UPDATE;
                                                -- B queda esperando acá
COMMIT;                                        -- A libera el lock
                                                -- recién ahora B recibe su resultado
                                                COMMIT;
```

**Qué se observó** (con timestamps reales):

- `18:18:16.849` — B pide el lock (`SELECT ... FOR UPDATE`).
- `18:18:18.853` (2 s después) — B todavía no tiene resultado; su sesión solo
  muestra `BEGIN`, la consulta sigue colgada.
- `18:18:19.857` — A hace `COMMIT`. Inmediatamente después, B recibe su
  resultado (`stock = 10`) y puede continuar.

**Conclusión:** confirmado en el motor. `SELECT ... FOR UPDATE` toma un lock
exclusivo de fila que se retiene hasta el `COMMIT`/`ROLLBACK` de quien lo pidió
primero; una segunda sesión que pide el mismo lock queda bloqueada (no falla,
no hace polling: espera) hasta que se libera.

---

## DUIA de esta parte

Ver `DUIA.md`, sección "Parte 2".
