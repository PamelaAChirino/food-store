# Informe de Simulacro de Incidente — Parte C (Unidad 5)

## 1. Contexto y objetivo

Se reprodujo, exclusivamente contra el entorno de desarrollo propio, la secuencia pedida por la consigna: varios intentos fallidos de login contra `fn_autenticar`, un login exitoso, una lectura masiva de `cliente` (adaptación de "usuario", ver nota en `sql/simulacro_incidente.sql`), y un intento de escalamiento de privilegios (otorgarle a `app_web` membresía en `admin_datos`). Script completo: [`sql/simulacro_incidente.sql`](../sql/simulacro_incidente.sql).

## 2. ¿Falló el escalamiento?

**Sí, falló.** `GRANT admin_datos TO app_web;`, ejecutado con `SET ROLE app_web`, devolvió:

```
ERROR:  permission denied to grant role "admin_datos"
DETAIL:  Only roles with the ADMIN option on role "admin_datos" may grant this role.
```

Esto confirma que el diseño de permisos de la Parte A es correcto en este punto: ningún rol de aplicación tiene `CREATEROLE` ni `ADMIN OPTION` sobre `admin_datos`, así que no puede auto-otorgarse esa membresía.

## 3. Evidencia entregada a la IA (OpenCode) para la reconstrucción

Se armó un paquete de evidencia anonimizado con dos fuentes — el fragmento del log del servidor y el registro de la tabla `intento_login` — y se le entregó **sin agregar contexto adicional**, pidiéndole que reconstruya qué ocurrió y proponga una hipótesis de contención. Archivo completo: [`docs/log_simulacro_anonimizado.txt`](./log_simulacro_anonimizado.txt).

## 4. Reconstrucción de la IA (a partir únicamente de esa evidencia)

> *A partir del fragmento de log y del registro de `intento_login`, lo que se observa es: el usuario `usuario_sintetico_1@anon.local` tuvo tres intentos de autenticación fallidos seguidos de uno exitoso, en un lapso de ~20 milisegundos — un patrón compatible con un intento de fuerza bruta de baja intensidad, o con alguien reintentando manualmente una contraseña que recién en el cuarto intento recordó bien. Inmediatamente después (misma sesión, PID 308), se registra un intento de `GRANT admin_datos TO app_web`, ejecutado por el usuario conectado `postgres`, que el motor rechazó por falta de `ADMIN OPTION`. La hipótesis más simple es que, tras lograr autenticarse, el actor intentó escalar privilegios elevando a `app_web` a un rol administrativo, y el motor lo bloqueó. Como contención, recomendaría: revisar si `usuario_sintetico_1` es una cuenta legítima con mala memoria de contraseña o un origen sospechoso, y evaluar si el usuario `postgres` que ejecutó el GRANT debería tener esa conexión abierta en este contexto.*

## 5. Contraste con lo que realmente se ejecutó

| Lo que la IA reconstruyó | Lo que realmente pasó | Veredicto |
|---|---|---|
| Patrón de fuerza bruta / reintento manual sobre `usuario_sintetico_1` | Correcto: fueron 3 intentos fallidos deliberados seguidos de uno exitoso contra `fn_autenticar`, simulando exactamente eso | **Acertó** |
| El GRANT lo ejecutó "el usuario conectado `postgres`" | Técnicamente lo que el log muestra, pero **incompleto**: el `GRANT` se emitió bajo `SET ROLE app_web`, es decir, el actor efectivo era `app_web`, no `postgres`. El log no registra el `SET ROLE` (no es una sentencia de modificación, así que `log_statement = mod` no la captura), por eso la IA no pudo verlo | **La IA no se equivocó con lo que tenía, pero el log no le alcanzaba para ver la causa real** — esto es una limitación del nivel de log, no un error de lectura |
| Nada sobre la lectura masiva de `cliente` | **Ocurrió igual** (`SELECT * FROM cliente` como `app_web`), pero un `SELECT` tampoco queda registrado con `log_statement = mod` | **Omisión real, y no detectable con esta evidencia** — la IA no inventó que no había pasado nada; simplemente no tenía cómo saberlo. Si se necesitara ver lecturas masivas en el log, haría falta `log_statement = all` (con el costo de volumen que eso implica) o un mecanismo específico tipo `pgaudit` |
| Ninguna afirmación sin sustento en el log | — | La IA no inventó una causa (como "fue un ataque externo" o "fue un bug del código") que el log no sostiene; se mantuvo dentro de lo que la evidencia mostraba |

**Conclusión de la lectura crítica:** la reconstrucción de la IA fue correcta con la evidencia que tenía, pero esa evidencia tenía dos puntos ciegos reales (el `SET ROLE` y la lectura masiva, ninguno capturado por `log_statement = mod`). Es exactamente el tipo de limitación que señala el informe de Parte B (punto 3): este nivel de log no alcanza para una reconstrucción completa; hace falta cruzarlo con la auditoría de aplicación (`log_auditoria`, `intento_login`) o subir a `pgaudit` si se necesita ver cada lectura.

## 6. Decisión de contención (del equipo, no de la IA)

Esta es una decisión tomada por el equipo a partir de la evidencia reunida, **no una acción ejecutada automáticamente a partir de lo que sugirió la IA**:

1. **No se revierte ningún rol**, porque el escalamiento no llegó a concretarse — el motor ya lo bloqueó.
2. **Se fuerza el cambio de contraseña** de la credencial que tuvo intentos fallidos antes del éxito (`fn_resetear_password`), como medida preventiva estándar ante un patrón de varios intentos fallidos, aunque el cuarto haya sido legítimo.
3. **Se amplía el nivel de log** únicamente en una ventana de investigación acotada (`log_statement = all` por un período corto) si se necesitara confirmar qué leyó exactamente `app_web` durante el incidente — no se deja en `all` de forma permanente, porque eso expondría valores de columnas sensibles en el log de forma continua (ver Parte B, punto 4).
4. **No se bloquea ningún origen de red**, porque todo el tráfico fue `127.0.0.1` (el propio entorno de desarrollo) — en un caso real con origen externo, esa sería la primera medida.
