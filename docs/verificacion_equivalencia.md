# Verificación de Equivalencia — Parte D (Unidad 5)

## 1. Qué se compara

Se construyó `usuario_anon` a partir de `cliente` (ver nota de adaptación en [`sql/usuario_anon.sql`](../sql/usuario_anon.sql): Food Store no tiene tabla `usuario` ni columna de fecha de alta, se usa `cliente` y el mes del primer pedido como proxy de "mes de alta"). Se generó la consulta de agregación sobre `usuario_anon` (cantidad de usuarios por `rol` y por `mes_alta`) y la consulta equivalente sobre los datos reales (`cliente` + `pedido`), y se verificó que ambas coinciden exactamente.

## 2. Resultado

| rol | mes_alta | total_usuarios (usuario_anon) | total_usuarios (real) |
|---|---|---|---|
| rol_app_escritura | 2026-09-01 | 1 | 1 |
| rol_app_lectura | 2026-09-01 | 1 | 1 |

Verificación formal (sección 4 del script, `EXCEPT` en ambas direcciones sobre los conteos agregados): **0 filas** — coinciden exactamente, mismos conteos, mismos agrupamientos.

## 3. Qué información no debería salir nunca hacia un asistente de IA sin anonimizar

El email real de cada cliente, su nombre y apellido completos tal como están en `cliente`, y cualquier dato que permita re-identificar a una persona a partir de la combinación de atributos (por ejemplo, teléfono + nombre). `usuario_anon` resuelve esto reemplazando el nombre por un identificador secuencial (`Usuario_<id>`) y el email por un hash irreversible (`md5(email) || '@anon.local'`) — se puede seguir agrupando y contando sin exponer el dato original, que es justamente lo que esta verificación demuestra: anonimizar no distorsiona lo que la base tiene para decir en conjunto.
