# Requirements — Food Store en la feria (base de la tablet)

**Equipo:** Pamela Chirino · Lucas Agüero · Mayra Mule
**Contexto:** el food truck vende en una feria sin señal. La tablet guarda una copia del catálogo y arma borradores; PostgreSQL decide precio, stock y ventas.

## Historia de usuario
COMO vendedor del food truck QUIERO armar pedidos en la tablet sin conexión PARA atender en la feria y que el servidor decida después si se pueden concretar.

## Requisitos (notación EARS)

**REQ-01 — Catálogo sin conexión** (ubicuo)
THE SYSTEM SHALL mostrar el catálogo disponible leyendo solo `producto_cache`, sin conectarse al servidor.
Se prueba con: **C1**

**REQ-02 — Conflicto de precio** (disparado por evento)
WHEN el precio actual del servidor es distinto del `precio_centavos_visto` de algún ítem y no hay otro problema
THE SYSTEM SHALL marcar la solicitud como CONFLICTO y guardar el precio viejo y el nuevo en el motivo.
Se prueba con: **C2**

**REQ-03 — Rechazo por stock o baja** (disparado por evento)
WHEN algún producto del borrador no existe, no está disponible, fue dado de baja o pide más unidades que el stock de la instantánea
THE SYSTEM SHALL marcar la solicitud como RECHAZADO con el motivo, sin modificar stock ni precio en PostgreSQL.
Se prueba con: **C3, C4**

**REQ-04 — Idempotencia** (comportamiento no deseado)
IF llega una solicitud con un `solicitud_uuid` que ya existe en `cola_sync`
THEN THE SYSTEM SHALL rechazarla por clave primaria y la simulación no volverá a evaluar solicitudes que no estén PENDIENTE.
Se prueba con: **C6** (y C5 como camino feliz: todo coincide → SIMULADO_APROBADO)

**REQ-05 — Datos inválidos** (comportamiento no deseado, extra)
IF un ítem tiene cantidad menor o igual a 0 o un producto que no está en el catálogo local
THEN THE SYSTEM SHALL dar error y no dejar filas nuevas.
Se prueba con: **C7**

## Fuera de alcance
- Confirmar ventas, descontar stock o cambiar precios en PostgreSQL desde la tablet.
- App de celular, interfaz gráfica o sincronización real por red.
