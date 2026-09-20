# TP4 Semana 4 (Unidad 2) — Food Store
## Joins, subconsultas, agregación y ventana

Integrantes: Mayra Mule, Pamela Chirino, Lucas Agüero

Base: misma carga masiva de la Semana 3 (50.000 productos, 20.000 clientes,
200.000 pedidos), completada ahora con el detalle de cada pedido en
`pedido_producto` (2-3 líneas por pedido, ~600.000 filas), necesario para
poder hacer JOIN de 3+ tablas.

> **Decisión documentada:** para cargar `pedido_producto` a este volumen se
> deshabilitó temporalmente el trigger `trg_pedido_producto_venta` (Unidad 1).
> Ese trigger valida stock y producto activo pensado para ventas una por una
> en tiempo real; aplicado fila por fila sobre 600.000 inserts habría agotado
> el stock de muchos productos a mitad de camino y abortado toda la carga.
> Se reactivó el trigger apenas terminó la carga masiva, así que sigue
> protegiendo cualquier venta nueva normalmente. Ver `carga_detalle.sql`.

---

## Parte 1 — Laboratorio: consultas analíticas lentas

### 1.2 Tabla de resultados

| Consulta | Algoritmo de join (antes) | Cambio aplicado | Algoritmo de join (después) | Mejora |
|---|---|---|---|---|
| **Facturación por categoría y mes** (categoria + producto + pedido_producto + pedido, sin filtro — agrega todo el histórico) | 3× Hash Join, con Parallel Seq Scan sobre las 4 tablas. Sort externo a disco (~8MB). **7195.9 ms** | `CREATE INDEX idx_pedido_producto_producto ON pedido_producto(id_producto);` | **Sin cambios** — sigue siendo 3× Hash Join, y el plan repetido sigue usando `Parallel Seq Scan on pedido_producto`, **no el índice nuevo**. Tiempo real: 1711.2 ms | Ver nota — la baja de 7196→1711 ms **no fue por el índice** |
| **Facturación por categoría, un mes específico** (mismo JOIN + filtro `pe.fecha` acotado a marzo) | 3× Hash Join, `Parallel Seq Scan on pedido` con filtro de fecha (descarta ~74.000 de ~66.667 filas por worker). **250.1 ms** | `CREATE INDEX idx_pedido_fecha ON pedido(fecha);` | Sigue siendo 3× Hash Join; cambió el **método de acceso** a `pedido` (`Seq Scan` → `Bitmap Heap Scan`), pero el tiempo real **empeoró**: 320.1 ms | **Negativa**: -28% (más lento) |

### Nota — por qué ninguna de las dos "mejoras" funcionó, documentado en vez de ocultado

**Consulta 1 (índice no usado):** se corrió la misma consulta dos veces
seguidas para aislar el efecto. Con el índice nuevo: 1711 ms. Sacando el
índice pero con la caché ya caliente (misma sesión, segunda ejecución): 1562
ms — prácticamente igual. La mejora real vino de que Postgres ya tenía las
páginas en caché de la primera corrida, no del índice — que además el plan
ni siquiera usó (siguió eligiendo `Parallel Seq Scan on pedido_producto`,
más barato que un `Index Scan` cuando hace falta leer prácticamente toda la
tabla para la agregación). Confirmado ejecutando la consulta con
`EXPLAIN (ANALYZE, BUFFERS)` en ambos casos y comparando el nodo elegido.

**Consulta 2 (índice usado, pero empeoró):** el filtro por mes solo descarta
alrededor del 74% de los pedidos — no es lo bastante selectivo. El índice sí
se usó (`Bitmap Index Scan on idx_pedido_fecha`), pero el `Bitmap Heap Scan`
resultante hizo lecturas de disco adicionales (`read=49` en los buffers) que
un simple `Seq Scan` secuencial no necesita. Es el ejemplo clásico de "el
índice existe y se usa, pero no convenía": para filtros de baja selectividad
(por encima de ~10-15% de la tabla, como regla general), un `Seq Scan` suele
ganarle a un `Bitmap/Index Scan`.

**Conclusión para la defensa oral:** ninguna consulta necesitaba un índice
nuevo — ambas son agregaciones que tocan una porción grande de la tabla, y
ahí el cuello de botella real es el volumen de datos a agregar, no la forma
de acceder a ellos. Un índice ayuda cuando el filtro es selectivo; acá no lo
era.

---

## Parte 2 — Lectura crítica de planes de join interpretados por IA

**Plan real usado** (historial de compras de un cliente puntual — 3 Nested
Loop anidados, cada uno con `loops` distinto, ideal para ver
externa/interna):

```
Sort  (cost=67.25..67.32 rows=30 width=40) (actual time=0.408..0.410 rows=21 loops=1)
  Sort Key: pe.fecha DESC
  ->  Nested Loop  (cost=5.50..66.51 rows=30 width=40) (actual time=0.142..0.381 rows=21 loops=1)
        ->  Nested Loop  (cost=5.21..57.13 rows=30 width=34) (actual time=0.131..0.261 rows=21 loops=1)
              ->  Nested Loop  (cost=4.79..50.55 rows=10 width=16) (actual time=0.115..0.134 rows=7 loops=1)
                    ->  Index Scan using cliente_email_key on cliente cl  (cost=0.41..8.43 rows=1 width=8) (actual time=0.024..0.025 rows=1 loops=1)
                          Index Cond: ((email)::text = 'usuario_12345@foodstore.com'::text)
                    ->  Bitmap Heap Scan on pedido pe  (cost=4.37..42.02 rows=10 width=24) (actual time=0.088..0.105 rows=7 loops=1)
                          Recheck Cond: (cl.id_cliente = id_cliente)
                          ->  Bitmap Index Scan on idx_pedido_cliente  (cost=0.00..4.37 rows=10 width=0) (actual time=0.047..0.047 rows=7 loops=1)
                                Index Cond: (id_cliente = cl.id_cliente)
              ->  Index Scan using pedido_producto_pkey on pedido_producto pp  (cost=0.42..0.63 rows=3 width=26) (actual time=0.011..0.017 rows=3 loops=7)
                    Index Cond: (id_pedido = pe.id_pedido)
        ->  Index Scan using producto_pkey on producto p  (cost=0.29..0.31 rows=1 width=22) (actual time=0.005..0.005 rows=1 loops=21)
              Index Cond: (id_producto = pp.id_producto)
Planning Time: 1.073 ms
Execution Time: 0.517 ms
```

**Explicación pedida a la IA** (dándole solo el texto del plan):

> "El plan arranca con un Nested Loop cuya tabla externa es
> `pedido_producto`, que actúa como ancla y sondea contra `producto` por
> cada línea. Antes de eso, hay otro Nested Loop donde `cliente` es la tabla
> interna, sondeada mediante el índice de email por cada fila de `pedido`.
> El costo total de 67.25 representa cuánto tardó la consulta completa en
> ejecutarse."

| Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
|---|---|---|
| "La tabla externa [del Nested Loop más externo] es `pedido_producto`, que sondea contra `producto`" | No | Es al revés: `producto` es la tabla **interna** (la que se sondea), evidenciado por `loops=21` en su `Index Scan using producto_pkey` — se ejecuta una vez por cada una de las 21 filas que trae el lado externo (el resultado del Nested Loop anterior, que incluye `pedido_producto`) |
| "`cliente` es la tabla interna, sondeada por cada fila de `pedido`" | No | Es al revés: `cliente` es la **externa/conductora** de ese Nested Loop — su `Index Scan using cliente_email_key` tiene `loops=1` (se ejecuta una sola vez, para el único cliente que matchea el email). `pedido` es la interna: su `Bitmap Heap Scan` usa `cl.id_cliente` como parámetro, es decir, depende del valor que le pasa `cliente` |
| "El costo total de 67.25 representa cuánto tardó la consulta completa en ejecutarse" | No | 67.25 es el `cost` estimado del nodo `Sort` (una unidad arbitraria del optimizador), no tiempo. El tiempo real está en `Execution Time: 0.517 ms`, una escala completamente distinta — el mismo error de confundir `cost` con milisegundos que ya apareció en la Semana 3 |

**Conclusión:** las 3 afirmaciones tenían errores, y los dos primeros
comparten la misma causa: la IA asumió que "la tabla que aparece primero en
la consulta" es la externa, cuando en realidad hay que leerlo directamente
del plan — la tabla externa de un Nested Loop es la que tiene `loops=1` (o el
menor número de loops relativo), y la interna es la que se re-ejecuta una vez
por cada fila que le llega del lado externo.

---

## Parte 3 — Consultas resumen, rankings y subconsultas bajo especificación precisa

> **Nota de adaptación al esquema real:** la spec de ejemplo del TP menciona
> "usuario vigente" y "pedido no eliminado" (borrado lógico en `cliente` y
> `pedido`). En el esquema real de Food Store, **`cliente` y `pedido` no
> tienen columna de borrado lógico** — solo `producto` y `categoria` tienen
> `activo`. La spec de abajo se adaptó a lo que el esquema realmente permite
> filtrar, en vez de inventar una columna que no existe.

**Spec:** "Generá una consulta SQL sobre el esquema de Food Store que
devuelva, para cada cliente con al menos un pedido, su nombre completo, el
total gastado (suma de `cantidad * precio_unitario` de todas sus líneas de
`pedido_producto`) y su puesto en un ranking de mayor a menor gasto, sin
colapsar filas. En caso de empate, deben compartir el mismo puesto. No uses
`SELECT *`."

**Versión 1 (función de ventana `RANK()`):**
```sql
WITH totales AS (
    SELECT pe.id_cliente, SUM(pp.cantidad * pp.precio_unitario) AS total_gastado
    FROM pedido pe
    JOIN pedido_producto pp ON pp.id_pedido = pe.id_pedido
    GROUP BY pe.id_cliente
)
SELECT cl.nombre, cl.apellido, t.total_gastado,
       RANK() OVER (ORDER BY t.total_gastado DESC) AS puesto
FROM cliente cl
JOIN totales t ON t.id_cliente = cl.id_cliente
ORDER BY puesto;
```

**Versión 2 (subconsulta correlacionada, propia — sin `RANK()`):**
```sql
WITH totales AS (
    SELECT pe.id_cliente, SUM(pp.cantidad * pp.precio_unitario) AS total_gastado
    FROM pedido pe
    JOIN pedido_producto pp ON pp.id_pedido = pe.id_pedido
    GROUP BY pe.id_cliente
)
SELECT cl.nombre, cl.apellido, t.total_gastado,
       (SELECT COUNT(*) + 1 FROM totales o
         WHERE o.total_gastado > t.total_gastado) AS puesto
FROM cliente cl
JOIN totales t ON t.id_cliente = cl.id_cliente
ORDER BY puesto;
```
La subconsulta correlacionada calcula el puesto contando cuántos clientes
gastaron estrictamente más — la misma lógica que hace `RANK()` internamente,
escrita a mano (y por eso los empates también comparten puesto acá).

**Verificación de equivalencia:**
```sql
(SELECT * FROM v1) EXCEPT (SELECT * FROM v2)  -- 0 filas
(SELECT * FROM v2) EXCEPT (SELECT * FROM v1)  -- 0 filas
```
Resultado real: **0 filas en ambos sentidos** sobre las 20.000 filas de
clientes → equivalentes. Top 1 real: Cliente_2359, $606.466,57, puesto 1.

---

## Parte 4 — Competencia de optimización entre equipos

Igual que en la Semana 3, esta parte depende de la consulta puntual que
entregue la cátedra el día de la competencia — no se puede resolver de
antemano. Procedimiento a seguir ese día:

1. Correr la consulta dada tal cual con `EXPLAIN ANALYZE` sobre la base
   masiva compartida; guardar el **tiempo real** (no el cost) como línea de
   base.
2. Identificar qué nodo domina el plan y qué algoritmo de join usa cada
   combinación de tablas (`Hash Join`, `Nested Loop`, `Merge Join`).
3. Antes de pedirle nada a la IA, estimar qué tan selectivo es cada filtro
   — la Parte 1 de este mismo TP mostró que un índice sobre un filtro poco
   selectivo (~74% de las filas) puede empeorar el tiempo en vez de
   mejorarlo.
4. Pedirle a OpenCode/Kiro una propuesta pasándole el plan real, justificada
   en el nodo concreto que ataca.
5. Aplicar solo lo que se entienda del todo, volver a medir, y documentar el
   resultado sea cual sea — incluida cualquier propuesta que no funcione.

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) |
|---|---|---|---|---|
| _(completar el día de la competencia)_ | | | | |

---

## Declaración de Uso de IA (DUIA)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| OpenCode | Generar el script de carga del detalle de pedidos (`pedido_producto`, ~600.000 filas, 2-3 líneas por pedido) | "Generá un script SQL para poblar pedido_producto con 2-3 líneas por cada uno de los 200.000 pedidos existentes, con producto y cantidad al azar, sin usar un patrón que Postgres pueda evaluar una sola vez para todas las filas" | Se aceptó la estructura general (CTE + INSERT con `ON CONFLICT DO NOTHING`), pero se corrigió un primer intento con `JOIN producto ON id_producto = (random...)` directo: se comprobó que Postgres evaluaba esa expresión una sola vez para todas las filas (mismo problema de fondo que el `LATERAL` de la Semana 3, aplicado ahora a una condición de JOIN). Se resolvió generando el `id_producto` aleatorio en el `SELECT` de una CTE previa, donde sí se evalúa por fila |
| OpenCode / Kiro | Proponer índices para las 2 consultas analíticas de la Parte 1, a partir de los planes `EXPLAIN ANALYZE` reales | Se le pasó cada plan real y se pidió una propuesta de índice justificada en el nodo concreto (Seq Scan sobre pedido_producto en un caso, Seq Scan sobre pedido con filtro de fecha en el otro) | Las 2 propuestas se probaron y **ninguna mejoró el tiempo real** — se documentaron igual en la tabla de la Parte 1 en vez de descartarlas en silencio, con la explicación de por qué no funcionaron (índice no usado por el planner en un caso; filtro no lo bastante selectivo en el otro) |
| Claude | Explicar en lenguaje natural, nodo por nodo, un plan real con 3 Nested Loop anidados (Parte 2) | Se le dio solo el texto del plan, sin más contexto | Se aceptó parcialmente: las 3 afirmaciones tenían errores — confundió tabla externa con interna en 2 de los 3 Nested Loop, y confundió `cost` con milisegundos. Se documentaron las 3 correcciones con evidencia de `loops=` de cada nodo |
| Claude | Generar las 2 versiones de la consulta de ranking de la Parte 3 (función de ventana y subconsulta correlacionada) a partir de una spec precisa | La spec de la Parte 3 (adaptada al esquema real, sin borrado lógico en cliente/pedido) | Se aceptaron ambas versiones; se verificó la equivalencia con `EXCEPT` en los dos sentidos sobre las 20.000 filas de clientes (0 filas de diferencia) antes de darlas por buenas |
