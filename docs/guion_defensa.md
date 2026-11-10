# Guion para el ensayo de defensa (10 minutos)

**Equipo:** Pamela Chirino · Lucas Agüero · Mayra Mule

| Min | Quién | Qué mostrar | Frase clave |
|---|---|---|---|
| 0–1 | Pamela | Regla de oro y la historia de la feria | "La tablet propone, PostgreSQL dispone: SIMULADO_APROBADO no es una venta." |
| 1–3 | Lucas | **Mapa** de los tres motores (informe 3.a) | "Cada dato tiene un solo dueño. El precio y el stock los manda PostgreSQL; la tablet solo tiene una copia con fecha." |
| 3–7 | Mayra | **Caso en vivo: C2** (o C6) | Ver abajo |
| 7–9 | Pamela | **Hallazgo de la IA**: el semáforo ingenuo con `LEFT JOIN` | "Con NULL, SUM no cuenta el problema y la solicitud salía VERDE. Lo probamos borrando un producto de la instantánea." |
| 9–10 | Todos | Preguntas | — |

## Caso en vivo C2 (4 minutos)
1. `SELECT * FROM cola_sync;` → la solicitud de C2 está en CONFLICTO, motivo `550000 -> 600000`.
2. Explicar: el administrador subió el precio en el servidor después de que se armó el borrador.
3. Correr `casos/03_c2_cliente_acepta.sql` → actualiza el precio visto y crea una solicitud con UUID nuevo.
4. Correr `semaforo.sql` → solo evalúa la nueva (`solicitudes_evaluadas_ahora = 1`) y da VERDE.
5. Cerrar con `control_servidor.sql` en psql: misma huella de stock y misma cantidad de pedidos.

## Preguntas probables (respuesta corta)
- **¿Por qué centavos?** Porque en `REAL` 0.1 + 0.2 ≠ 0.3; con enteros la suma es exacta.
- **¿Por qué el PRAGMA en cada script?** `foreign_keys` vale por conexión; sin él SQLite acepta un producto 999.
- **¿Por qué no se borra el producto dado de baja?** Es una lápida: los borradores viejos siguen apuntando a una fila y el catálogo la oculta con `eliminado = 0`.
- **¿Qué evita duplicar un envío?** El `solicitud_uuid` es clave primaria. En un sistema real, la protección va en el servidor: una tabla de solicitudes procesadas con el UUID como clave única, dentro de la misma transacción que crea el pedido.
- **¿Qué pasa si se restaura un respaldo viejo?** Las tablets descartan su catálogo, piden instantánea nueva y vuelven a evaluar las PENDIENTE (informe 3.b).
