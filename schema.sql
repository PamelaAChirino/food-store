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
        ON DELETE RESTRICT
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