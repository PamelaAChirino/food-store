PRAGMA foreign_keys = ON;
-- =====================================================================
-- Food Store · Base de Datos II · TP8 · Consigna 1.b
-- movil/schema_sqlite.sql — base local de la tablet (SQLite 3.37+)
-- Regla de oro: el móvil propone, el servidor dispone.
-- La tablet guarda una COPIA del catálogo y BORRADORES. Nada de esto es
-- una venta: precio, stock y ventas los decide PostgreSQL.
-- Uso: sqlite3 foodstore_movil.db < schema_sqlite.sql
-- =====================================================================

DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;
DROP TABLE IF EXISTS snapshot_servidor;

-- Copia local del catálogo (solo lectura para la tablet).
-- Se carga desde snapshot_servidor; nunca se escribe "hacia" el servidor.
CREATE TABLE producto_cache (
    id              INTEGER PRIMARY KEY,                      -- mismo id que en PostgreSQL
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto     INTEGER NOT NULL CHECK (stock_visto >= 0), -- lo que había al copiar, no el real
    disponible      INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado       INTEGER NOT NULL DEFAULT 0 CHECK (eliminado IN (0, 1)), -- lápida
    copiado_en      TEXT    NOT NULL                          -- fecha de la instantánea
) STRICT;

-- Pedido armado en la feria, sin señal. Es un BORRADOR, no una venta.
CREATE TABLE pedido_borrador (
    id_local   TEXT PRIMARY KEY CHECK (length(id_local) = 36),  -- UUID generado en la tablet
    usuario    TEXT NOT NULL,                                   -- alias inventado, sin mail ni datos reales
    forma_pago TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha      TEXT NOT NULL DEFAULT (datetime('now', 'localtime'))
) STRICT;

CREATE TABLE item_borrador (
    id_local              TEXT    NOT NULL REFERENCES pedido_borrador (id_local) ON DELETE CASCADE,
    producto_id           INTEGER NOT NULL REFERENCES producto_cache (id),
    cantidad              INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)          -- un renglón por producto en cada borrador
) STRICT;

-- Cola de solicitudes de sincronización. Cada envío tiene su propio UUID:
-- reenviar la misma solicitud choca con la clave primaria (idempotencia).
CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY CHECK (length(solicitud_uuid) = 36),
    id_local       TEXT NOT NULL REFERENCES pedido_borrador (id_local),
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE'
                   CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo         TEXT,
    creada_en      TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    evaluada_en    TEXT
) STRICT;

-- Tabla de paso: recibe el CSV exportado de v_snapshot_movil tal cual.
-- disponible/eliminado vienen de psql como 't' / 'f'.
CREATE TABLE snapshot_servidor (
    id              INTEGER PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL,
    stock           INTEGER NOT NULL,
    disponible      TEXT    NOT NULL CHECK (disponible IN ('t', 'f')),
    eliminado       TEXT    NOT NULL CHECK (eliminado  IN ('t', 'f')),
    fecha_snapshot  TEXT    NOT NULL
) STRICT;

CREATE INDEX idx_cola_estado ON cola_sync (estado);
CREATE INDEX idx_item_producto ON item_borrador (producto_id);
