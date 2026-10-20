# Diseño Técnico - Parte A: Roles y Permisos (Unidad 5)

## 1. Entorno Tecnológico
- **Sistema Gestor de Base de Datos**: PostgreSQL 17.
- **Herramienta de Administración**: DBeaver.

## 2. Estrategia de Implementación de Roles
Para cumplir con los principios de seguridad y separación de privilegios, se implementó una jerarquía basada en dos capas:
1. **Roles de Grupo (`NOLOGIN`)**: Agrupan los conjuntos de permisos según el perfil funcional (`rol_app_lectura`, `rol_app_escritura`, `rol_reportes`, `rol_soporte`). No permiten conexiones directas por motivos de seguridad.
2. **Roles de Usuario (`LOGIN`)**: Cuentan con credenciales de autenticación robustas y heredan mediante la cláusula `GRANT` los permisos de los roles de grupo correspondientes (`app_web`, `admin_datos`).

## 3. Seguridad a Nivel de Columna
Sobre la tabla sensible `cliente`, se evita otorgar permisos globales (`SELECT ON cliente`) al rol de lectura general, restringiéndolo explícitamente mediante:
```sql
GRANT SELECT (id_cliente, nombre, apellido, telefono, email) ON cliente TO rol_app_lectura;