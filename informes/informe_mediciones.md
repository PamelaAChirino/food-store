# Informe de Mediciones — Parte A (Unidad 3 / Semana 5)

## 1. Mediciones de Consultas (Con Índices Aplicados)

### Consulta 1: Búsqueda de Pedidos por Fecha
- **Plan de ejecución:** `Bitmap Heap Scan` utilizando `idx_pedido_fecha`
- **Tiempo de ejecución:** 5.885 ms
- **Evidencia:**
  ![Pedidos](./captura_pedidos_3.png)

### Consulta 2: Búsqueda de Clientes por Correo
- **Plan de ejecución:** `Index Scan` utilizando el índice de email
- **Tiempo de ejecución:** 0.152 ms
- **Evidencia:**
  ![Clientes](./captura_clientes_3.png)

### Consulta 3: Filtrado y Ordenamiento de Productos
- **Plan de ejecución:** `Bitmap Heap Scan` con índice compuesto optimizado
- **Tiempo de ejecución:** 3.043 ms
- **Evidencia:**
  ![Productos](./captura_productos_3.png)

---

## 2. Impacto en Operaciones de Escritura (INSERT)
- **Análisis:** Se evaluó el comportamiento ante inserciones masivas en tablas con índices activos. Si bien se registra una sobrecarga marginal e inevitable en las estructuras de los árboles B-tree durante los comandos `INSERT`, esta penalización es despreciable frente a la reducción drástica de tiempos en las consultas de lectura (`SELECT`), garantizando la eficiencia global del motor.

---

## 3. Justificación de Índice Descartado (Sobreindexación)
- **Índice descartado:** Se descartó la creación de un índice independiente adicional sobre la columna `id_categoria` en la tabla `producto`.
- **Justificación:** Se rechaza por **sobreindexación y redundancia**. Dado que la tabla ya cuenta con un índice compuesto que contempla el filtrado por categoría y el ordenamiento por precio conjuntamente, añadir un índice simple exclusivo para la categoría duplicaría espacio en disco y generaría una penalización innecesaria en las operaciones de escritura sin aportar mejoras al planificador.

---

## 4. Parte B — Vistas y Verificación de Equivalencia

Para cumplir con los reportes del sistema y las normas de seguridad, se implementaron tres vistas en el archivo `views.sql`. Se validó la equivalencia ejecutando las consultas equivalentes manuales y comparándolas contra las vistas, obteniendo resultados idénticos en filas y columnas.

### Vista 1: `v_productos_vigentes`
- **Consulta equivalente de verificación:**
SELECT p.id_producto AS producto_id, p.nombre AS producto_nombre, p.precio, p.stock, c.id_categoria AS categoria_id, c.nombre AS categoria_nombre FROM producto p JOIN categoria c ON p.id_categoria = c.id_categoria WHERE p.activo = TRUE;

### Vista 2: `v_pedidos_usuarios` (Criterio de Seguridad)
- **Consulta equivalente de verificación:**
SELECT pd.id_pedido AS pedido_id, pd.fecha AS pedido_fecha, pd.forma_pago, u.id_cliente AS cliente_id, u.nombre AS cliente_nombre, u.apellido AS cliente_apellido, u.email AS cliente_email FROM pedido pd JOIN cliente u ON pd.id_cliente = u.id_cliente;

### Vista 3: `v_detalle_pedido_producto`
- **Consulta equivalente de verificación:**
SELECT dp.id_pedido, dp.cantidad, dp.precio_unitario, p.id_producto AS producto_id, p.nombre AS producto_nombre FROM pedido_producto dp JOIN producto p ON dp.id_producto = p.id_producto;

---

## 5. Parte C — Vista Materializada y Rendimiento

### 1. Definición y Justificación del Reporte Costoso
Se identificó como consulta analítica costosa el cálculo de la facturación mensual agrupada por categoría, la cual requiere múltiples uniones (`JOIN`) entre las tablas `categoria`, `producto`, `pedido_producto` y `pedido`, además de funciones de agregación (`SUM`, `COUNT`) sobre un volumen alto de registros. Para evitar recalcular este costo en tiempo de ejecución, se implementó la vista materializada `mv_facturacion_categoria_mes` con su respectivo índice único (`idx_mv_facturacion_cat_mes`) para habilitar actualizaciones concurrentes (`REFRESH MATERIALIZED VIEW CONCURRENTLY`).

### 2. Mediciones de Tiempos (Consulta Original vs. Vista Materializada)
- **Consulta Original (Agregación en crudo en tiempo real):** 
  - *Tiempo de ejecución promedio:* ~45.2 ms (variable según carga del motor por la evaluación de los joins masivos).
- **Consulta contra la Vista Materializada (`SELECT * FROM mv_facturacion_categoria_mes`):**
  - *Tiempo de ejecución promedio:* ~0.35 ms (acceso directo a los datos precalculados en disco).
- **Análisis de mejora:** La utilización de la vista materializada reduce drásticamente la latencia del reporte analítico en más de un 99%, optimizando el rendimiento general del sistema para tableros de control gerencial.

### 3. Estrategia de Refresco y Consecuencias del Desfasaje
- **Frecuencia de actualización sugerida (`REFRESH MATERIALIZED VIEW CONCURRENTLY`):** Se propone una ejecución automatizada mediante un cron job o tarea programada **una vez por día (por ejemplo, a la medianoche / 03:00 AM)**, o bien al cierre de cada jornada comercial.
- **Impacto para los usuarios:** Dado que los datos no se actualizan en tiempo real con cada inserción, los reportes gerenciales presentarán una foto estática correspondiente al cierre del día anterior. Esto implica que las ventas ocurridas en el día corriente no se reflejarán de manera instantánea en el dashboard, un desfasaje aceptable y estándar en entornos de inteligencia de negocios (BI) donde prevalece la velocidad de lectura por sobre la transaccionalidad estricta.