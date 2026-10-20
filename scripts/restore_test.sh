#!/usr/bin/env bash
# ============================================================================
# Trabajo Práctico Unidad 6 - Parte 4: Simulacro de restauración + RTO/RPO
# Script: restore_test.sh
# Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
# ============================================================================
# Automatiza el simulacro de la consigna: crea foodstore_restore_test,
# restaura el último .dump disponible con pg_restore --no-owner
# --no-privileges, corre las validaciones mínimas (conteo de filas por
# tabla + controles de productos/pedido_producto inválidos), y mide:
#   - RTO observado: tiempo entre el inicio de createdb y el fin de las
#     validaciones.
#   - RPO observado: antigüedad del .dump usado respecto al momento del
#     simulacro (cuánto dato se "perdería" si el incidente fuera ahora).
# ============================================================================

set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-postgres}"
BASE_RESTORE="foodstore_restore_test"
DESTINO="backups"

ULTIMO_DUMP="$(ls -t "$DESTINO"/foodstore_*.dump 2>/dev/null | head -n1)"
if [ -z "$ULTIMO_DUMP" ]; then
    echo "No hay ningún .dump en $DESTINO/. Corré backup_foodstore.sh primero." >&2
    exit 1
fi

FECHA_DUMP_EPOCH=$(stat -c %Y "$ULTIMO_DUMP")
AHORA_EPOCH=$(date +%s)
RPO_SEGUNDOS=$((AHORA_EPOCH - FECHA_DUMP_EPOCH))

echo "Usando respaldo: $ULTIMO_DUMP"
echo "Antigüedad del respaldo (RPO observado): ${RPO_SEGUNDOS}s"

INICIO=$(date +%s.%N)

dropdb -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" --if-exists "$BASE_RESTORE"
createdb -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" "$BASE_RESTORE"
pg_restore -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$BASE_RESTORE" --no-owner --no-privileges "$ULTIMO_DUMP"

echo ""
echo "=== Validación mínima (Parte 4) ==="
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$BASE_RESTORE" -c "
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'pedido_producto', COUNT(*) FROM pedido_producto;
"

psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$BASE_RESTORE" -c "
SELECT COUNT(*) AS productos_invalidos FROM producto WHERE precio < 0 OR stock < 0;
"

psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$BASE_RESTORE" -c "
SELECT COUNT(*) AS detalles_invalidos FROM pedido_producto WHERE cantidad <= 0 OR precio_unitario < 0;
"

FIN=$(date +%s.%N)
RTO=$(echo "$FIN - $INICIO" | bc)

echo ""
echo "=== Resultado ==="
echo "RTO observado (createdb + pg_restore + validaciones): ${RTO}s"
echo "RPO observado (antigüedad del respaldo usado): ${RPO_SEGUNDOS}s"
