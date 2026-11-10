# Food Store · TP8 — La base de la tablet y el cierre de la capa de datos

Base de Datos II · Tecnicatura Universitaria en Programación · UTN · 2026
**Equipo:** Pamela Chirino · Lucas Agüero · Mayra Mule

> Regla de oro: **el móvil propone, el servidor dispone.** La tablet solo consulta y arma borradores. `SIMULADO_APROBADO` no es una venta.

## Requisitos
- PostgreSQL 16+ con `psql` (una base de **pruebas**, nunca la real)
- SQLite 3.37+ con `sqlite3` (o DB Browser for SQLite)

## Opción rápida (todo de una)
```bash
createdb foodstore_pruebas
./correr_todo.sh          # recrea todo y guarda la evidencia en docs/evidencia/salida_completa.txt
```

## Orden paso a paso (desde cero)
Desde la carpeta `food-store/`:

| # | Qué | Comando |
|---|---|---|
| 1 | Crear la copia de pruebas del servidor (tablas, datos inventados, vista `v_snapshot_movil`) | `createdb foodstore_pruebas` y `psql -d foodstore_pruebas -f servidor/foodstore_pruebas.sql` |
| 2 | Control del servidor ANTES | `psql -d foodstore_pruebas -f servidor/control_servidor.sql` |
| 3 | Crear la base de la tablet (1.b) | `cd movil && rm -f foodstore_movil.db && sqlite3 foodstore_movil.db < schema_sqlite.sql` |
| 4 | Exportar la instantánea (2.a) | `psql -d foodstore_pruebas -c "\copy (SELECT * FROM v_snapshot_movil) TO 'movil/servidor_snapshot.csv' CSV HEADER"` |
| 5 | Importarla y cargar `producto_cache` | `cd movil && sqlite3 foodstore_movil.db < cargar_snapshot.sql` |
| 6 | Pruebas 1.c (COMMIT, ROLLBACK, C1, C7) | `sqlite3 foodstore_movil.db < pruebas_sqlite.sql` |
| 7 | Borradores de los casos C2–C5 | `sqlite3 foodstore_movil.db < casos/01_borradores_casos.sql` |
| 8 | Cambios del administrador en el servidor (C2 precio, C4 baja) | `psql -d foodstore_pruebas -f servidor/casos_servidor.sql` |
| 9 | Nueva instantánea | repetir pasos 4 y 5 |
| 10 | Semáforo (2.b) | `sqlite3 foodstore_movil.db < semaforo.sql` |
| 11 | C2: el cliente acepta y se reenvía con UUID nuevo | `sqlite3 foodstore_movil.db < casos/03_c2_cliente_acepta.sql` y otra vez `semaforo.sql` |
| 12 | C4: catálogo sin el producto, la fila queda | `sqlite3 foodstore_movil.db < casos/05_c4_catalogo.sql` |
| 13 | C6: reenviar el mismo UUID (error esperado) y repetir semáforo (0 cambios) | `sqlite3 foodstore_movil.db < casos/04_c6_reenvio.sql` y `semaforo.sql` |
| 14 | Control del servidor DESPUÉS (tiene que dar igual que el paso 2) | `psql -d foodstore_pruebas -f servidor/control_servidor.sql` |

Los errores `CHECK constraint failed`, `FOREIGN KEY constraint failed` (paso 6) y `UNIQUE constraint failed` (paso 13) son **esperados**: son las pruebas.

**Importante:** `PRAGMA foreign_keys` vale solo para la conexión. Todos los scripts lo activan en la primera línea; si abren la base en DB Browser, ejecútenlo antes de insertar.

## Estructura
```
food-store/
├── README.md
├── correr_todo.sh
├── servidor/                 copia de PRUEBAS de PostgreSQL
│   ├── foodstore_pruebas.sql     esquema + datos inventados + v_snapshot_movil
│   ├── casos_servidor.sql        cambios para C2 y C4
│   └── control_servidor.sql      pedidos y stock antes/después
├── movil/
│   ├── schema_sqlite.sql         1.b
│   ├── pruebas_sqlite.sql        1.c
│   ├── cargar_snapshot.sql       2.a
│   ├── semaforo.sql              2.b
│   ├── servidor_snapshot.csv     2.a (última instantánea)
│   ├── foodstore_movil.db
│   └── casos/                    2.c
└── docs/
    ├── informe.pdf               1.a, 2.c, 3.a, 3.b, 3.c
    ├── kiro/                     requirements.md · design.md · tasks.md
    ├── bitacora_ia.md
    ├── DUIA.md
    ├── guion_defensa.md          ensayo de 10 minutos
    └── evidencia/                salidas reales de las corridas
```
