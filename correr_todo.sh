#!/usr/bin/env bash
# =====================================================================
# Food Store · TP8 · Recrea TODO desde cero y guarda la evidencia.
# Uso:  ./correr_todo.sh                (usa la base "foodstore_pruebas")
#       PGDATABASE=otra ./correr_todo.sh
# Requiere psql y sqlite3 en el PATH. La salida completa queda en
# docs/evidencia/salida_completa.txt
# =====================================================================
set -u
cd "$(dirname "$0")"
export PGDATABASE="${PGDATABASE:-foodstore_pruebas}"
LOG=docs/evidencia/salida_completa.txt
mkdir -p docs/evidencia
: > "$LOG"

titulo() { printf '\n\n==================== %s ====================\n' "$1" | tee -a "$LOG"; }
pg()     { psql -X -q -v ON_ERROR_STOP=1 "$@" 2>&1 | tee -a "$LOG"; }
lite()   { (cd movil && sqlite3 foodstore_movil.db < "$1") 2>&1 | tee -a "$LOG"; }
snapshot() {
  psql -X -q -c "\copy (SELECT * FROM v_snapshot_movil) TO 'movil/servidor_snapshot.csv' CSV HEADER"
  cp movil/servidor_snapshot.csv "docs/evidencia/$1"
  echo "-- instantánea exportada: $1" | tee -a "$LOG"; cat movil/servidor_snapshot.csv | tee -a "$LOG"
}

titulo "0. Servidor de PRUEBAS (PostgreSQL) desde cero"
pg -f servidor/foodstore_pruebas.sql 2>/dev/null
titulo "0b. Control del servidor ANTES"
pg -f servidor/control_servidor.sql

titulo "1.b Esquema SQLite de la tablet"
rm -f movil/foodstore_movil.db
lite schema_sqlite.sql
(cd movil && sqlite3 foodstore_movil.db ".tables") | tee -a "$LOG"

titulo "2.a Instantánea 1 (inicial) -> SQLite"
snapshot snapshot_1_inicial.csv
lite cargar_snapshot.sql

titulo "1.c Pruebas: COMMIT/ROLLBACK, C1 y C7"
lite pruebas_sqlite.sql

titulo "2.c Paso 1: borradores C2-C5 (con precios de la instantánea 1)"
lite casos/01_borradores_casos.sql

titulo "2.c Paso 2: cambios en el servidor (C2 sube precio, C4 baja lógica)"
pg -f servidor/casos_servidor.sql

titulo "2.c Paso 3: instantánea 2 -> SQLite y semáforo"
snapshot snapshot_2_casos.csv
lite cargar_snapshot.sql
lite semaforo.sql

titulo "C2: el cliente acepta el precio nuevo -> solicitud nueva -> semáforo"
lite casos/03_c2_cliente_acepta.sql
lite semaforo.sql

titulo "C4: catálogo recargado (la lápida queda)"
lite casos/05_c4_catalogo.sql

titulo "C6: reenviar la misma solicitud + repetir el semáforo"
lite casos/04_c6_reenvio.sql
lite semaforo.sql

titulo "Control del servidor DESPUÉS (pedidos y stock iguales)"
pg -f servidor/control_servidor.sql

echo -e "\nListo. Evidencia en $LOG"
