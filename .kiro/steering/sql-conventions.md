# Convenciones SQL — Food Store

## Idioma

- Los **identificadores** (tablas, columnas, constraints, índices) van en **español**.
- Los **comentarios** van en español.
- Las **palabras clave SQL** (`SELECT`, `CREATE TABLE`, `NOT NULL`, etc.) van en **mayúsculas**.

## Nomenclatura

### Tablas
- Nombre en singular, snake_case minúsculas: `categoria`, `producto`, `pedido_producto`.
- La tabla intermedia N:M lleva el nombre de ambas entidades separadas por `_`: `pedido_producto`.

### Columnas
- snake_case minúsculas.
- Las claves primarias siguen el patrón `id_<tabla>`: `id_categoria`, `id_producto`, `id_cliente`, `id_pedido`.
- Las claves foráneas usan el mismo nombre que la PK referenciada: `id_categoria`, `id_cliente`, `id_producto`, `id_pedido`.
- Los flags booleanos de baja lógica se llaman `activo`.

### Constraints
| Tipo | Patrón | Ejemplo |
|---|---|---|
| CHECK | `chk_<tabla>_<columna>` | `chk_producto_precio` |
| FOREIGN KEY | `fk_<tabla>_<referencia>` | `fk_producto_categoria` |
| PRIMARY KEY | Declarada inline con `PRIMARY KEY` o `CONSTRAINT pk_<tabla>` para claves compuestas | |
| UNIQUE | Declarada inline con `UNIQUE` o `CONSTRAINT uq_<tabla>_<columna>` | |

### Índices
- Patrón: `idx_<tabla>_<columnas>`: `idx_pedido_cliente`, `idx_producto_categoria_activo`.

### Tipos ENUM
- Nombre en snake_case con sufijo `_enum`: `forma_pago_enum`.
- Valores del enum en **MAYÚSCULAS**: `'EFECTIVO'`, `'TARJETA'`, `'TRANSFERENCIA'`.

## Tipos de datos preferidos

| Dato | Tipo PostgreSQL |
|---|---|
| Claves primarias autogeneradas | `BIGINT GENERATED ALWAYS AS IDENTITY` |
| Texto corto (nombres, emails) | `VARCHAR(n)` con longitud razonable |
| Texto libre | `TEXT` |
| Moneda / precios | `NUMERIC(10, 2)` — nunca `FLOAT` ni `REAL` |
| Cantidades enteras | `INT` |
| Flags booleanos | `BOOLEAN NOT NULL DEFAULT TRUE/FALSE` |
| Fechas con zona horaria | `TIMESTAMPTZ` con `DEFAULT now()` |

## Estructura de un archivo SQL

1. Bloque de encabezado con comentario `--` que indica propósito, motor y autores.
2. Sección de limpieza (`DROP ... IF EXISTS ... CASCADE`) antes de crear objetos.
3. Creación de tipos (`CREATE TYPE`).
4. Creación de tablas en orden de dependencia (sin FK hacia tablas no creadas aún).
5. Creación de índices al final.
6. Comentarios de justificación para cada índice creado.

## Integridad referencial

- Usar `ON DELETE RESTRICT` como política por defecto en todas las FK para proteger el historial.
- No usar `ON DELETE CASCADE` salvo que se justifique explícitamente.
- No usar `ON DELETE SET NULL` salvo que la columna lo permita y se justifique.

## Bajas lógicas

- Nunca hacer `DELETE` en `categoria` ni en `producto` en producción.
- Usar `UPDATE ... SET activo = FALSE` para dar de baja un registro.
- Las consultas de catálogo deben filtrar siempre por `activo = TRUE`.

## Seed / datos de prueba

- Todo `INSERT` en `seed.sql` debe funcionar sin conocer IDs generados, usando subconsultas `(SELECT id_x FROM tabla WHERE nombre = '...')`.
- Los datos de prueba son mínimos y representativos del dominio (pizzas, bebidas, clientes ficticios).
