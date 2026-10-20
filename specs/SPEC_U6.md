# Especificación y Plan de Mantenimiento - Food Store (Unidad 6)

- **Proyecto**: Food Store (PostgreSQL 16+)
- **Integrantes**: Pamela Chirino, Lucas Agüero, Mayra Mulé

---

## 1. Propósito y Objetivos de Recuperación (RPO y RTO)
El plan de mantenimiento asegura la disponibilidad, integridad y recuperabilidad de la base de datos `foodstore`. 
- **RPO (Recovery Point Objective)**: Máximo 5 minutos para datos operativos mediante archivado continuo de WAL.
- **RTO (Recovery Time Objective)**: Máximo 1 hora, validado mediante ensayos semanales de restauración en entornos descartables.

## 2. Plan de Tareas Rutinarias

| Tarea | Frecuencia | Herramienta / Mecanismo | Rol de Ejecución | Evidencia / Destino |
| :--- | :--- | :--- | :--- | :--- |
| **Respaldo lógico** | Diaria (02:00) | Script de respaldo (`pg_dump` formato custom) | `mant_backup` | Archivo `.dump` + `.sha256` + Fila en `mantenimiento.bitacora` |
| **Chequeo de salud** | Diaria | `health_check.sql` | `mant_monitor` | Métricas de conexiones, caché y tuplas muertas |
| **Archivado de pedidos** | Mensual (Día 1, 03:00) | Procedimiento `sp_archivar_pedidos` | `admin_datos` (via `pg_cron`) | Movimiento a tablas históricas + Bitácora |
| **VACUUM y ANALYZE** | Diaria (03:30) | `pg_cron` (`VACUUM ANALYZE`) | `admin_datos` | `cron.job_run_details` |
| **Controles de integridad** | Diaria (04:00) | Función `fn_verificar_integridad()` | `admin_datos` (via `pg_cron`) | Registro de estado en bitácora |
| **Verificación de índices** | Semanal (Domingo 04:30) | `amcheck` (`bt_index_check`) | `admin_datos` (via `pg_cron`) | `cron.job_run_details` |
| **Prueba de restauración** | Semanal (Domingo 06:00) | Script de restauración de prueba | Superusuario (en entorno de pruebas) | Restauración exitosa en `foodstore_restore_test` y RTO medido |

## 3. Criterios de Seguridad y Aceptación
1. **Mínimo Privilegio**: Las tareas se ejecutan con roles específicos (`mant_backup`, `mant_monitor`, `admin_datos`), prohibiendo el uso de superusuario para rutinas diarias.
2. **Cero Contraseñas**: No se almacenan credenciales en texto plano dentro de los scripts; se utiliza el archivo de configuración del sistema (`.pgpass` / `pgpass.conf`).
3. **Resguardo Atómico**: Los respaldos se generan en archivos temporales (`.parcial`) y solo se renombran tras verificar su integridad mediante `pg_restore --list` y un hash SHA-256.
4. **Entornos Descartables**: Las pruebas destructivas y de restauración se ejecutan exclusivamente sobre bases de prueba (`foodstore_restore_test`), protegiendo la base productiva.