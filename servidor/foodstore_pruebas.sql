-- =====================================================================
-- Food Store · Base de Datos II · TP8
-- servidor/foodstore_pruebas.sql
-- COPIA DE PRUEBAS del servidor PostgreSQL con DATOS INVENTADOS.
-- (Regla 1: nunca se trabaja sobre la base real.)
-- Si su esquema real tiene otros nombres, solo hay que adaptar la vista
-- v_snapshot_movil del final: la tablet depende de la vista, no de las tablas.
-- Uso: psql -d foodstore_pruebas -f servidor/foodstore_pruebas.sql
-- =====================================================================

DROP VIEW  IF EXISTS v_snapshot_movil;
DROP TABLE IF EXISTS detalle_pedido, pedido, producto, categoria, usuario CASCADE;

CREATE TABLE usuario (
    id            SERIAL PRIMARY KEY,
    nombre        VARCHAR(80)  NOT NULL,
    email         VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(100) NOT NULL,          -- dato que NUNCA viaja a la tablet
    rol           VARCHAR(10)  NOT NULL DEFAULT 'CLIENTE'
                  CHECK (rol IN ('ADMIN', 'CLIENTE'))
);

CREATE TABLE categoria (
    id     SERIAL PRIMARY KEY,
    nombre VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE producto (
    id           SERIAL PRIMARY KEY,
    nombre       VARCHAR(80)   NOT NULL,
    descripcion  TEXT,
    precio       NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
    stock        INTEGER       NOT NULL CHECK (stock >= 0),
    disponible   BOOLEAN       NOT NULL DEFAULT TRUE,
    eliminado    BOOLEAN       NOT NULL DEFAULT FALSE,   -- baja lógica
    categoria_id INTEGER       NOT NULL REFERENCES categoria(id),
    imagen_url   TEXT,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE pedido (
    id         SERIAL PRIMARY KEY,
    usuario_id INTEGER       NOT NULL REFERENCES usuario(id),
    fecha      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    estado     VARCHAR(12)   NOT NULL DEFAULT 'PENDIENTE'
               CHECK (estado IN ('PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO')),
    forma_pago VARCHAR(15)   NOT NULL
               CHECK (forma_pago IN ('EFECTIVO','TARJETA','TRANSFERENCIA')),
    total      NUMERIC(12,2) NOT NULL CHECK (total >= 0)
);

CREATE TABLE detalle_pedido (
    pedido_id   INTEGER       NOT NULL REFERENCES pedido(id),
    producto_id INTEGER       NOT NULL REFERENCES producto(id),
    cantidad    INTEGER       NOT NULL CHECK (cantidad > 0),
    subtotal    NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0),
    PRIMARY KEY (pedido_id, producto_id)
);

-- ------------------------- Datos inventados -------------------------
INSERT INTO usuario (nombre, email, password_hash, rol) VALUES
 ('Admin Feria',  'admin@foodstore.test',    'hash-falso-1', 'ADMIN'),
 ('Cliente Uno',  'cliente1@foodstore.test', 'hash-falso-2', 'CLIENTE'),
 ('Cliente Dos',  'cliente2@foodstore.test', 'hash-falso-3', 'CLIENTE');

INSERT INTO categoria (nombre) VALUES ('Sándwiches'), ('Pizzas'), ('Empanadas'), ('Bebidas'), ('Acompañamientos');

INSERT INTO producto (nombre, descripcion, precio, stock, disponible, categoria_id) VALUES
 ('Hamburguesa clásica', 'Carne, queso y tomate',   5500.00, 30, TRUE,  1),  -- id 1 (C2)
 ('Lomito completo',     'Con jamón, queso y huevo',7800.00, 15, TRUE,  1),  -- id 2
 ('Pizza muzzarella',    'Grande, 8 porciones',     6900.00, 10, TRUE,  2),  -- id 3
 ('Empanada de carne',   'Al horno',                1200.00, 40, TRUE,  3),  -- id 4 (C3)
 ('Choripán',            'Con chimichurri',         3500.00, 25, TRUE,  1),  -- id 5 (C4)
 ('Papas fritas',        'Porción grande',          2800.00, 20, TRUE,  5),  -- id 6 (C5)
 ('Agua sin gas 500 ml', NULL,                      1000.00, 50, TRUE,  4),  -- id 7 (C5)
 ('Gaseosa 500 ml',      NULL,                      1500.00,  0, FALSE, 4);  -- id 8 (no disponible)

INSERT INTO pedido (usuario_id, estado, forma_pago, total) VALUES
 (2, 'TERMINADO', 'EFECTIVO', 12800.00),
 (3, 'PENDIENTE', 'TARJETA',   6900.00);

INSERT INTO detalle_pedido VALUES
 (1, 1, 1, 5500.00), (1, 6, 1, 2800.00), (1, 5, 1, 3500.00), (1, 7, 1, 1000.00),
 (2, 3, 1, 6900.00);

-- --------------------- Vista para la tablet (parada 5) ---------------------
-- Solo datos de producto. Incluye los productos dados de baja como LÁPIDAS
-- (eliminado = true) para que la tablet se entere de la baja.
-- Precio en centavos (entero) para no arrastrar decimales a SQLite.
CREATE VIEW v_snapshot_movil AS
SELECT p.id,
       p.nombre,
       (p.precio * 100)::INTEGER                     AS precio_centavos,
       p.stock,
       p.disponible,
       p.eliminado,
       to_char(now() AT TIME ZONE 'America/Argentina/Mendoza',
               'YYYY-MM-DD HH24:MI:SS')              AS fecha_snapshot
FROM producto p
ORDER BY p.id;
