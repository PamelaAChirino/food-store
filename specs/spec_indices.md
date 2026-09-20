# Especificación de Índices — Parte A

## 1. Búsqueda de Pedidos por Fecha
- **Descripción:** Optimizar las consultas frecuentes que filtran los pedidos por un rango de fechas.
- **Frecuencia:** Alta.
- **Columnas que participan:** La columna `fecha` de la tabla `pedido`.

## 2. Búsqueda de Clientes por Correo
- **Descripción:** Optimizar la búsqueda y validación de clientes por su dirección de email.
- **Frecuencia:** Media-Alta.
- **Columnas que participan:** La columna `email` de la tabla `cliente`.

## 3. Filtrado y Ordenamiento de Productos
- **Descripción:** Optimizar el catálogo para filtrar productos por categoría y ordenarlos por precio.
- **Frecuencia:** Alta.
- **Columnas que participan:** Las columnas `id_categoria` y `precio` de la tabla `producto`.