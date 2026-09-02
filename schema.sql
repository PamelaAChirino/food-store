-- =============================================================================
-- TRABAJO PRÁCTICO N.º 1 - FOOD STORE
-- Script de Creación del Esquema Relacional (schema.sql)
-- Motor: PostgreSQL
-- Integrantes: Chirino Pamela, Agüero Lucas y Mule Mayra
-- =============================================================================

-- Limpieza de tablas y tipos previas para garantizar ejecución limpia de principio a fin
DROP TABLE IF EXISTS pedido_producto CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;
DROP TABLE IF EXISTS categoria CASCADE;
DROP TYPE IF EXISTS forma_pago_enum CASCADE;

-- 1. Tipo Enum (Dominio cerrado para Formas de Pago)
CREATE TYPE forma_pago_enum AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);

-- 2. Tabla Categoria
CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE, -- Restricción UNIQUE para clave candidata
    descripcion TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE -- R7: Marca de baja lógica (por defecto activa)
);

-- 3. Tabla Cliente
CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    telefono VARCHAR(30),
    email VARCHAR(255) NOT NULL UNIQUE -- R6: Correo único identificador del cliente
);

-- 4. Tabla Producto
CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    descripcion TEXT,
    precio NUMERIC(10, 2) NOT NULL, -- NUMERIC para precisión fija monetaria
    stock INT NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE, -- R7: Baja lógica para conservar historial
    id_categoria BIGINT NOT NULL,
    
    -- Restricciones CHECK para validar reglas de negocio (R5)
    CONSTRAINT chk_producto_precio CHECK (precio >= 0),
    CONSTRAINT chk_producto_stock CHECK (stock >= 0),
    
    -- FK hacia Categoria: Se usa RESTRICT para evitar que se elimine una categoría que tenga productos asociados
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria (id_categoria)
        ON DELETE RESTRICT
);

-- 5. Tabla Pedido
CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(), -- Timestamp con zona horaria y valor por defecto
    forma_pago forma_pago_enum NOT NULL,
    id_cliente BIGINT NOT NULL,
    
    -- FK hacia Cliente: RESTRICT evita borrar un cliente si este ya posee un historial de pedidos
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id_cliente)
        ON DELETE RESTRICT,
        
    -- R5: La fecha del pedido no puede ser futura
    CONSTRAINT chk_pedido_fecha_no_futura CHECK (fecha <= now())
);

-- 6. Tabla Intermedia Pedido_Producto (Relación N:M)
CREATE TABLE pedido_producto (
    id_pedido BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario NUMERIC(10, 2) NOT NULL, -- R4: Garantiza el precio histórico congelado al momento del pedido
    
    PRIMARY KEY (id_pedido, id_producto), -- Clave primaria compuesta
    
    -- Restricciones CHECK declarativas
    CONSTRAINT chk_detalle_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio_unitario CHECK (precio_unitario >= 0),
    
    -- FKs con RESTRICT para resguardar la integridad referencial del historial de ventas
    CONSTRAINT fk_detalle_pedido FOREIGN KEY (id_pedido)
        REFERENCES pedido (id_pedido)
        ON DELETE RESTRICT,
        
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto)
        REFERENCES producto (id_producto)
        ON DELETE RESTRICT
);

-- 7. Índices Justificados
-- Justificación: Acelera la consulta de historial de compras y filtrado de pedidos por cada cliente.
CREATE INDEX idx_pedido_cliente ON pedido(id_cliente);

-- Justificación: Acelera el listado de productos activos pertenecientes a una categoría específica para el catálogo web.
CREATE INDEX idx_producto_categoria_activo ON producto(id_categoria, activo);

-- =============================================================================
-- 8. Trigger: Validación de ventas en Pedido_Producto (R7 y Control de Stock)
-- =============================================================================
-- Función de disparo: se ejecuta en cada INSERT sobre pedido_producto.
--   - Rechaza la venta de productos dados de baja lógica (activo = FALSE).
--   - Rechaza la venta si la cantidad supera el stock disponible.
--   - Descuenta el stock vendido de forma atómica.
-- FOR UPDATE: bloquea la fila del producto mientras la transacción de la venta
-- está activa, serializando las ventas concurrentes del mismo producto y
-- evitando condiciones de carrera (clásico problema de la "doble venta").
CREATE OR REPLACE FUNCTION fn_validar_venta_pedido_producto() RETURNS TRIGGER AS $$
DECLARE
    v_nombre_producto VARCHAR(120);
    v_activo BOOLEAN;
    v_stock INT;
BEGIN
    -- Lee el producto bloqueando su fila hasta el fin de la transacción
    SELECT nombre, activo, stock
      INTO v_nombre_producto, v_activo, v_stock
      FROM producto
     WHERE id_producto = NEW.id_producto
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El producto con id % no existe.', NEW.id_producto;
    END IF;

    -- R7: Impide vender un producto dado de baja lógica
    IF NOT v_activo THEN
        RAISE EXCEPTION 'El producto "%" (id %) está dado de baja y no puede venderse.',
            v_nombre_producto, NEW.id_producto;
    END IF;

    -- Impide vender más cantidad que el stock disponible
    IF NEW.cantidad > v_stock THEN
        RAISE EXCEPTION 'Stock insuficiente del producto "%" (id %): disponible % y se solicitan %.',
            v_nombre_producto, NEW.id_producto, v_stock, NEW.cantidad;
    END IF;

    -- Descuenta el stock vendido
    UPDATE producto
       SET stock = stock - NEW.cantidad
     WHERE id_producto = NEW.id_producto;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pedido_producto_venta
    BEFORE INSERT ON pedido_producto
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_venta_pedido_producto();