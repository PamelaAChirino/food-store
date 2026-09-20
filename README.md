# Food Store — Base de Datos II (Trabajo Práctico Integrador)

Repositorio oficial correspondiente al Trabajo Práctico de Base de Datos II. Este proyecto implementa la optimización de consultas mediante índices estratégicos, vistas relacionales con aplicación de criterios de seguridad, una vista materializada orientada a reportes analíticos de alta performance, y un riguroso flujo de trabajo documentado mediante especificaciones técnicas (`specs/`) y bitácora de uso de IA (`duia.md`).

---

## 📂 Estructura del Repositorio

food-store/
├── schema.sql                  # Estructura base de las tablas del sistema
├── seed.sql                    # Datos de prueba e inserciones iniciales
├── indices.sql                 # Creación de índices optimizados y análisis (Parte A)
├── views.sql                   # Vistas relacionales de reportes/seguridad (Parte B) y vista materializada (Parte C)
├── scripts/                    # Scripts auxiliares de carga masiva, optimización y reportes analíticos
├── specs/                      # Carpeta con las especificaciones técnicas de desarrollo (Kiro)
│   ├── spec_indices.md
│   ├── spec_vistas.md
│   ├── spec_vistas_parte_b.md
│   └── spec_vistas_materializadas_parte_c.md
├── duia.md                     # Declaración de Uso de IA y bitácora de decisiones técnicas
├── informe_mediciones.md       # Resultados de EXPLAIN ANALYZE, rendimiento y justificaciones
└── README.md                   # Guía de reproducción y documentación del proyecto

---

## 🚀 Requisitos Técnicos y Entorno

- **Motor de Base de Datos:** PostgreSQL (compatible con versiones 12 o superiores).
- **Herramienta de gestión sugerida:** DBeaver, pgAdmin o terminal `psql`.

---

## ⚙️ Orden de Ejecución para Reproducir las Pruebas

Para levantar la base de datos de manera limpia y verificar todas las optimizaciones implementadas, ejecute los scripts en el siguiente orden estricto:

1. **Crear esquema de datos base:**
   `\i schema.sql`

2. **Cargar los datos iniciales:**
   `\i seed.sql`

3. **Aplicar la optimización de índices (Parte A):**
   `\i indices.sql`

4. **Implementar vistas relacionales y vista materializada (Partes B y C):**
   `\i views.sql`

---

## 📊 Resumen de Componentes Implementados

- **Parte A (Índices):** Incorporación de índices estratégicos evaluando planes de ejecución mediante `EXPLAIN ANALYZE` y justificando el descarte de sobreindexación en el informe.
- **Parte B (Vistas y Seguridad):** Creación de vistas relacionales de reportes y de seguridad (ocultando datos sensibles como contraseñas), validadas contra consultas equivalentes.
- **Parte C (Vista Materializada):** Implementación de la vista materializada para reportes agregados junto a su índice único exclusivo, permitiendo actualizaciones concurrentes eficientes (`REFRESH MATERIALIZED VIEW CONCURRENTLY`).