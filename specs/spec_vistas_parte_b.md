# spec: vistas_reportes_y_seguridad
Objetivo: Implementar las tres vistas requeridas para los reportes analíticos y operativos de Food Store.
- v_productos_vigentes: expone productos activos con su categoría (filtro activo = TRUE).
- v_pedidos_usuarios: expone pedidos y datos de contacto del cliente, aplicando el criterio de seguridad de omitir la columna contraseña de la tabla base.
- v_detalle_pedido_producto: expone el detalle de los ítems del pedido junto al nombre del producto.
Criterio de aceptación: Coincidencia exacta de filas y columnas al contrastar las vistas con las consultas manuales equivalentes.