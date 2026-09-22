# TP4 — Semana 4 (Unidad 2)
## Reportes analíticos asistidos por IA sobre Food Store: joins, subconsultas, agregación y ventana

Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mule

**Base de datos usada:** misma carga masiva de la Semana 3 (50.000
productos, 20.000 clientes, 200.000 pedidos), completada con el detalle de
cada pedido en `pedido_producto` (2-3 líneas por pedido, ~600.000 filas),
necesario para poder hacer JOIN de 3+ tablas.

**Decisión documentada:** para cargar `pedido_producto` a este volumen se
deshabilitó temporalmente el trigger `trg_pedido_producto_venta` (Unidad
1). Ese trigger valida stock y producto activo pensado para ventas una por
una en tiempo real; aplicado fila por fila sobre 600.000 inserts habría
agotado el stock de muchos productos a mitad de camino y abortado toda la
carga. Se reactivó apenas terminó la carga masiva, así que sigue
protegiendo cualquier venta nueva normalmente. Ver `carga_detalle.sql`.

---

## Parte 1 — Laboratorio: consultas analíticas lentas

### 1.2 Tabla de resultados

| Consulta | Algoritmo de join (antes) | Cambio aplicado | Algoritmo de join (después) | Mejora |
|---|---|---|---|---|
| Facturación por categoría y mes (categoria + producto + pedido_producto + pedido, sin filtro) | 3× Hash Join, Parallel Seq Scan sobre las 4 tablas. Sort externo a disco (~8MB). **7195.9 ms** | `CREATE INDEX idx_pedido_producto_producto ON pedido_producto(id_producto);` | Sin cambios — sigue 3× Hash Join, sigue usando Parallel Seq Scan on pedido_producto, NO el índice nuevo. **1706.6 ms** | Ver nota — la baja no fue por el índice |
| Facturación por categoría, un mes específico (mismo JOIN + filtro `pe.fecha` acotado a marzo) | 3× Hash Join, Parallel Seq Scan on pedido con filtro de fecha (descarta ~74.000 de ~66.667 filas/worker). **250.1 ms** | `CREATE INDEX idx_pedido_fecha ON pedido(fecha);` | Sigue 3× Hash Join; cambió el acceso a pedido (Seq Scan → Bitmap Heap Scan), pero el tiempo real empeoró: **320.1 ms** | Negativa: -28% (más lento) |

### Por qué ninguna de las dos "mejoras" funcionó — documentado, no ocultado

**Consulta 1 (índice no usado):** se corrió la misma consulta dos veces
seguidas para aislar el efecto. Con el índice nuevo: 1706.6 ms. Sacando el
índice pero con la caché ya caliente (misma sesión, segunda ejecución):
1562 ms — prácticamente igual. La mejora real vino de que Postgres ya tenía
las páginas en caché de la primera corrida, no del índice, que además el
plan ni siquiera usó (siguió eligiendo `Parallel Seq Scan on
pedido_producto`, más barato que un `Index Scan` cuando hace falta leer
casi toda la tabla).

*Figura 1: plan de ejecución `EXPLAIN ANALYZE` de la Consulta 1 (base sin
optimizar) — ver captura en el repositorio.*

**Consulta 2 (índice usado, pero empeoró):** el filtro por mes solo
descarta ~74% de los pedidos — no es lo bastante selectivo. El índice sí se
usó (`Bitmap Index Scan on idx_pedido_fecha`), pero el `Bitmap Heap Scan`
resultante hizo lecturas de disco adicionales que un `Seq Scan` secuencial
no necesita. Es el ejemplo clásico de "el índice existe y se usa, pero no
convenía": para filtros de baja selectividad (por encima de ~10-15% de la
tabla, como regla general), un `Seq Scan` suele ganarle a un
`Bitmap/Index Scan`.

*Figura 2: plan de ejecución `EXPLAIN ANALYZE` de la Consulta 2 (con índice
aplicado) — ver captura en el repositorio.*

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
                    ->  Index Scan using cliente_email_key on cliente cl  (cost=0.41..8.43 rows=1 width=8)
                          (actual time=0.024..0.025 rows=1 loops=1)
                          Index Cond: ((email)::text = 'usuario_12345@foodstore.com'::text)
                    ->  Bitmap Heap Scan on pedido pe  (cost=4.37..42.02 rows=10 width=24)
                          (actual time=0.088..0.105 rows=7 loops=1)
                          Recheck Cond: (cl.id_cliente = id_cliente)
                          ->  Bitmap Index Scan on idx_pedido_cliente  (cost=0.00..4.37 rows=10 width=0)
                                (actual time=0.047..0.047 rows=7 loops=1)
                                Index Cond: (id_cliente = cl.id_cliente)
              ->  Index Scan using pedido_producto_pkey on pedido_producto pp  (cost=0.42..0.63 rows=3 width=26)
                    (actual time=0.011..0.017 rows=3 loops=7)
                    Index Cond: (id_pedido = pe.id_pedido)
        ->  Index Scan using producto_pkey on producto p  (cost=0.29..0.31 rows=1 width=22)
              (actual time=0.005..0.005 rows=1 loops=21)
              Index Cond: (id_producto = pp.id_producto)
Planning Time: 1.073 ms
Execution Time: 0.517 ms
```

**Explicación pedida a la IA** (dándole solo el texto del plan de arriba):

> "El plan arranca con un Nested Loop cuya tabla externa es
> `pedido_producto`, que actúa como ancla y sondea contra `producto` por
> cada línea. Antes de eso, hay otro Nested Loop donde `cliente` es la
> tabla interna, sondeada mediante el índice de email por cada fila de
> `pedido`. El costo total de 67.25 representa cuánto tardó la consulta
> completa en ejecutarse."

| Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
|---|---|---|
| "La tabla externa es pedido_producto, que sondea contra producto" | No | Es al revés: `producto` es la tabla interna (la que se sondea) — su `Index Scan using producto_pkey` tiene `loops=21`, se ejecuta una vez por cada una de las 21 filas que trae el lado externo |
| "cliente es la tabla interna, sondeada por cada fila de pedido" | No | Es al revés: `cliente` es la externa/conductora — su `Index Scan using cliente_email_key` tiene `loops=1` (se ejecuta una sola vez). `pedido` es la interna: su `Bitmap Heap Scan` usa `cl.id_cliente` como parámetro, depende del valor que le pasa `cliente` |
| "El costo de 67.25 representa cuánto tardó la consulta en ejecutarse" | No | 67.25 es el `cost` estimado del nodo `Sort` (unidad arbitraria del optimizador), no tiempo. El tiempo real está en `Execution Time: 0.517 ms`, otra escala completamente distinta |

**Conclusión:** las 3 afirmaciones tenían errores, y los dos primeros
comparten la misma causa: la IA asumió que "la tabla que aparece primero en
la consulta" es la externa, cuando hay que leerlo del plan — la externa de
un Nested Loop es la que tiene `loops=1` (o el menor número relativo), y la
interna es la que se re-ejecuta una vez por cada fila que le llega del lado
externo.

---

## Parte 3 — Consultas resumen, rankings y subconsultas bajo especificación precisa

> **Nota de adaptación al esquema real:** la spec de ejemplo del TP
> menciona "usuario vigente" y "pedido no eliminado" (borrado lógico en
> `cliente` y `pedido`). En el esquema real de Food Store, `cliente` y
> `pedido` **no** tienen columna de borrado lógico — solo `producto` y
> `categoria` tienen `activo`. La spec de abajo se adaptó a lo que el
> esquema realmente permite filtrar.

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
gastaron estrictamente más — la misma lógica que hace `RANK()`
internamente, escrita a mano (y por eso los empates también comparten
puesto acá).

**Verificación de equivalencia:**
```sql
(SELECT * FROM v1) EXCEPT (SELECT * FROM v2)  -- 0 filas
(SELECT * FROM v2) EXCEPT (SELECT * FROM v1)  -- 0 filas
```
Resultado real: 0 filas en ambos sentidos sobre las 20.000 filas de
clientes → equivalentes. Top 1 real: Cliente_2359, $606.466,57, puesto 1.

---

## Declaración de Uso de IA (DUIA)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| OpenCode | Generar el script de carga del detalle de pedidos (pedido_producto, ~600.000 filas) | "Generá un script SQL para poblar pedido_producto con 2-3 líneas por cada uno de los 200.000 pedidos existentes, con producto y cantidad al azar, sin usar un patrón que Postgres pueda evaluar una sola vez para todas las filas" | Se aceptó la estructura general, pero se corrigió un primer intento con `JOIN producto ON id_producto = (random...)` directo: se comprobó que Postgres evaluaba esa expresión una sola vez para todas las filas (mismo problema que el LATERAL de la Semana 3, ahora en una condición de JOIN). Se resolvió generando el `id_producto` aleatorio en el `SELECT` de una CTE previa |
| OpenCode/Kiro | Proponer índices para las 2 consultas analíticas de la Parte 1, a partir de los planes EXPLAIN ANALYZE reales | Se pasó cada plan real y se pidió una propuesta justificada en el nodo concreto (Seq Scan sobre pedido_producto en un caso, sobre pedido con filtro de fecha en el otro) | Las 2 propuestas se probaron y NINGUNA mejoró el tiempo real — se documentaron igual en la Parte 1 en vez de descartarlas en silencio, con la explicación de por qué no funcionaron |
| Claude | Explicar nodo por nodo un plan real con 3 Nested Loop anidados (Parte 2) | Se dio solo el texto del plan, sin más contexto | Se aceptó parcialmente: las 3 afirmaciones tenían errores — confundió tabla externa con interna en 2 de los 3 Nested Loop, y cost con milisegundos. Se documentaron las 3 correcciones con evidencia de loops= de cada nodo |
| Claude | Generar las 2 versiones de la consulta de ranking de la Parte 3 | La spec de la Parte 3 (adaptada al esquema real, sin borrado lógico en cliente/pedido) | Se aceptaron ambas versiones; se verificó equivalencia con EXCEPT en los dos sentidos sobre las 20.000 filas de clientes (0 filas de diferencia) |
