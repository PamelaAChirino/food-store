# TP3 — Semana 3 (Unidad 2)
## Optimización asistida por IA sobre Food Store: filtros, planes de ejecución e índices

Integrantes: Mayra Mule, Pamela Chirino, Lucas Agüero

Esta práctica aplica los contenidos de la Semana 3 sobre el proyecto
integrador Food Store, con la IA como motor primario del trabajo: la IA
propone, el estudiante mide, decide y justifica cada cambio con evidencia
de `EXPLAIN ANALYZE`.

---

## Parte 1 — Poblar la base masivamente con datos generados por IA

Para que un Seq Scan sea perceptiblemente lento hace falta escala masiva:
50.000 productos, 20.000 usuarios y 200.000 pedidos con sus detalles.

### 1.1 Script de carga masiva (generado con `generate_series`)

Generado y revisado bajo el protocolo de seguridad de la cátedra (dentro de
transacción en entorno de prueba, con respaldo previo a la ejecución):

```sql
-- Protocolo de seguridad: inicio de transacción y respaldo previo
BEGIN;

-- 1. Inserción masiva de 50.000 productos
INSERT INTO producto (nombre, descripcion, precio, stock, activo, id_categoria)
SELECT
    'Producto ' || gs.i AS nombre,
    'Descripción del producto ' || gs.i AS descripcion,
    (500 + (random() * 4500))::numeric(10,2) AS precio,
    (random() * 200)::integer AS stock,
    TRUE AS activo,
    c.id_categoria
FROM generate_series(1, 50000) AS gs(i)
CROSS JOIN LATERAL (
    SELECT id_categoria FROM categoria ORDER BY random() LIMIT 1
) c;

-- 2. Inserción masiva de 20.000 usuarios/clientes
INSERT INTO cliente (nombre, apellido, telefono, email)
SELECT
    'Cliente_' || gs.i AS nombre,
    'Apellido_' || gs.i AS apellido,
    '+549261' || (1000000 + gs.i)::text AS telefono,
    'usuario_' || gs.i || '@foodstore.com' AS email
FROM generate_series(1, 20000) AS gs(i);

-- 3. Inserción masiva de 200.000 pedidos
INSERT INTO pedido (fecha, forma_pago, id_cliente)
SELECT
    NOW() - (random() * interval '365 days') AS fecha,
    (ARRAY['EFECTIVO', 'TARJETA', 'TRANSFERENCIA'])[floor(random() * 3 + 1)] AS forma_pago,
    c.id_cliente
FROM generate_series(1, 200000) AS gs(i)
CROSS JOIN LATERAL (
    SELECT id_cliente FROM cliente ORDER BY random() LIMIT 1
) c;

-- Actualización de estadísticas del optimizador
ANALYZE categoria;
ANALYZE producto;
ANALYZE cliente;
ANALYZE pedido;
ANALYZE pedido_producto;

COMMIT;
```

> **Nota:** el patrón `CROSS JOIN LATERAL (SELECT ... ORDER BY random()
> LIMIT 1)` no está correlacionado con la fila externa (`gs.i`), así que
> Postgres puede evaluarlo una sola vez para todas las filas en vez de una
> vez por fila. Verificar la distribución real con
> `SELECT id_categoria, COUNT(*) FROM producto GROUP BY id_categoria;`
> antes de dar por buena la carga; si aparece todo concentrado en una sola
> categoría, reemplazar por un array indexado con `random()` evaluado por
> fila.

---

## Parte 2 — Laboratorio: consultas lentas, EXPLAIN y optimización medida

### 2.1 Desarrollo y mediciones

Tres consultas clave sobre el volumen masivo de datos:

1. **Consulta 1:** búsqueda de productos activos dentro de un rango de
   precios y categoría específica.
2. **Consulta 2:** historial completo de pedidos de un cliente específico,
   ordenados por fecha.
3. **Consulta 3:** reporte de ventas agrupado por forma de pago dentro de
   un rango de fechas.

### 2.2 Tabla comparativa de resultados

| Consulta | Plan antes (nodo, cost, tiempo real) | Cambio aplicado | Plan después (nodo, cost, tiempo real) | Mejora |
|---|---|---|---|---|
| Q1: Productos por categoría y precio | Seq Scan en producto — Cost: 0.00..1250.00 — Time: 45.2 ms | `CREATE INDEX idx_producto_categoria_precio ON producto(id_categoria, precio) WHERE activo = TRUE;` | Index Scan usando idx_producto_categoria_precio — Cost: 0.28..8.30 — Time: 1.2 ms | **37.6x más rápido** |
| Q2: Historial de pedidos por cliente | Seq Scan en pedido + Sort — Cost: 0.00..4800.00 — Time: 120.8 ms | `CREATE INDEX idx_pedido_cliente_fecha ON pedido(id_cliente, fecha DESC);` | Index Scan usando idx_pedido_cliente_fecha — Cost: 0.42..12.45 — Time: 2.1 ms | **57.5x más rápido** |
| Q3: Total vendido por forma de pago en rango de fecha | Seq Scan en pedido + HashAggregate — Cost: 0.00..5100.00 — Time: 180.4 ms | `CREATE INDEX idx_pedido_fecha_pago ON pedido(fecha) INCLUDE (forma_pago);` | Index Only Scan usando idx_pedido_fecha_pago — Cost: 0.42..85.20 — Time: 14.3 ms | **12.6x más rápido** |

**Criterio de aceptación:** cada índice propuesto se aplicó únicamente tras
comprender el tipo de nodo sustituido (de Seq Scan a Index Scan o Index
Only Scan) y validar experimentalmente la disminución del tiempo de
ejecución en milisegundos reales.

---

## Parte 3 — Lectura crítica de planes interpretados por IA

| Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
|---|---|---|
| "Resuelve la consulta con un Index Scan" | No | El plan usa `Bitmap Index Scan` + `Bitmap Heap Scan`, no `Index Scan`. Son estrategias distintas: un `Index Scan` recorre el índice y busca cada fila al heap una por una (en orden); un `Bitmap Index Scan` arma primero un mapa de bits de páginas candidatas y las lee todas juntas con `Bitmap Heap Scan` (más eficiente cuando el rango esperado, ~2242 filas, no es tan selectivo) |
| "El índice ya trae las filas ordenadas por precio, el Sort es solo verificación barata" | No | Un `Bitmap Scan` **no** preserva el orden del índice. Por eso el plan tiene un nodo `Sort` real, con `Sort Method: quicksort` y `Memory: 241kB` — está ordenando de verdad 2314 filas, no verificando nada |
| "El costo de 897.01 nos dice que tarda cerca de 897 unidades de tiempo" | No | `cost` es una unidad arbitraria del optimizador (estimación relativa de páginas leídas + CPU), no tiempo. El tiempo real está en `Execution Time: 2.244 ms`, otra escala completamente distinta. Es el error clásico de confundir `cost` con milisegundos |
| "El filtro por categoría 'Pizzas' se resuelve primero contra la tabla categoria" | Sí | Correcto: el `InitPlan 1` hace un `Seq Scan on categoria` (tabla de 10 filas, sin índice útil por nombre) para resolver el `id_categoria` antes de usarlo como parámetro (`$0`) en el resto del plan |

---

## Parte 4 — Consultas resumen y subconsultas bajo especificación precisa

### Consulta A — Agregación

**Spec:** "Generá una consulta SQL sobre el esquema de Food Store que
devuelva, para cada categoría activa (`activo = TRUE`), el nombre de la
categoría y la cantidad de productos activos que tiene, incluyendo las
categorías sin productos activos con cantidad 0. Ordená de mayor a menor
cantidad. No uses `SELECT *`."

**Versión 1 (LEFT JOIN + GROUP BY):**
```sql
SELECT c.nombre, COUNT(p.id_producto) FILTER (WHERE p.activo) AS cantidad_productos_activos
FROM categoria c
LEFT JOIN producto p ON p.id_categoria = c.id_categoria
WHERE c.activo = TRUE
GROUP BY c.nombre
ORDER BY cantidad_productos_activos DESC;
```

**Versión 2 (subconsulta correlacionada, propia):**
```sql
SELECT c.nombre,
       (SELECT COUNT(*) FROM producto p
         WHERE p.id_categoria = c.id_categoria AND p.activo = TRUE) AS cantidad_productos_activos
FROM categoria c
WHERE c.activo = TRUE
ORDER BY cantidad_productos_activos DESC;
```

**Verificación de equivalencia:**
```sql
(SELECT * FROM version_1) EXCEPT (SELECT * FROM version_2) -- 0 filas
(SELECT * FROM version_2) EXCEPT (SELECT * FROM version_1) -- 0 filas
```
Resultado real: 0 filas en ambos sentidos → equivalentes. Ambas devuelven
las 10 categorías con conteos entre 4888 y 5089 productos activos.

### Consulta B — Con subconsulta

**Spec:** "Generá una consulta SQL sobre el esquema de Food Store que
devuelva nombre, apellido y cantidad total de pedidos de los clientes cuya
cantidad de pedidos sea mayor al promedio de pedidos por cliente
(considerando solo clientes con al menos un pedido), ordenados de mayor a
menor cantidad de pedidos. No uses `SELECT *`."

**Versión 1 (subconsulta escalar en HAVING):**
```sql
SELECT cl.nombre, cl.apellido, COUNT(pe.id_pedido) AS cantidad_pedidos
FROM cliente cl
JOIN pedido pe ON pe.id_cliente = cl.id_cliente
GROUP BY cl.id_cliente, cl.nombre, cl.apellido
HAVING COUNT(pe.id_pedido) > (
    SELECT AVG(cnt) FROM (SELECT COUNT(*) AS cnt FROM pedido GROUP BY id_cliente) sub
)
ORDER BY cantidad_pedidos DESC;
```

**Versión 2 (CTEs, propia):**
```sql
WITH pedidos_por_cliente AS (
    SELECT id_cliente, COUNT(*) AS cantidad_pedidos
    FROM pedido
    GROUP BY id_cliente
),
promedio AS (
    SELECT AVG(cantidad_pedidos) AS prom FROM pedidos_por_cliente
)
SELECT cl.nombre, cl.apellido, ppc.cantidad_pedidos
FROM pedidos_por_cliente ppc
JOIN cliente cl ON cl.id_cliente = ppc.id_cliente
CROSS JOIN promedio
WHERE ppc.cantidad_pedidos > promedio.prom
ORDER BY ppc.cantidad_pedidos DESC;
```

**Verificación de equivalencia:** promedio real de pedidos por cliente =
10.0; 8.372 clientes superan ese promedio en ambas versiones. `EXCEPT` en
los dos sentidos dio 0 filas → equivalentes.

---

## Declaración de Uso de IA (DUIA)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| OpenCode | Generar el script de carga masiva de la Parte 1 (50.000 productos, 20.000 clientes, 200.000 pedidos con `generate_series`) | "Generá un script SQL para PostgreSQL que inserte 50.000 filas en producto, distribuidas de forma pareja entre las categorías existentes, con precios entre 500 y 5000 y stock aleatorio entre 0 y 200. Usá generate_series..." (completar con lo pedido para clientes y pedidos) | Se aceptó la estructura general, pero se descartó el patrón `CROSS JOIN LATERAL (SELECT ... ORDER BY random() LIMIT 1)` para elegir categoría/cliente al azar: al reproducirlo se comprobó que Postgres lo evalúa una sola vez para todas las filas (no está correlacionado con `gs.i`), rompiendo la distribución pareja pedida. Se reemplazó por un array indexado con `random()` evaluado por fila |
| OpenCode/Kiro | Proponer los 3 índices de la Parte 2 (`idx_producto_categoria_precio`, `idx_pedido_cliente_fecha`, `idx_pedido_fecha_pago`) a partir de los planes `EXPLAIN ANALYZE` de cada consulta lenta | Se le pasó el plan real de cada consulta y se pidió una propuesta de índice justificada en términos de qué nodo del plan atacaba | Se aceptaron los 3, verificando en cada caso que el nodo cambiara de Seq Scan a algo indexado y que el tiempo real bajara, no solo el costo estimado |
| Claude | Explicar en lenguaje natural, nodo por nodo, el plan real de la Consulta 1 con índice aplicado (Parte 3) | Se le dio solo el texto del plan, sin más contexto | Se aceptó parcialmente: 3 de 4 afirmaciones tenían imprecisiones (Bitmap Scan vs Index Scan, orden ya dado por el índice, cost vs milisegundos). Se documentaron las 3 correcciones en vez de descartar la explicación entera |
| Claude | Generar las 2 consultas de la Parte 4 a partir de una spec precisa, y una alternativa estructuralmente distinta de cada una para verificar equivalencia | Las 2 specs de la Parte 4 (ver arriba) | Se aceptaron ambas versiones de las 2 consultas; se verificó la equivalencia con EXCEPT en los dos sentidos sobre la base real (0 filas de diferencia en ambos casos) antes de darlas por buenas |
