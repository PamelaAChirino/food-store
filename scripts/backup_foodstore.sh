#!/usr/bin/env bash
# ============================================================================
# Trabajo Práctico Unidad 6 - Parte 2: Respaldo automatizable
# Script: backup_foodstore.sh
# Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
# ============================================================================
# Versión .sh del respaldo (la consigna acepta .ps1 O .sh). Se agrega para
# poder probar y ejecutar el ciclo de respaldo/restauración de forma real en
# Linux/CI, y como opción si algún integrante corre PostgreSQL fuera de
# Windows. Mismo comportamiento que backup_foodstore.ps1: conecta como el
# rol de mínimo privilegio mant_backup, nunca expone la contraseña en el
# script (usa ~/.pgpass), y deja log + archivo .dump con fecha/hora.
# ============================================================================

set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-mant_backup}"
BASE="foodstore"
DESTINO="backups"
LOGDIR="logs"

mkdir -p "$DESTINO" "$LOGDIR"

FECHA="$(date +%Y-%m-%d_%H%M)"
ARCHIVO="$DESTINO/foodstore_${FECHA}.dump"
LOG="$LOGDIR/backup_${FECHA}.log"

echo "[$(date)] Inicio de respaldo -> $ARCHIVO" > "$LOG"

if pg_dump -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$BASE" -Fc -f "$ARCHIVO" 2>> "$LOG"; then
    echo "[$(date)] Respaldo OK: $ARCHIVO" >> "$LOG"
    echo "Respaldo finalizado con éxito: $ARCHIVO"
else
    codigo=$?
    echo "[$(date)] ERROR: pg_dump finalizó con código de error $codigo" >> "$LOG"
    echo "El respaldo falló. Revisa el archivo de log en $LOG" >&2
    exit "$codigo"
fi
