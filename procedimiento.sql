-- =============================================================================
-- TPI FOOD STORE - Procedimiento almacenado (PL/pgSQL, invocado con CALL)
-- Objetivo del punto 6 del checklist de entrega: "procedimientos almacenados
-- desarrollados en PL/pgSQL", distinto de una funcion o un trigger.
-- =============================================================================
--
-- sp_registrar_pedido: registra un pedido completo (cabecera + N lineas de
-- detalle) como una unica operacion atomica. Recibe el cliente, la forma de
-- pago y un array de productos/cantidades, y devuelve el id del pedido
-- creado a traves de un parametro INOUT.
--
-- Por que PROCEDURE y no FUNCTION: un procedimiento puede manejar su propio
-- control transaccional (COMMIT/ROLLBACK internos) y se invoca con CALL, no
-- dentro de un SELECT -- es la forma que pide la consigna para diferenciarlo
-- de fn_validar_venta_pedido_producto() (esa es una FUNCTION disparada por
-- el trigger, no un procedimiento). Acá no hacemos COMMIT/ROLLBACK interno
-- a propósito: si sp_registrar_pedido se llama desde una transacción más
-- grande, tiene que poder abortarse junto con ella.

CREATE OR REPLACE PROCEDURE sp_registrar_pedido(
    p_id_cliente     BIGINT,
    p_forma_pago     forma_pago_enum,
    p_ids_producto   BIGINT[],
    p_cantidades     INT[],
    INOUT p_id_pedido BIGINT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    i INT;
BEGIN
    IF array_length(p_ids_producto, 1) IS NULL THEN
        RAISE EXCEPTION 'El pedido debe tener al menos un producto.';
    END IF;
    IF array_length(p_ids_producto, 1) <> array_length(p_cantidades, 1) THEN
        RAISE EXCEPTION 'La cantidad de productos y de cantidades no coincide.';
    END IF;

    -- Cabecera del pedido
    INSERT INTO pedido (forma_pago, id_cliente)
    VALUES (p_forma_pago, p_id_cliente)
    RETURNING id_pedido INTO p_id_pedido;

    -- Detalle: una linea por producto. El trigger trg_pedido_producto_venta
    -- ya valida producto activo + stock suficiente y descuenta el stock en
    -- cada INSERT -- el procedimiento no duplica esa lógica, la reutiliza.
    -- OJO: un INSERT...SELECT...WHERE id_producto=X, si X no existe, NO
    -- tira error -- simplemente inserta 0 filas (se detectó probando el
    -- procedimiento: un id de producto inexistente generaba un pedido con
    -- menos líneas de las pedidas, sin ningún aviso). Por eso se valida la
    -- existencia explícitamente ANTES de insertar.
    FOR i IN 1 .. array_length(p_ids_producto, 1) LOOP
        IF NOT EXISTS (SELECT 1 FROM producto WHERE id_producto = p_ids_producto[i]) THEN
            RAISE EXCEPTION 'El producto con id % no existe (línea % del pedido).', p_ids_producto[i], i;
        END IF;

        INSERT INTO pedido_producto (id_pedido, id_producto, cantidad, precio_unitario)
        SELECT p_id_pedido, p_ids_producto[i], p_cantidades[i], precio
        FROM producto
        WHERE id_producto = p_ids_producto[i];
    END LOOP;
END;
$$;

-- =============================================================================
-- Prueba (correr sobre copia de trabajo, protocolo de seguridad de la cátedra)
-- =============================================================================
-- Caso válido: CALL sp_registrar_pedido(1, 'EFECTIVO', ARRAY[1,2,3]::BIGINT[], ARRAY[1,1,1], NULL);
--   -> crea el pedido y sus 3 líneas.
-- Caso inválido: CALL sp_registrar_pedido(1, 'EFECTIVO', ARRAY[1,999999]::BIGINT[], ARRAY[1,1], NULL);
--   -> ERROR: El producto con id 999999 no existe (línea 2 del pedido).
--      No queda ni el pedido ni ninguna línea (atómico).
