# Declaración de Uso de Inteligencia Artificial (DUIA) y Bitácora

- **Herramienta utilizada:** Asistente de Inteligencia Artificial (Gemini / Kiro / OpenCode).
- **Propósito:** Asistencia en la redacción de especificaciones técnicas (`specs/`), diseño de scripts SQL para vistas y vistas materializadas, y estructuración del informe de mediciones.
- **Validación:** Los scripts y estructuras fueron analizados línea por línea y adaptados para su correcta ejecución.

---

## Bitácora de Decisiones Técnicas

### 1. Caso de sobreindexación descartado (Parte A)
- **Interacción:** Se evaluó mediante asistencia de IA la creación de un índice independiente adicional sobre la columna `id_categoria` en la tabla `producto` para agilizar los filtrados.
- **Decisión y justificación:** Se **descartó** la propuesta de crear dicho índice simple por considerarlo redundante. Dado que la tabla ya contaba con un índice compuesto que integraba el filtrado por categoría y el ordenamiento por precio, añadir un índice aislado duplicaba espacio en disco y generaba una penalización innecesaria en las operaciones de escritura (`INSERT`), sin aportar mejoras reales al planificador.

### 2. Verificación de equivalencia de resultados (Parte B)
- **Interacción:** Se generaron las vistas relacionales (como `v_productos_vigentes` y `v_pedidos_usuarios`) con asistencia de OpenCode.
- **Decisión y justificación:** Se **aceptó** la estructura de los `JOIN` y filtros tras realizar la verificación de equivalencia requerida. Se ejecutaron manualmente las consultas equivalentes en crudo contra la base de datos y se contrastaron contra las vistas, comprobando una coincidencia exacta de filas y columnas. Asimismo, se validó el criterio de seguridad al omitir la columna de contraseña en la vista de usuarios.