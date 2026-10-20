# Requerimientos - Parte A: Roles y Permisos (Unidad 5)

## 1. Objetivo
Implementar una política de seguridad basada en el principio de mínimo privilegio sobre la base de datos del sistema **Food Store**, estructurando roles de grupo y de acceso para los distintos perfiles de usuarios y aplicaciones.

## 2. Requerimientos de Roles de Grupo (NOLOGIN)
- **`rol_app_lectura`**: 
  - Acceso de sólo lectura (`SELECT`) sobre los catálogos principales (`producto`, `categoria`).
  - Acceso restringido (seguridad a nivel de columna) sobre la tabla de clientes, limitando la visibilidad únicamente a los campos operativos (`id_cliente`, `nombre`, `apellido`, `telefono`, `email`), ocultando información sensible.
- **`rol_app_escritura`**: 
  - Permisos de inserción, actualización y lectura (`SELECT`, `INSERT`, `UPDATE`) en las tablas transaccionales del negocio (`pedido`, `pedido_producto`, `cliente`).
  - Permisos de uso sobre las secuencias del esquema para permitir la generación de identificadores.
- **`rol_reportes`**: 
  - Acceso global de lectura sobre las tablas del sistema y sobre las vistas materializadas analíticas creadas (ej. `mv_top_categorias_dia`).
- **`rol_soporte`**: 
  - Acceso de consulta general para tareas de diagnóstico y mantenimiento operativo.

## 3. Requerimientos de Roles de Login (Autenticación)
- **`app_web`**: Usuario técnico utilizado por la aplicación web, el cual heredará los privilegios de los grupos `rol_app_lectura` y `rol_app_escritura`.
- **`admin_datos`**: Usuario técnico para administración y auditoría, heredando los privilegios de `rol_reportes` y `rol_soporte`.

## 4. Políticas de Seguridad por Defecto
- Revocación de permisos públicos de creación sobre el esquema `public` (`REVOKE CREATE ON SCHEMA public FROM PUBLIC`).
- Configuración de `ALTER DEFAULT PRIVILEGES` para garantizar que cualquier futura tabla creada en el esquema herede automáticamente los permisos correspondientes para los roles de lectura y escritura.