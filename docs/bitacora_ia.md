# Bitácora de uso de IA — TP8 Food Store

**Equipo:** Pamela Chirino · Lucas Agüero · Mayra Mule
**Herramientas:** Claude (Anthropic) · Kiro (spec) · OpenCode (agente Plan, code review)

| # | Qué le pedimos | Qué aceptamos | Qué descartamos / corregimos | Por qué | Cómo lo comprobamos |
|---|---|---|---|---|---|
| 1 | Armar `schema_sqlite.sql` a partir de la tabla de la consigna 1.b | Tablas `STRICT`, `CHECK` de estados y forma de pago, precio en centavos, PK compuesta en `item_borrador` | — | Cumple las reglas de la consigna y las podemos explicar | `pruebas_sqlite.sql`: C7 da `CHECK constraint failed` y `FOREIGN KEY constraint failed`, el conteo de filas no cambia |
| 2 | Escribir el semáforo usando la pista de la cátedra (`SUM(i.cantidad > s.stock OR …)`) | La idea de agrupar por solicitud y contar ítems con problema | **Corregimos** la versión literal: con `LEFT JOIN`, si el producto no está en la instantánea las comparaciones dan `NULL`, `SUM` las ignora y la solicitud sale VERDE | Un producto inexistente tiene que dar ROJO | Borramos el producto 2 de `snapshot_servidor` en una copia: versión ingenua → `SIMULADO_APROBADO`; nuestra versión → `RECHAZADO · producto 2 no existe en el servidor` |
| 3 | Sugerencias para "mejorar" la tablet | El índice por `estado` en `cola_sync` | **Descartamos** un trigger que descontaba `stock_visto` al agregar un ítem | Rompe la regla de oro: la tablet no decide el stock; además dos borradores en la misma tablet no son ventas | `grep` sobre los scripts de `movil/`: ningún `UPDATE` de stock; control en PostgreSQL antes/después con la misma huella de stock |
| 4 | Plan de mantenimiento: cómo respaldar | Respaldo completo con `pg_dump -Fc` y restauración de prueba en una base aparte | **Descartamos** respaldar solo la tabla `producto` con `-t` | La restauración falla (falta `categoria`) y no vuelve la vista `v_snapshot_movil`, de la que dependen las tablets | `docs/evidencia/verificaciones_code_review.txt` (H6) |

Nota: todo lo generado se leyó y se ejecutó antes de entregarlo; la salida completa está en `docs/evidencia/salida_completa.txt`.
