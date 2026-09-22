# Declaración de Uso de IA (DUIA) — Food Store

Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mule


## Unidad 1 (TP2 — Semana 2): Integridad, transacciones y concurrencia

### Parte 1 — Restricciones de integridad

| Herramienta | OpenCode, con GitHub Models como proveedor |

| Spec o prompt utilizado | 

"Necesito 3 restricciones para el proyecto Food Store: 
(1) un CHECK en `pedido` para que `fecha` no pueda ser futura; 
(2) un trigger BEFORE INSERT en `pedido_producto` que impida vender un producto con `activo = FALSE`; 
(3) en el mismo trigger, que impida vender más `cantidad` que el `stock` disponible del producto y lo descuente al vender. Usar `FOR UPDATE` al leer el stock para evitar condiciones de carrera entre ventas concurrentes." 

| Qué generó | 

1) Constraint `chk_pedido_fecha_no_futura` (`CHECK fecha <= now()`), agregado como constraint de tabla dentro de `CREATE TABLE pedido`. 
2) Función `fn_validar_venta_pedido_producto()` y trigger `trg_pedido_producto_venta` (BEFORE INSERT ON `pedido_producto`), que usa `SELECT ... FOR UPDATE` para bloquear la fila del producto, valida que exista, que esté activo y que haya stock suficiente, y descuenta el stock |

| Qué se aceptó | 

Todo el código tal cual lo propuso OpenCode, sin cambios. Incluye una validación extra que no estaba en el prompt original: si `id_producto` no existe, el trigger corta con un `RAISE EXCEPTION` claro en vez de dejar que falle más adelante por la FK. Se mantuvo por ser una mejora razonable |

| Qué se modificó o descartó, y por qué | 

Nada se modificó a mano. Los nombres de función/trigger que eligió OpenCode son distintos a los de un borrador previo; se dejaron los de OpenCode porque son los que quedaron aplicados en el `schema.sql` real |

| Verificación realizada | 

`schema.sql` completo corrido de punta a punta sin errores. Dentro de `BEGIN; ... ROLLBACK;` con `SAVEPOINT` por caso, se probaron 6 casos: pedido válido, fecha futura (falla), venta válida con descuento de stock confirmado, producto inactivo (falla), stock insuficiente (falla), producto inexistente (falla). Los 6 dieron el resultado esperado |

### Parte 2 — Concurrencia
| Herramienta | Claude (verificación posterior en PostgreSQL 16, dos sesiones psql/DBeaver reales) |

| Spec o prompt utilizado | 

"Explicá qué pasó en cada escenario de concurrencia reproducido sobre la tabla `producto`, y qué nivel de aislamiento (o mecanismo de bloqueo) lo evitaría. Necesito documentar la prueba práctica usando dos sesiones concurrentes en DBeaver con `FOR UPDATE`." |

| Qué generó | 

Explicación de lectura no repetible, lectura fantasma y espera por bloqueo, con el nivel de aislamiento sugerido para cada una |

| Qué se aceptó | 

Las explicaciones teóricas de los niveles de aislamiento y, para el control de stock, la implementación del bloqueo pesimista con `SELECT ... FOR UPDATE` dentro del trigger |

| Qué se modificó o descartó, y por qué | 

Se ajustó la explicación del escenario de lectura fantasma: la IA dijo que `REPEATABLE READ` no garantiza evitar fantasmas según el estándar SQL, pero el motor real (PostgreSQL) sí evitó el fantasma en la prueba, por usar snapshot isolation. Se documentó la discrepancia en vez de descartarla |

| Verificación realizada | 

Simulación práctica en DBeaver con dos solapas (Sesión 1 y 2) sobre la base real. Caso reproducido: Sesión 1 compra la última unidad de un producto (stock=1) dentro de una transacción abierta; Sesión 2 intenta otra compra del mismo producto y queda en espera por el `FOR UPDATE`. Al hacer `COMMIT` la Sesión 1, el stock baja a 0 y la Sesión 2 se destraba, reevalúa y aborta con `[P0001]: Stock insuficiente. Disponible 0 y se solicitan 1` — se previno con éxito la sobreventa |

### Parte 3 — Lectura crítica

| Herramienta | Claude |

| Spec o prompt utilizado |

 "Analizá qué haría realmente cada uno de estos dos scripts SQL tal como están escritos, por qué no cumple la consigna que dice cumplir, y dame la versión corregida." |

| Qué generó | 

Análisis del Script 1 (`UPDATE` sin `WHERE`) y Script 2 (`DELETE` con `NOT IN` + `NULL`), más las versiones corregidas |

| Qué se aceptó | El análisis y la corrección de ambos scripts |

| Qué se modificó o descartó, y por qué |

 Ninguno — se verificó el Script 2 con una prueba mínima en PostgreSQL (tabla temporal con un `NULL` en la FK) antes de aceptarla |

| Verificación realizada |

Prueba en PostgreSQL con tablas temporales reproduciendo la trampa de `NOT IN` con `NULL` |


## Unidad 2 (TP3/TP4 — Semanas 3 y 4): Optimización de consultas

| Herramienta | Para qué se usó | Prompt / spec (resumen)
| Se aceptó / se descartó — por qué |

| OpenCode | Carga masiva (50.000 productos, 20.000 clientes, 200.000 pedidos, ~600.000 líneas de detalle) |

Generar scripts con `generate_series` para poblar la base a escala | Se aceptó la estructura general, pero se descartó el patrón `CROSS JOIN LATERAL (SELECT ... ORDER BY random() LIMIT 1)`: al no estar correlacionado con la fila externa, Postgres lo evalúa una sola vez para todas las filas, rompiendo la distribución pareja pedida. Se corrigió generando el valor aleatorio en el `SELECT` de una CTE previa |

| OpenCode/Kiro | 

Proponer 5 índices a partir de planes `EXPLAIN ANALYZE` reales (TP3: categoría+precio, cliente+fecha, forma de pago+fecha; TP4: sobre pedido_producto y sobre pedido(fecha)) 

| Se pasó cada plan real y se pidió una propuesta justificada en el nodo concreto que atacaba | 3 de los 5 se aceptaron con mejora real confirmada (37.6x, 57.5x, 12.6x). 2 se probaron y **no mejoraron el tiempo real** — se documentaron igual en vez de descartarlos en silencio (ver TP4_Semana4.md, Parte 1) |

| Claude | 

Explicar en lenguaje natural planes reales (TP3: un plan con `Bitmap Scan`; TP4: un plan con 3 `Nested Loop` anidados), dándole solo el texto del plan | — | Ambos ejercicios encontraron imprecisiones reales de la IA: confundir `Bitmap Scan` con `Index Scan`, asumir orden que un `Bitmap Scan` no garantiza, confundir `cost` con milisegundos, y confundir tabla externa/interna en un `Nested Loop`. Documentado con evidencia (`loops=`, `Sort Method`) en cada caso |

| Claude | 

Generar consultas (agregación, subconsulta, ranking con función de ventana) a partir de specs precisas, más una segunda versión estructuralmente distinta de cada una | 
Specs detalladas en TP3_Semana3.md y TP4_Semana4.md | Se aceptaron todas las versiones generadas; cada par se verificó con `EXCEPT` en los dos sentidos contra la base real (0 filas de diferencia en todos los casos) antes de darlas por buenas |

*Detalle completo de cada interacción: ver `informes/TP3_Semana3.md` e
`informes/TP4_Semana4.md`, sección DUIA de cada documento.*


## Unidad 3 (TP5 — Semana 5): Índices, vistas y vistas materializadas

- **Herramienta utilizada:** Asistente de Inteligencia Artificial (Gemini / Kiro / OpenCode).
- **Propósito:** Asistencia en la redacción de especificaciones técnicas (`specs/`), diseño de scripts SQL para vistas y vistas materializadas, y estructuración del informe de mediciones.
- **Validación:** Los scripts y estructuras fueron analizados línea por línea y adaptados para su correcta ejecución.

### Bitácora de decisiones técnicas

**1. Caso de sobreindexación descartado (Parte A):** se evaluó, con
asistencia de IA, la creación de un índice independiente adicional sobre
`id_categoria` en `producto` para agilizar los filtrados. Se **descartó**
por considerarlo redundante: la tabla ya contaba con un índice compuesto
que integraba el filtrado por categoría y el ordenamiento por precio;
agregar un índice aislado duplicaba espacio en disco y generaba una
penalización innecesaria en `INSERT`, sin aportar mejoras reales al
planificador.

**2. Verificación de equivalencia de resultados (Parte B):** se generaron
las vistas relacionales (`v_productos_vigentes`, `v_pedidos_usuarios`,
entre otras) con asistencia de OpenCode. Se **aceptó** la estructura de los
`JOIN` y filtros tras la verificación de equivalencia requerida: se
ejecutaron manualmente las consultas equivalentes en crudo contra la base
y se contrastaron con las vistas, comprobando coincidencia exacta de filas
y columnas. Se validó también el criterio de seguridad, omitiendo la
columna de contraseña en la vista de usuarios.

*Detalle completo (specs, índices descartados con medición, las 4 vistas,
la vista materializada): ver `informes/informe_mediciones.md` y `specs/`.*


## TPI — Procedimiento almacenado

| Herramienta | Claude |

| Spec o prompt utilizado | 

Diseñar un procedimiento `CALL`-invocable que registre un pedido completo (cabecera + N líneas) como operación atómica, reutilizando la validación ya existente en el trigger de `pedido_producto` |

| Qué generó |

 `sp_registrar_pedido(p_id_cliente, p_forma_pago, p_ids_producto[], p_cantidades[], INOUT p_id_pedido)` |

| Qué se aceptó | La estructura general (cabecera + loop de inserts) |

| Qué se modificó o descartó, y por qué |

 Se corrigió un bug real detectado al probarlo: un `INSERT ... SELECT ... WHERE id_producto = X` con un producto inexistente no tira error, inserta 0 filas en silencio — el pedido quedaba con menos líneas de las pedidas sin ningún aviso. Se agregó una validación explícita de existencia (`IF NOT EXISTS ... RAISE EXCEPTION`) antes de cada insert |

| Verificación realizada | 

Caso válido (3 líneas, quedan las 3) y caso inválido (un producto inexistente en medio del array): confirmado que no queda ninguna fila suelta cuando falla — atomicidad real |
