# TP Unidad 4 — FNBC y Desnormalización Controlada — Observaciones de verificación

Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé

Este documento registra la verificación empírica (PostgreSQL 16) de la resolución
y dos ajustes puntuales aplicados antes de la entrega, en línea con el criterio de
la cátedra: *"una afirmación sin el artefacto que la demuestre no se considera
resuelta."*

## Parte 1 — FNBC (`tp_fnbc_control_lote.sql`)

Verificado end-to-end contra una base de prueba: ambos `EXCEPT` (legacy ↔ vista
de compatibilidad) retornan 0 filas, y el chequeo opcional de la DF1 también
retorna 0 filas. El análisis de dependencias funcionales, clausuras, claves
candidatas, prueba de violación de FNBC y descomposición sin pérdida es correcto.
**Sin cambios.**

## Parte 2 — Desnormalización (`tp_desnormalizacion_top_categorias.sql`)

### Corrección aplicada: faltaba la sección "3b"

El informe menciona una versión ampliada del script de auditoría ("3b") que
compara todas las fechas y detecta categorías presentes en la fuente pero
ausentes en la vista — pero esa sección no estaba en el `.sql` entregado
(solo existía la auditoría de la sección 3, acotada a una fecha puntual).

Al revisar la sección 3 tal cual estaba, se detectó además que tiene un problema
de diseño: filtra por `v.fecha = '2026-09-15'` recién en el `WHERE` externo,
**después** del `JOIN`. Si una categoría no tiene ninguna fila en la vista para
esa fecha puntual (por ejemplo, la vista está desactualizada y esa categoría
recién tuvo ventas hoy), el `FULL OUTER JOIN` igual la empareja con una fila de
**otra fecha** de la misma categoría, y el filtro externo descarta el resultado.
La auditoría da 0 filas aunque falten datos reales — un falso "todo bien".

Se comprobó empíricamente: se insertó una venta nueva en una categoría sin
datos previos en la vista para la fecha auditada, sin refrescar la vista, y la
sección 3 no detectó el faltante (0 filas). Se agregó la sección 3b —
comparando por `(fecha, categoria)` en conjunto, igual que la clave del índice
único de la vista, y filtrando por fecha *antes* del `JOIN`— y con el mismo
escenario sí detectó correctamente la diferencia.

La sección 3 original se dejó intacta (documentada tal cual la entregó la
compañera); la 3b fue agregada al final del archivo.

### Recomendaciones menores (no bloqueantes, pero vale mencionarlas si preguntan)

- El enunciado original de la consigna filtraba por `eliminado = false`. En el
  esquema real de Food Store, `pedido` y `pedido_producto` no tienen columna de
  borrado lógico (solo `producto` y `categoria` la tienen, vía `activo`), así
  que ese filtro no aplica tal cual. Se mantuvo sin el filtro, lo cual es
  razonable para un reporte de ventas históricas (un producto discontinuado
  igual debería contar en el total vendido de su categoría), pero conviene que
  el informe lo mencione como adaptación explícita, siguiendo el mismo criterio
  usado en TP3/TP4/TP5.
- El comentario sobre que las `REFERENCES` a `lote`/`deposito`/`usuario` "se
  activan al ejecutar sobre la base completa de Food Store" es engañoso: esas
  tablas no existen en el proyecto real — Parte 1 es un escenario nuevo que
  extiende el modelo, no algo que ya esté en la base. Conviene aclararlo en el
  informe para no dar a entender que falta correr algo sobre el proyecto real.
- El tiempo "antes" (≈1.63 ms) se tomó del campo `actual time` del nodo `Limit`
  en vez de la línea explícita `Execution Time:` (como sí se hizo en el "después",
  0.249 ms). No cambia la conclusión, pero por prolijidad metodológica convendría
  volver a capturar el "antes" con `Execution Time:` explícito para que ambas
  mediciones se reporten de la misma forma.

## Conclusión

Contenido académico de Parte 1: excelente, verificado, sin cambios. Parte 2:
correcta en su diseño (vista materializada + índice único + REFRESH
CONCURRENTLY + auditoría), con un gap real en el script de auditoría que ya
fue corregido (sección 3b agregada y probada). Recomendado agregar al informe
una línea que documente el agregado de 3b.
