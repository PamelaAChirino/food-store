# Design — base de la tablet

## Decisiones
| Decisión | Por qué |
|---|---|
| SQLite con tablas `STRICT` y `PRAGMA foreign_keys = ON` en cada script | Tipos y claves foráneas que de verdad se controlan (por defecto SQLite no las activa) |
| Precios en centavos (`INTEGER`) | Evitar errores de redondeo de `REAL` |
| `id_local` y `solicitud_uuid` como UUID texto (36) | Se generan sin servidor y no chocan entre tablets |
| Lápidas (`eliminado = 1`) en vez de borrar | Los borradores viejos siguen apuntando a una fila válida |
| `snapshot_servidor` como tabla de paso | Recibe el CSV crudo (`t`/`f`) y después se pasa a `producto_cache` |

## Tablas
- `producto_cache` — copia del catálogo (id, nombre, precio_centavos, stock_visto, disponible, eliminado, copiado_en)
- `pedido_borrador` — encabezado (id_local, usuario, forma_pago, fecha)
- `item_borrador` — renglones (id_local, producto_id, cantidad, precio_centavos_visto)
- `cola_sync` — solicitudes (solicitud_uuid PK, id_local, estado, motivo)
- `snapshot_servidor` — instantánea importada de `v_snapshot_movil`

## Flujo
1. PostgreSQL de pruebas → `v_snapshot_movil` → `\copy` a CSV.
2. SQLite → `.import` a `snapshot_servidor` → upsert en `producto_cache`.
3. La tablet arma borrador + ítems + solicitud en una transacción.
4. `semaforo.sql` evalúa solo las PENDIENTE: ROJO → RECHAZADO, AMARILLO → CONFLICTO, VERDE → SIMULADO_APROBADO.
5. PostgreSQL no se modifica.
