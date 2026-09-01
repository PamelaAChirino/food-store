# Food Store — Descripción del Proyecto

## Contexto académico

Trabajo Práctico N.º 1 de la materia **Base de Datos II**.
Integrantes: Chirino Pamela, Agüero Lucas y Mule Mayra.

## Descripción

Food Store es un sistema de gestión de pedidos para una tienda de comidas (estilo pizzería/delivery). El proyecto consiste exclusivamente en la capa de base de datos: diseño relacional, esquema SQL y datos de prueba. No existe capa de aplicación en este repositorio.

## Motor de base de datos

**PostgreSQL** (última versión estable). Toda la sintaxis, tipos de datos y funciones deben ser compatibles con PostgreSQL. No usar sintaxis específica de MySQL, SQLite ni SQL Server.

## Archivos principales

| Archivo | Propósito |
|---|---|
| `schema.sql` | Definición completa del esquema: tipos, tablas, constraints, índices |
| `seed.sql` | Datos iniciales de categorías, productos y clientes para desarrollo y pruebas |

## Orden de ejecución

Siempre ejecutar en este orden:
1. `schema.sql`
2. `seed.sql`

## Entidades del dominio

- **Categoria**: agrupa productos (ej: Pizzas, Bebidas). Soporta baja lógica.
- **Producto**: ítem del catálogo con precio, stock y categoría. Soporta baja lógica.
- **Cliente**: persona que realiza pedidos. Identificado de forma única por email.
- **Pedido**: compra realizada por un cliente con forma de pago.
- **Pedido_Producto**: tabla intermedia N:M que registra el detalle de cada pedido con precio histórico congelado.

## Reglas de negocio clave

- **R4**: El `precio_unitario` en `pedido_producto` se congela al momento del pedido (precio histórico).
- **R5**: `precio >= 0` y `stock >= 0` se validan con constraints CHECK.
- **R6**: El email del cliente es único (clave candidata).
- **R7**: Las bajas son lógicas (`activo = FALSE`) en `categoria` y `producto` para preservar el historial de ventas.

## Formas de pago

Definidas como un tipo ENUM: `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`.
