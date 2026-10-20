# ============================================================================
# Trabajo Práctico Unidad 6 - Parte 2: Respaldo automatizable
# Script: backup_foodstore.ps1
# Integrantes: Pamela Chirino, Lucas Agüero, Mayra Mulé
# ============================================================================
# Corrección (Unidad 6 - revisión): el archivo se llamaba
# "backup_food_store.ps1" y la variable $Base valía 'food_store' (con guion
# bajo). La consigna pide el nombre de archivo "backup_foodstore.ps1" o
# ".sh" (sin guion bajo), y la base real del proyecto es 'foodstore'. El
# nombre del .dump generado ($Archivo, línea ~24 más abajo) ya usaba
# "foodstore_$Fecha" correctamente -- solo la variable de conexión $Base
# estaba mal, lo cual habría hecho fallar pg_dump con
# "FATAL: database "food_store" does not exist" en cuanto se intentara
# ejecutar contra la base real.
# ============================================================================

$ErrorActionPreference = 'Stop'

# Directorios y rutas (ajusta la ruta de pg_dump si es necesario)
$PgBin   = 'C:\Program Files\PostgreSQL\17\bin'
$PgHost  = 'localhost'
$PgPort  = '5432'
$PgUser  = 'mant_backup'
$Base    = 'foodstore'
$Destino = 'backups'
$LogDir  = 'logs'

# Crear carpetas si no existen
New-Item -ItemType Directory -Force -Path $Destino | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# Formato de fecha y hora para el archivo y el log
$Fecha   = Get-Date -Format 'yyyy-MM-dd_HHmm'
$Archivo = Join-Path $Destino "foodstore_$Fecha.dump"
$Log     = Join-Path $LogDir "backup_$Fecha.log"

"[$((Get-Date))] Inicio de respaldo -> $Archivo" | Out-File $Log

try {
    # Ejecución de pg_dump en formato custom (-Fc) sin exponer contraseña (usa .pgpass)
    & "$PgBin\pg_dump.exe" -h $PgHost -p $PgPort -U $PgUser -d $Base -Fc -f $Archivo 2>> $Log

    if ($LASTEXITCODE -eq 0) {
        "[$((Get-Date))] Respaldo OK: $Archivo" | Out-File $Log -Append
        Write-Output "Respaldo finalizado con éxito: $Archivo"
    } else {
        throw "pg_dump finalizó con código de error $LASTEXITCODE"
    }
}
catch {
    "[$((Get-Date))] ERROR: $_" | Out-File $Log -Append
    Write-Error "El respaldo falló. Revisa el archivo de log en $Log"
    exit $LASTEXITCODE
}
