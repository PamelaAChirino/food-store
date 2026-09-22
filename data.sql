-- Datos de carga inicial para desarrollo y pruebas

INSERT INTO categoria (nombre, descripcion) VALUES
    ('Pizzas', 'Pizzas a la piedra'),
    ('Bebidas', 'Bebidas frías');

INSERT INTO producto (nombre, descripcion, precio, stock, id_categoria) VALUES
    ('Muzzarella', 'Pizza clásica de muzzarella', 1000.00, 10, (SELECT id_categoria FROM categoria WHERE nombre = 'Pizzas')),
    ('Napolitana', 'Pizza con tomate y ajo', 1500.00, 5, (SELECT id_categoria FROM categoria WHERE nombre = 'Pizzas')),
    ('Coca 1.5L', 'Gaseosa cola 1.5 litros', 800.00, 20, (SELECT id_categoria FROM categoria WHERE nombre = 'Bebidas'));

INSERT INTO cliente (nombre, apellido, telefono, email) VALUES
    ('Ana', 'Gómez', '2610000000', 'ana.gomez@test.com'),
    ('Luis', 'Paz', '2610000001', 'luis.paz@test.com');