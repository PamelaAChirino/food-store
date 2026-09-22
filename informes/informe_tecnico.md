# Informe técnico — TPI Food Store (Entrega parcial: Unidades 1-3)

Integrantes: Mayra Mule, Pamela Chirino, Lucas Agüero
Motor: PostgreSQL 16, con PL/pgSQL.

---

## 1. Qué implementamos en cada unidad

### Unidad 1 — Integridad, transacciones y concurrencia
- Modelo ER, paso a relacional y normalización hasta 3FN (5 tablas:
  `categoria`, `cliente`, `producto`, `pedido`, `pedido_producto` como tabla
  intermedia N:M).
- DDL completo con tipos (`ENUM forma_pago_enum`, `TIMESTAMPTZ`, columnas
  `IDENTITY`), PK/FK con `ON DELETE RESTRICT`, y `CHECK`/`UNIQUE` para reglas
  de negocio (precio y stock no negativos, email único, fecha de pedido no
  futura).
- Trigger `trg_pedido_producto_venta` (función PL/pgSQL
  `fn_validar_venta_pedido_producto`): antes de vender, valida que el
  producto exista, esté activo y tenga stock suficiente, y descuenta el
  stock — usando `SELECT ... FOR UPDATE` para que dos ventas concurrentes
  del mismo producto no lean el mismo stock viejo.
- Protocolo de seguridad de la cátedra (`protocolo_seguridad.md`): copia de
  trabajo, transacción reversible, respaldo antes de todo DDL.
- Laboratorio de concurrencia (`informe_concurrencia.md`): 3 escenarios
  reproducidos con dos sesiones psql reales — lectura no repetible, lectura
  fantasma, espera por bloqueo — bajo `READ COMMITTED` y `REPEATABLE READ`.
- Ejercicio de lectura crítica sobre dos scripts peligrosos (`UPDATE` sin
  `WHERE`, `DELETE` con `NOT IN` + `NULL`).

### Unidad 2 — Optimización de consultas
- Carga masiva para tener volumen real: 50.000 productos, 20.000 clientes,
  200.000 pedidos, ~600.000 líneas de detalle.
- Optimización de 3 consultas con filtro simple (categoría+precio,
  cliente+fecha, forma de pago+fecha) midiendo `EXPLAIN ANALYZE` antes y
  después de cada índice.
- Optimización de consultas analíticas con múltiples JOIN (facturación por
  categoría y mes, ranking de clientes por gasto), identificando el
  algoritmo de join elegido por el optimizador (`Hash Join`, `Nested Loop`)
  en cada caso.
- Consultas resumen, subconsultas correlacionadas y funciones de ventana
  (`RANK()`), con verificación de equivalencia contra una versión alternativa
  escrita a mano (`EXCEPT` en ambos sentidos).
- Dos ejercicios de lectura crítica de planes reales interpretados por IA,
  detectando errores concretos (confundir `cost` con milisegundos, confundir
  tabla externa/interna en un `Nested Loop`, asumir orden que un `Bitmap
  Scan` no garantiza).

### Unidad 3 — Índices, vistas y objetos programables
- Plan de indexado: 1 índice aceptado (`idx_producto_nombre_vig`, con
  `text_pattern_ops` para que sirva en `LIKE 'prefijo%'`) y 2 descartados con
  evidencia (baja cardinalidad, agregación sobre casi toda la tabla).
- 4 vistas (`v_productos_vigentes`, `v_pedidos_cliente`, `v_detalle_pedido`,
  `v_cliente_publico` como vista de seguridad), cada una verificada contra su
  consulta manual equivalente.
- Vista materializada `mv_facturacion_categoria_mes` con índice único para
  `REFRESH CONCURRENTLY`.
- Procedimiento almacenado `sp_registrar_pedido` (PL/pgSQL, invocado con
  `CALL`): registra un pedido completo (cabecera + N líneas de detalle) como
  una única operación atómica.

---

## 2. Cómo probamos cada elemento

Ningún script se aplicó sin antes probarse. El patrón fue siempre el mismo:

1. **Restricciones e integridad:** `BEGIN; ... ROLLBACK;` con `SAVEPOINT` por
   caso, probando tanto el camino válido como cada camino inválido esperado
   (fecha futura, producto inactivo, stock insuficiente, producto
   inexistente).
2. **Concurrencia:** dos sesiones `psql` reales corridas en paralelo,
   comparando la salida real bajo distintos niveles de aislamiento, no una
   predicción teórica.
3. **Índices:** `EXPLAIN (ANALYZE, BUFFERS)` antes y después de cada
   `CREATE INDEX`, mirando tanto el tiempo real de ejecución como el nodo
   del plan elegido (no solo si bajó el tiempo, sino si el índice
   efectivamente se usó).
4. **Vistas:** `(SELECT * FROM vista) EXCEPT (SELECT ... consulta manual)`
   en ambos sentidos — solo se dio una vista por válida con 0 filas de
   diferencia.
5. **Procedimiento:** un caso válido (3 líneas, quedan las 3) y un caso
   inválido (un producto inexistente en medio del array), confirmando que no
   queda ninguna fila suelta cuando falla — ver el hallazgo del punto 3.

---

## 3. Qué resultados obtuvimos

- Las 3 partes de integridad (CHECK de fecha, producto activo, stock
  suficiente) rechazan exactamente los casos que deben rechazar y aceptan
  los que deben aceptar.
- Bajo `READ COMMITTED` se reprodujeron lectura no repetible y lectura
  fantasma; bajo `REPEATABLE READ`, ninguna de las dos ocurrió — con una
  particularidad real: el estándar SQL no garantiza que `REPEATABLE READ`
  evite fantasmas, pero en PostgreSQL (snapshot isolation) sí los evitó en
  nuestra prueba. Documentado como discrepancia, no ocultado.
- `idx_producto_nombre_vig`: 5.1 ms → 0.1 ms (~51x). Los otros dos índices
  propuestos se descartaron con datos: uno mejoraba solo ~19% (no justifica
  el costo de mantenerlo), el otro no lo usó nunca el planner.
- Vista materializada: 943 ms → 1.16 ms (~812x) contra la consulta original.
- Procedimiento `sp_registrar_pedido`: en la primera versión, un producto
  inexistente no generaba error — insertaba silenciosamente menos líneas de
  las pedidas (`INSERT ... SELECT` sobre un `WHERE` que no matchea ninguna
  fila no falla, simplemente inserta cero filas). Se corrigió agregando una
  validación explícita de existencia antes de insertar; verificado que ahora
  sí aborta todo el pedido sin dejar filas sueltas.

---

## 4. Qué consultas optimizamos y qué diferencias encontramos

| Consulta | Antes | Índice/cambio | Después | Resultado |
|---|---|---|---|---|
| Productos por categoría y precio | Seq Scan, 45.2 ms | `idx_producto_categoria_precio` | Index Scan, 1.2 ms | 37.6x |
| Historial de pedidos por cliente | Seq Scan + Sort, 120.8 ms | `idx_pedido_cliente_fecha` | Index Scan, 2.1 ms | 57.5x |
| Búsqueda de productos por nombre | Seq Scan, 5.1 ms | `idx_producto_nombre_vig` (con `text_pattern_ops`) | Index Scan, 0.1 ms | ~51x |
| Facturación por categoría y mes (sin materializar) | — | Vista materializada + índice único | 943 ms → 1.16 ms | ~812x |
| Facturación por categoría, sin filtro (agregación de toda la tabla) | 3× Hash Join, 7196 ms | Índice sobre `pedido_producto(id_producto)` | Sin cambios reales — el índice nunca se usó; la baja observada (7196→1711 ms) era caché, no el índice | Sin mejora real (documentado) |
| Pedidos por forma de pago | Seq Scan, 17.8 ms | `idx_pedido_forma_pago` | Bitmap Heap Scan, 14.5 ms | Solo ~19% — descartado por baja cardinalidad (3 valores posibles) |
| Facturación por categoría, un mes específico | 3× Hash Join, 250.1 ms | `idx_pedido_fecha` | Bitmap Heap Scan, 320.1 ms | **Empeoró** — filtro no selectivo (~74% de las filas), descartado |

La conclusión general: un índice no es gratis ni siempre ayuda. En 3 de los
7 casos probados, el índice propuesto no mejoró el tiempo real (o lo
empeoró), y en todos esos casos se pudo explicar por qué mirando el plan
real — baja selectividad, agregación sobre casi toda la tabla, o una mejora
que en realidad venía de la caché y no del índice.

---

## 5. Uso de otras herramientas de IA

Además de OpenCode y Kiro (indicadas por la cátedra), usamos **Claude**
(Anthropic) para:

- **Explicar planes de `EXPLAIN ANALYZE` en lenguaje natural**, como
  ejercicio de lectura crítica (Unidad 2, Partes 2 de las Semanas 3 y 4):
  se le dio solo el texto del plan, sin más contexto, y se contrastó cada
  afirmación contra el plan real. En los dos ejercicios, varias afirmaciones
  resultaron imprecisas (confundir `cost` con milisegundos, confundir tabla
  externa/interna en un `Nested Loop`, asumir que un `Bitmap Scan` devuelve
  resultados ordenados) — se documentaron como correcciones, no se
  descartó la explicación completa.
- **Generar consultas a partir de una especificación precisa** y una
  segunda versión con estructura distinta, para el ejercicio de
  equivalencia de resultados (subconsulta vs. `JOIN`+agregación, función de
  ventana vs. subconsulta correlacionada) — siempre verificadas con `EXCEPT`
  antes de aceptarlas.
- **Verificación cruzada de scripts de carga masiva**: un primer intento de
  `CROSS JOIN LATERAL (SELECT ... ORDER BY random() LIMIT 1)` para
  distribuir productos entre categorías resultó tener un problema real: al
  no estar correlacionada con la fila externa, PostgreSQL la evaluaba una
  sola vez para todas las filas en vez de una vez por fila, dejando casi
  todos los productos en una sola categoría al azar. Se detectó recién al
  verificar la distribución real (`GROUP BY id_categoria`) y se corrigió
  generando el valor aleatorio directamente en el `SELECT` de una CTE previa.

En todos los casos se aplicó el mismo criterio que exige la cátedra para
OpenCode/Kiro: ninguna propuesta se aceptó por default, todo se verificó
contra el motor real antes de darlo por bueno.
