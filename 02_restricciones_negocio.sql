-- =============================================================================
-- TP2 SEMANA 2 - FOOD STORE
-- Restricciones de integridad para reglas de negocio no garantizadas por el motor
-- Motor: PostgreSQL
-- =============================================================================

-- -----------------------------------------------------------------------------
-- REGLA A: un pedido no puede registrarse con fecha futura
-- (evita errores de carga: alguien tipea mal el año o el sistema tiene mal
-- configurada la zona horaria del cliente)
-- -----------------------------------------------------------------------------
ALTER TABLE pedido
    ADD CONSTRAINT chk_pedido_fecha_no_futura CHECK (fecha <= now());

-- -----------------------------------------------------------------------------
-- REGLA B + C: al vender un producto (insertar una línea en pedido_producto)
--   B. el producto no puede estar dado de baja (activo = FALSE)
--   C. no se puede vender más unidades de las que hay en stock
-- Se resuelven en UN solo trigger (no dos) para que el chequeo de stock y el
-- descuento de stock sean atómicos dentro de la misma fila: si se separaran en
-- dos triggers BEFORE INSERT sobre la misma tabla, el orden de ejecución entre
-- ellos no está garantizado por nombre y se complica razonar sobre el resultado.
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_venta_producto()
RETURNS TRIGGER AS $$
DECLARE
    v_activo BOOLEAN;
    v_stock  INT;
BEGIN
    -- FOR UPDATE: bloquea la fila del producto hasta el commit de esta
    -- transacción, para que dos ventas concurrentes del mismo producto no
    -- lean el mismo stock "viejo" y lo descuenten dos veces (race condition).
    SELECT activo, stock INTO v_activo, v_stock
    FROM producto
    WHERE id_producto = NEW.id_producto
    FOR UPDATE;

    IF NOT v_activo THEN
        RAISE EXCEPTION 'No se puede vender el producto id=% porque está dado de baja (inactivo)', NEW.id_producto;
    END IF;

    IF v_stock < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para producto id=%: disponible %, solicitado %', NEW.id_producto, v_stock, NEW.cantidad;
    END IF;

    UPDATE producto SET stock = stock - NEW.cantidad WHERE id_producto = NEW.id_producto;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_venta_producto
    BEFORE INSERT ON pedido_producto
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_venta_producto();


-- =============================================================================
-- PRUEBAS (correr dentro de BEGIN; ... ROLLBACK; sobre copia_trabajo, según el
-- protocolo de seguridad, antes de aplicar en serio)
-- =============================================================================

-- Nota: dentro de una transacción, en cuanto una sentencia falla, Postgres
-- aborta el resto hasta el ROLLBACK. Para poder probar varios casos inválidos
-- seguidos sin perder los datos base ya cargados, cada caso "debe fallar" se
-- envuelve en su propio SAVEPOINT y se vuelve a él después del error esperado.

-- Los IDs se buscan por nombre/email con subconsultas en vez de hardcodearse,
-- porque las secuencias de las PK (GENERATED ALWAYS AS IDENTITY) no se
-- resetean con ROLLBACK: si se hardcodea "id_producto = 1" el test se rompe
-- apenas se corre una segunda vez sobre la misma base.

BEGIN;

-- Datos base de prueba
INSERT INTO categoria (nombre) VALUES ('Pizzas');
INSERT INTO producto (nombre, precio, stock, id_categoria, activo)
    VALUES ('Muzzarella', 1000, 10, (SELECT id_categoria FROM categoria WHERE nombre = 'Pizzas'), TRUE);
INSERT INTO producto (nombre, precio, stock, id_categoria, activo)
    VALUES ('Napolitana', 1500, 5, (SELECT id_categoria FROM categoria WHERE nombre = 'Pizzas'), FALSE);  -- producto dado de baja
INSERT INTO cliente (nombre, apellido, email) VALUES ('Ana', 'Gómez', 'ana@test.com');

-- Caso VÁLIDO: pedido con fecha actual (default)
INSERT INTO pedido (forma_pago, id_cliente)
    VALUES ('EFECTIVO', (SELECT id_cliente FROM cliente WHERE email = 'ana@test.com'));
-- Esperado: OK

-- Caso INVÁLIDO: fecha futura → debe violar chk_pedido_fecha_no_futura
SAVEPOINT antes_de_fecha_futura;
INSERT INTO pedido (fecha, forma_pago, id_cliente)
    VALUES ('2099-01-01', 'EFECTIVO', (SELECT id_cliente FROM cliente WHERE email = 'ana@test.com'));
-- Esperado: ERROR: new row for relation "pedido" violates check constraint "chk_pedido_fecha_no_futura"
ROLLBACK TO SAVEPOINT antes_de_fecha_futura;

-- Caso VÁLIDO: vender un producto activo, dentro del stock
INSERT INTO pedido_producto (id_pedido, id_producto, cantidad, precio_unitario)
    VALUES (
        (SELECT id_pedido FROM pedido ORDER BY id_pedido DESC LIMIT 1),
        (SELECT id_producto FROM producto WHERE nombre = 'Muzzarella'),
        2, 1000
    );
-- Esperado: OK, y producto.stock de Muzzarella pasa de 10 a 8
SELECT stock FROM producto WHERE nombre = 'Muzzarella';  -- debería devolver 8

-- Caso INVÁLIDO: vender un producto inactivo → debe violar la regla B
SAVEPOINT antes_de_producto_inactivo;
INSERT INTO pedido_producto (id_pedido, id_producto, cantidad, precio_unitario)
    VALUES (
        (SELECT id_pedido FROM pedido ORDER BY id_pedido DESC LIMIT 1),
        (SELECT id_producto FROM producto WHERE nombre = 'Napolitana'),
        1, 1500
    );
-- Esperado: ERROR: No se puede vender el producto id=... porque está dado de baja (inactivo)
ROLLBACK TO SAVEPOINT antes_de_producto_inactivo;

-- Caso INVÁLIDO: vender más unidades de las que hay en stock → debe violar la regla C
SAVEPOINT antes_de_stock_insuficiente;
INSERT INTO pedido_producto (id_pedido, id_producto, cantidad, precio_unitario)
    VALUES (
        (SELECT id_pedido FROM pedido ORDER BY id_pedido DESC LIMIT 1),
        (SELECT id_producto FROM producto WHERE nombre = 'Muzzarella'),
        999, 1000
    );
-- Esperado: ERROR: Stock insuficiente para producto id=...: disponible 8, solicitado 999
ROLLBACK TO SAVEPOINT antes_de_stock_insuficiente;

ROLLBACK;  -- se descarta todo: esto fue solo para verificar, no queda commiteado
