# spec: mv_facturacion_categoria_mes
Objetivo: Optimizar un reporte agregado costoso de facturación mensual por categoría mediante una vista materializada.
Consulta afectada: Agregación con múltiples JOINs entre categoria, producto, pedido_producto y pedido, usando SUM y COUNT.
Requisitos técnicos: Uso de WITH DATA y creación de un índice único sobre (id_categoria, mes_anio) para permitir REFRESH CONCURRENTLY a futuro sin bloquear lecturas.
Criterio de aceptación: Reducción drástica del tiempo de respuesta del reporte (bajada de ms a sub-milisegundos frente a la consulta en crudo).