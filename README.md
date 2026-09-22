# Food Store — Base de Datos II (Trabajo Práctico Integrador)

Repositorio del Trabajo Práctico Integrador (TPI) de Base de Datos II. El
proyecto modela un sistema de gestión de pedidos de un negocio de comidas y
cubre, de punta a punta, las tres primeras unidades de la materia:
integridad/transacciones/concurrencia, optimización de consultas, e
índices/vistas/objetos programables — todo en PostgreSQL 16+ con PL/pgSQL.

---

## 📂 Estructura del repositorio

```
food-store/
├── schema.sql                        # DDL base: tipos, tablas, PK/FK, CHECK, índices y trigger de venta
├── 02_restricciones_negocio.sql      # Restricciones de negocio (fecha no futura, venta con control de stock) + pruebas con SAVEPOINT
├── data.sql                          # Datos de carga inicial para desarrollo y pruebas
├── indices.sql                       # Índices adicionales de la Parte A (Unidad 3)
├── views.sql                         # Vistas relacionales (seguridad/reportes) + vista materializada con índice único
├── procedimiento.sql                 # Procedimiento almacenado sp_registrar_pedido (PL/pgSQL, invocado con CALL)
├── queries.sql                       # Consultas de negocio y analíticas: JOIN, agregación, subconsultas, funciones de ventana
├── protocolo_seguridad.md            # Protocolo obligatorio antes de correr cualquier script (copia de trabajo, transacciones reversibles)
├── ejercicio_lectura_critica.md      # Análisis crítico de scripts riesgosos (UPDATE sin WHERE, DELETE con NOT IN + NULL)
├── duia.md                           # Declaración de Uso de IA: herramienta, prompt, qué se aceptó/descartó y por qué
│
├── scripts/                          # Scripts auxiliares de carga masiva y optimización
│   ├── carga_masiva.sql              #   Poblamiento masivo con generate_series (50k productos, 20k clientes, 200k pedidos)
│   ├── carga_detalle.sql             #   Carga de detalle de pedidos (pedido_producto) para el volumen histórico
│   ├── optimizacion.sql              #   Análisis de rendimiento: EXPLAIN ANALYZE antes/después de cada índice
│   └── reportes_analiticos_IA.sql    #   Consultas analíticas con JOIN múltiple y funciones de ventana
│
├── specs/                            # Especificaciones técnicas de desarrollo (Kiro)
│   ├── spec_indices.md
│   ├── spec_vistas.md
│   ├── spec_vistas_parte_b.md
│   └── spec_vistas_materializadas_parte_c.md
│
├── informes/                         # Informes y entregas por unidad/semana
│   ├── TP1_FoodStore.md              #   Modelo ER, paso a relacional y normalización 3FN/BCNF
│   ├── TP3_Semana3.md                #   Carga masiva y optimización de consultas con filtro simple
│   ├── TP4_Semana4.md                #   Consultas analíticas con múltiples JOIN y funciones de ventana
│   ├── informe_concurrencia.md       #   Laboratorio de concurrencia: lectura no repetible, fantasma y bloqueo (2 sesiones psql)
│   ├── informe_mediciones.md         #   Mediciones EXPLAIN ANALYZE, índices descartados y verificación de vistas
│   └── informe_tecnico.md            #   Informe técnico consolidado de la entrega (qué se hizo, cómo se probó, resultados, uso de IA)
│
├── capturas/                         # Evidencia visual (diagrama ER y capturas de ejecución)
│   ├── DiagramaER.jpeg
│   ├── captura_clientes.png
│   ├── captura_pedidos.png
│   └── captura_productos.png
│
├── .kiro/steering/                   # Reglas de contexto del proyecto para el asistente Kiro
│   ├── project.md
│   ├── database-schema.md
│   └── sql-conventions.md
│
└── README.md                         # Este archivo
```

---

## 🚀 Requisitos técnicos y entorno

- **Motor de base de datos:** PostgreSQL 16 o superior (requisito obligatorio del
  TPI: usa tipos `ENUM`, `TIMESTAMPTZ`, columnas `IDENTITY`, `JSONB` y
  procedimientos invocados con `CALL`, específicos de este motor).
- **Herramienta de gestión sugerida:** `psql`, DBeaver o pgAdmin.

---

## ⚙️ Orden de ejecución para reproducir el proyecto

Ejecutar en este orden estricto sobre una base de trabajo (nunca sobre datos
reales — ver `protocolo_seguridad.md`):

1. **Crear el esquema base** (tipos, tablas, restricciones, índice y trigger de venta):
   `\i schema.sql`

2. **Aplicar las restricciones de negocio adicionales** (incluye sus propias pruebas con `SAVEPOINT`, autocontenidas en `BEGIN; ... ROLLBACK;`):
   `\i 02_restricciones_negocio.sql`

3. **Cargar datos iniciales de desarrollo:**
   `\i data.sql`

4. **(Opcional) Poblar con volumen realista para medir rendimiento:**
   `\i scripts/carga_masiva.sql`
   `\i scripts/carga_detalle.sql`

5. **Aplicar los índices de la Parte A (Unidad 3):**
   `\i indices.sql`

6. **Crear vistas, vista materializada y procedimiento almacenado:**
   `\i views.sql`
   `\i procedimiento.sql`

7. **Correr las consultas de negocio/analíticas:**
   `\i queries.sql`

---

## 📊 Resumen de componentes por unidad

- **Unidad 1 — Integridad, transacciones y concurrencia:** modelo ER y
  normalización hasta 3FN/BCNF (`informes/TP1_FoodStore.md`), DDL completo con
  `CHECK`/`UNIQUE`/FK (`schema.sql`), trigger de venta con `SELECT ... FOR
  UPDATE` para control de concurrencia, y laboratorio de aislamiento con dos
  sesiones `psql` reales (`informes/informe_concurrencia.md`).
- **Unidad 2 — Optimización de consultas:** carga masiva de volumen realista
  (`scripts/carga_masiva.sql`, `scripts/carga_detalle.sql`), consultas con
  JOIN, agregación, subconsultas y funciones de ventana (`queries.sql`), y
  medición de planes con `EXPLAIN ANALYZE` antes/después de cada cambio
  (`scripts/optimizacion.sql`, `informes/TP3_Semana3.md`, `informes/TP4_Semana4.md`).
- **Unidad 3 — Índices, vistas y objetos programables:** plan de indexado con
  índices aceptados y descartados con evidencia (`indices.sql`,
  `informes/informe_mediciones.md`), vistas de seguridad/reportes y vista
  materializada con índice único para `REFRESH CONCURRENTLY` (`views.sql`), y
  procedimiento almacenado en PL/pgSQL invocado con `CALL`
  (`procedimiento.sql`).

El informe técnico consolidado de toda la entrega —qué se implementó, cómo se
probó, qué resultados se obtuvieron, qué consultas se optimizaron y qué otras
herramientas de IA se usaron— está en `informes/informe_tecnico.md`.
