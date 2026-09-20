-- ==========================================
-- ENTREGABLE: indices.sql
-- Parte A — Base de Datos II
-- ==========================================

-- 1. Índice para optimizar la búsqueda y rangos de fechas en pedidos
CREATE INDEX idx_pedido_fecha ON pedido (fecha);

-- 2. Índice para acelerar la búsqueda de clientes por correo electrónico
CREATE INDEX idx_cliente_email ON cliente (email);

-- 3. Índice compuesto para filtrar productos por categoría y ordenarlos por precio eficientemente
CREATE INDEX idx_producto_categoria_precio ON producto (id_categoria, precio);