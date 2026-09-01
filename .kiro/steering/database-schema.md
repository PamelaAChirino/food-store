# Esquema de Base de Datos — Food Store

Motor: **PostgreSQL**
Archivo fuente: `schema.sql`

## Diagrama de relaciones (texto)

```
categoria (1) ──< producto (N)
cliente   (1) ──< pedido   (N)
pedido    (N) >──< producto (N)  →  pedido_producto
```

## Tipo ENUM

```sql
CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');
```

---

## Tablas

### categoria

| Columna | Tipo | Restricciones |
|---|---|---|
| `id_categoria` | `BIGINT GENERATED ALWAYS AS IDENTITY` | PRIMARY KEY |
| `nombre` | `VARCHAR(100)` | NOT NULL, UNIQUE |
| `descripcion` | `TEXT` | — |
| `activo` | `BOOLEAN` | NOT NULL, DEFAULT TRUE |

- `nombre` es clave candidata (UNIQUE).
- `activo = FALSE` indica baja lógica (R7).

---

### cliente

| Columna | Tipo | Restricciones |
|---|---|---|
| `id_cliente` | `BIGINT GENERATED ALWAYS AS IDENTITY` | PRIMARY KEY |
| `nombre` | `VARCHAR(100)` | NOT NULL |
| `apellido` | `VARCHAR(100)` | NOT NULL |
| `telefono` | `VARCHAR(30)` | — |
| `email` | `VARCHAR(255)` | NOT NULL, UNIQUE |

- `email` es clave candidata que identifica de forma única al cliente (R6).

---

### producto

| Columna | Tipo | Restricciones |
|---|---|---|
| `id_producto` | `BIGINT GENERATED ALWAYS AS IDENTITY` | PRIMARY KEY |
| `nombre` | `VARCHAR(120)` | NOT NULL |
| `descripcion` | `TEXT` | — |
| `precio` | `NUMERIC(10,2)` | NOT NULL, CHECK >= 0 (R5) |
| `stock` | `INT` | NOT NULL, DEFAULT 0, CHECK >= 0 (R5) |
| `activo` | `BOOLEAN` | NOT NULL, DEFAULT TRUE |
| `id_categoria` | `BIGINT` | NOT NULL, FK → categoria |

- FK `fk_producto_categoria`: `ON DELETE RESTRICT` — no se puede eliminar una categoría con productos.
- `activo = FALSE` indica baja lógica (R7).

---

### pedido

| Columna | Tipo | Restricciones |
|---|---|---|
| `id_pedido` | `BIGINT GENERATED ALWAYS AS IDENTITY` | PRIMARY KEY |
| `fecha` | `TIMESTAMPTZ` | NOT NULL, DEFAULT now() |
| `forma_pago` | `forma_pago_enum` | NOT NULL |
| `id_cliente` | `BIGINT` | NOT NULL, FK → cliente |

- FK `fk_pedido_cliente`: `ON DELETE RESTRICT` — no se puede eliminar un cliente con historial de pedidos.

---

### pedido_producto *(tabla intermedia N:M)*

| Columna | Tipo | Restricciones |
|---|---|---|
| `id_pedido` | `BIGINT` | NOT NULL, FK → pedido |
| `id_producto` | `BIGINT` | NOT NULL, FK → producto |
| `cantidad` | `INT` | NOT NULL, CHECK > 0 |
| `precio_unitario` | `NUMERIC(10,2)` | NOT NULL, CHECK >= 0 |

- Clave primaria compuesta: `(id_pedido, id_producto)`.
- `precio_unitario` congela el precio al momento del pedido — **nunca** se actualiza retroactivamente (R4).
- Ambas FK usan `ON DELETE RESTRICT`.

---

## Índices

| Índice | Tabla | Columnas | Justificación |
|---|---|---|---|
| `idx_pedido_cliente` | `pedido` | `id_cliente` | Acelera el historial de compras por cliente |
| `idx_producto_categoria_activo` | `producto` | `id_categoria, activo` | Acelera el listado de productos activos por categoría en el catálogo |

---

## Reglas de negocio resumidas

| ID | Regla |
|---|---|
| R4 | Precio histórico congelado en `pedido_producto.precio_unitario` |
| R5 | `precio >= 0` y `stock >= 0` validados con CHECK |
| R6 | `cliente.email` es único |
| R7 | Bajas lógicas con `activo = FALSE` en `categoria` y `producto` |
