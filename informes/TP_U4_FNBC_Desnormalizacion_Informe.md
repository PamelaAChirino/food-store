# Trabajo Práctico — Unidad 4

## Forma Normal de Boyce-Codd y Desnormalización Controlada en Food Store

**Integrantes:** Pamela Chirino, Lucas Agüero, Mayra Mulé
**Proyecto integrador de referencia:** Food Store
**Entregables asociados:** `tp_fnbc_control_lote.sql` y `tp_desnormalizacion_top_categorias.sql`

---

## Parte 1 — Análisis y aplicación de la FNBC: ControlLoteAlmacen

Esquema inicial: `control_lote_almacen(lote_id, deposito_id, responsable_control_id)` con clave primaria `(lote_id, deposito_id)` y la instancia de ejemplo `(501, 30, 801)`, `(502, 30, 801)`, `(503, 31, 802)`.

### a) Dependencias funcionales

A partir de la regla de negocio relevada con logística:

- **DF1:** {LoteID, DepositoID} → {ResponsableControlID}. Para un lote y un depósito interviniente dados, el responsable de control queda unívocamente determinado.
- **DF2:** {ResponsableControlID} → {DepositoID}. Cada responsable pertenece, como dato maestro del personal, a un único depósito.

### b) Clausuras y claves candidatas

Esquema R = {LoteID, DepositoID, ResponsableControlID}. Clausuras de los subconjuntos razonables:

| Subconjunto X | X⁺ (clausura) | ¿Superclave? |
|---|---|---|
| {LoteID} | {LoteID} | No |
| {DepositoID} | {DepositoID} | No |
| {ResponsableControlID} | {ResponsableControlID, DepositoID} (por DF2) | No |
| {DepositoID, ResponsableControlID} | {DepositoID, ResponsableControlID} | No |
| {LoteID, DepositoID} | {LoteID, DepositoID, ResponsableControlID} (por DF1) | **Sí** |
| {LoteID, ResponsableControlID} | {LoteID, ResponsableControlID, DepositoID} (por DF2) | **Sí** |

Ambas superclaves son minimales (ningún subconjunto propio determina todo R), por lo tanto el conjunto **completo de claves candidatas** es: **{LoteID, DepositoID}** y **{LoteID, ResponsableControlID}**.

**Atributos primos:** LoteID, DepositoID y ResponsableControlID (los tres integran alguna clave candidata). **Atributos no primos:** ninguno.

### c) Evaluación de FNBC

Definición: R está en FNBC si, para toda dependencia funcional no trivial X → Y, X es superclave de R.

- DF1 cumple: su determinante {LoteID, DepositoID} es clave candidata.
- DF2 **viola** la FNBC: es no trivial y su determinante {ResponsableControlID} no es superclave, porque {ResponsableControlID}⁺ = {ResponsableControlID, DepositoID} no contiene a LoteID.

**Conclusión:** `control_lote_almacen` **no está en FNBC**. Observación: sí está en 3FN, porque DepositoID es un atributo primo; por eso la consigna exige usar la definición de FNBC y no la de 3FN.

### d) Anomalías

**Actualización.** Si el responsable 801 se reasigna al depósito 32, hay que modificar las dos filas donde aparece, (501, 30, 801) y (502, 30, 801). Si solo se actualiza una, queda (501, 32, 801) junto a (502, 30, 801): el responsable 801 figura en dos depósitos y se viola DF2 sin que el esquema lo impida.

**Inserción.** No se puede dar de alta al responsable 803 en el depósito 32 mientras no controle ningún lote: la fila necesita un `lote_id`, que es parte de la clave primaria y no admite NULL. El dato maestro «803 pertenece al depósito 32» no puede existir por sí solo.

**Borrado.** Si se elimina el único lote controlado desde el depósito 31, la fila (503, 31, 802), se pierde también el hecho de que el responsable 802 pertenece al depósito 31, aunque ese dato siga siendo válido.

### e) Descomposición sin pérdida (script SQL)

Algoritmo: para la DF violatoria X → Y con X = {ResponsableControlID} e Y = {DepositoID}, se generan R1 = X ∪ Y = {ResponsableControlID, DepositoID} y R2 = R − (Y − X) = {LoteID, ResponsableControlID}. R1 queda en FNBC (su única DF tiene como determinante a la clave) y R2 también (solo tiene DF triviales; su clave es la totalidad de sus atributos).

```sql
CREATE TABLE responsable_deposito_fnbc (
    responsable_control_id BIGINT PRIMARY KEY, -- REFERENCES usuario(id)
    deposito_id             BIGINT NOT NULL     -- REFERENCES deposito(id)
);

CREATE TABLE control_lote_fnbc (
    lote_id                 BIGINT NOT NULL,    -- REFERENCES lote(id)
    responsable_control_id  BIGINT NOT NULL
        REFERENCES responsable_deposito_fnbc(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

CREATE OR REPLACE VIEW v_control_lote_almacen_fnbc AS
SELECT cl.lote_id, rd.deposito_id, cl.responsable_control_id
FROM control_lote_fnbc cl
JOIN responsable_deposito_fnbc rd
  ON rd.responsable_control_id = cl.responsable_control_id;
```

> **Nota de adaptación:** las `REFERENCES` a `lote`, `deposito` y `usuario` están comentadas porque esas tablas no existen en el proyecto real de Food Store — Parte 1 introduce un escenario nuevo (control de lotes en depósito) que extiende el modelo original, no algo ya presente en la base. Quedan comentadas a modo de documentación del diseño conceptual; no se activan al correr sobre la base real porque esas tablas maestras no forman parte del esquema actual del proyecto.

### f) Justificación de la reunión sin pérdida y migración

El atributo común de la descomposición es ResponsableControlID. Es **clave primaria (superclave) de R1**. Por el criterio de descomposición binaria sin pérdida (R1 ∩ R2 → R1 o R1 ∩ R2 → R2), la reunión natural R1 ⋈ R2 reconstruye exactamente R: cada fila de R2 se empareja con una sola fila de R1, por lo que no aparecen tuplas espurias ni se pierden tuplas originales.

```sql
INSERT INTO responsable_deposito_fnbc (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM control_lote_almacen_legacy
ON CONFLICT (responsable_control_id) DO NOTHING;

INSERT INTO control_lote_fnbc (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id
FROM control_lote_almacen_legacy
ON CONFLICT DO NOTHING;
```

Verificación de equivalencia mediante la vista de compatibilidad (ambas consultas deben devolver 0 filas):

```sql
(SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen_legacy)
EXCEPT
(SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen_fnbc);

(SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen_fnbc)
EXCEPT
(SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen_legacy);
```

**Resultado (capturas DBeaver):** primer EXCEPT (legacy menos vista) → 0 filas. Segundo EXCEPT (vista menos legacy) → 0 filas.

> **Verificado nuevamente de forma independiente** contra una base de prueba en PostgreSQL 16: ambos `EXCEPT` dan 0 filas, confirmando la equivalencia.

**Observación sobre las dependencias.** La descomposición es sin pérdida pero no preserva DF1 ({LoteID, DepositoID} → ResponsableControlID) como restricción de una sola tabla, algo habitual en FNBC. Esa regla queda cubierta por el chequeo opcional de la sección 6 del script (debe dar 0 filas), o por un disparador si se quiere imponerla.

---

## Parte 2 — Consulta con desnormalización controlada (Top Categorías)

### a) Consulta original y plan de ejecución

Top 5 de categorías por monto vendido en el día, uniendo `pedido_producto`, `producto`, `categoria` y `pedido`:

```sql
EXPLAIN ANALYZE
SELECT c.nombre AS categoria,
       SUM(pp.cantidad * pp.precio_unitario) AS total_vendido
FROM pedido_producto pp
JOIN producto pr ON pr.id_producto = pp.id_producto
JOIN categoria c ON c.id_categoria = pr.id_categoria
JOIN pedido ped ON ped.id_pedido = pp.id_pedido
WHERE ped.fecha >= '2026-09-15'::date
  AND ped.fecha <  '2026-09-15'::date + INTERVAL '1 day'
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;
```

El plan tiene un costo estimado de **1286.49** y un tiempo de ejecución de **≈ 1.63 ms** (tiempo real del nodo raíz). El costo lo domina el nodo `Nested Loop` (cost 6.32..1284.95), que reúne `pedido`, `pedido_producto`, `producto` y `categoria`: lee `pedido` con un `Bitmap Heap Scan` sobre `idx_pedido_fecha` (142 filas estimadas) y repite `Index Scans` sobre `pedido_producto_pkey` y `producto_pkey` por cada fila de `pedido` (el `Nested Loop` devuelve 112 filas reales). Encima trabajan un `HashAggregate` (GROUP BY), un `Sort` y el `Limit`.

*Captura 1: EXPLAIN ANALYZE de la consulta original (costo 1286.49)*

### b) Patrón elegido y justificación

Se eligió una **vista materializada** (`mv_top_categorias_dia`) con índice único sobre `(fecha, categoria)`. La evidencia medida en (a) es un plan de costo 1286.49 y ≈ 1.63 ms, dominado por un `Nested Loop` que reúne cuatro tablas transaccionales en cada consulta del panel, cuando el resultado (un total por categoría y por día) cambia mucho más lento que la frecuencia con que se lee. La sincronización con la fuente de verdad la garantiza `REFRESH MATERIALIZED VIEW CONCURRENTLY`, ejecutado periódicamente sin bloquear las lecturas, más un script de auditoría que compara la vista contra las tablas originales; el costo aceptado es que entre dos refrescos el dato puede estar atrasado como máximo un período. Es reversible sin pérdida de información: la vista es puramente derivada, `pedido`, `pedido_producto`, `producto` y `categoria` siguen siendo la única fuente de verdad, y basta un `DROP MATERIALIZED VIEW` para volver al diseño normalizado.

### c) Implementación

```sql
CREATE MATERIALIZED VIEW mv_top_categorias_dia AS
SELECT ped.fecha::date                       AS fecha,
       c.nombre                              AS categoria,
       SUM(pp.cantidad * pp.precio_unitario) AS total_vendido
FROM pedido_producto pp
JOIN producto  pr  ON pr.id_producto  = pp.id_producto
JOIN categoria c   ON c.id_categoria  = pr.id_categoria
JOIN pedido    ped ON ped.id_pedido   = pp.id_pedido
GROUP BY ped.fecha::date, c.nombre
WITH DATA;

CREATE UNIQUE INDEX ux_mv_top_cat_dia
    ON mv_top_categorias_dia (fecha, categoria);

-- Sincronización (periódica, p. ej. cada minuto)
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_categorias_dia;
```

### d) Consulta optimizada y comparación antes / después

```sql
EXPLAIN ANALYZE
SELECT categoria, total_vendido
FROM mv_top_categorias_dia
WHERE fecha = '2026-09-15'
ORDER BY total_vendido DESC
LIMIT 5;
```

| Métrica | Antes (4 tablas) | Después (vista materializada) |
|---|---|---|
| Tiempo de ejecución | ≈ 1.63 ms | 0.249 ms (planning 0.158 ms) |
| Costo estimado del plan | 1286.49 | 36.93 |
| Nodo dominante | `Nested Loop` (cost 6.32..1284.95) | `Seq Scan` on `mv_top_categorias_dia` (cost 0.00..36.88) |

El costo estimado baja de 1286.49 a 36.93 (unas 35 veces menos) y el tiempo real de ≈ 1.63 ms a 0.249 ms (unas 6.5 veces menos), porque el plan deja de reunir las cuatro tablas y lee filas ya agregadas. El planificador usa un `Seq Scan` y no el índice único: la vista es chica (≈ 1830 filas; el filtro descartó 1825) y recorrerla entera resulta más barato que un acceso por índice. El índice `ux_mv_top_cat_dia` cumple su papel en la sincronización (`REFRESH ... CONCURRENTLY` lo exige).

*Captura 2: EXPLAIN ANALYZE de la consulta optimizada (costo 36.93, 0.249 ms)*

### e) Script de auditoría

Compara la vista con la fuente de verdad para la fecha auditada mediante un `FULL OUTER JOIN`. Debe devolver 0 filas:

```sql
SELECT
    v.categoria,
    v.total_vendido AS valor_materializado,
    COALESCE(r.total_real, 0) AS valor_real
FROM mv_top_categorias_dia v
FULL OUTER JOIN (
    SELECT c.nombre AS categoria,
           SUM(pp.cantidad * pp.precio_unitario) AS total_real
    FROM pedido_producto pp
    JOIN producto pr ON pr.id_producto = pp.id_producto
    JOIN categoria c ON c.id_categoria = pr.id_categoria
    JOIN pedido ped ON ped.id_pedido = pp.id_pedido
    WHERE ped.fecha >= '2026-09-15'::date
      AND ped.fecha <  '2026-09-15'::date + INTERVAL '1 day'
    GROUP BY c.nombre
) r ON r.categoria = v.categoria
WHERE v.fecha = '2026-09-15'
  AND (v.total_vendido IS DISTINCT FROM r.total_real);
```

Resultado sobre la base migrada: **0 filas (No data)**.

*Captura 3: resultado de la auditoría (sin filas)*

El script audita la fecha indicada.

> **Corrección aplicada tras la verificación (ver `TP_U4_FNBC_Desnormalizacion_Observaciones.md`):** al comprobar este script contra un escenario armado a propósito (una categoría con ventas nuevas en el día auditado, sin refrescar aún la vista), el punto (e) **no detectó el faltante** — devolvió 0 filas igual, porque filtra por `v.fecha` recién en el `WHERE` externo, después del `JOIN` por categoría. Se agregó al archivo `tp_desnormalizacion_top_categorias.sql` la sección **3b**, que compara por `(fecha, categoria)` en conjunto y filtra la fecha *antes* del `JOIN`, detectando correctamente categorías presentes en la fuente pero ausentes en la vista materializada para cualquier fecha. Probada con el mismo escenario, 3b sí detecta la diferencia; con la vista sincronizada, da 0 filas como se espera.

---

*Documento convertido a Markdown a partir del informe original en PDF, preservando su contenido íntegro, para facilitar el diff en git. Única adición: la nota de corrección de la sección (e) y la observación de verificación independiente en la Parte 1.*
