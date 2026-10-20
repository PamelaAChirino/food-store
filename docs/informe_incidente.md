# Informe de Simulacro de Incidente — Parte C (Unidad 5)

## 1. Contexto

Se reprodujo, exclusivamente contra el entorno de desarrollo propio, la secuencia pedida por la consigna: varios intentos fallidos de login contra `fn_autenticar`, un login exitoso, una lectura masiva de la tabla `usuario`, y un intento de escalamiento de privilegios (otorgarle a `app_web` membresía en `admin_datos`). Script: `sql/simulacro_incidente.sql`.

## 2. Qué ocurrió realmente (evidencia directa, no del log)

Consultando `log_autenticacion` después de la secuencia: 3 intentos de `fn_autenticar('mrodrig', ...)` con contraseña incorrecta (`exitoso = f`) seguidos de 1 intento con la contraseña correcta (`exitoso = t`). La lectura de `usuario` devolvió las 5 filas de la tabla (columnas no sensibles, sin `password_hash`, por el permiso a nivel de columna de la Parte A). El intento de `GRANT admin_datos TO app_web` **falló** con `permission denied to grant role "admin_datos"`.

**El escalamiento no tuvo éxito.** El esquema de permisos de la Parte A se comportó como estaba previsto: `app_web` no tiene la opción `ADMIN` sobre `admin_datos`, así que no hay defecto que corregir en ese punto.

**Hallazgo corregido respecto de la versión anterior de este script:** la primera versión incluía un "Escenario 3" donde `admin_datos` actualizaba `cliente` y se documentaba como "modificación autorizada" exitosa. Al verificarlo contra los permisos reales definidos en `roles.sql`, esa operación **falla** (`admin_datos` hereda `rol_soporte` y `rol_reportes`, ambos de solo lectura). El informe original afirmaba un resultado que el propio esquema de permisos no permite — se corrigió eliminando esa afirmación y reemplazando el escenario por la secuencia que realmente pide la consigna.

## 3. Anonimización del log

El fragmento de log de toda la secuencia se anonimizó reemplazando origen de conexión y usuario de sistema operativo por valores sintéticos antes de "entregarlo" a la IA para su reconstrucción (archivo `log_simulacro_anonimizado.txt`), siguiendo el mismo criterio aplicado a `usuario_anon` en la Parte D.

## 4. Reconstrucción pedida a la IA (a partir únicamente del log anonimizado, sin contexto adicional)

> Se observa una sesión que primero limpia una tabla de registro de autenticación, luego invoca cuatro veces una función `fn_autenticar` contra un mismo usuario de prueba con contraseñas no visibles en el log (el texto de la sentencia no revela si cada intento tuvo éxito o fracasó, porque `log_statement` registra la llamada, no su valor de retorno). A continuación la sesión cambia de rol a `app_web` y ejecuta una lectura dirigida de columnas específicas (no `SELECT *`) sobre la tabla `usuario` — una consulta que, por sí sola, no luce anómala: no hay en el log ninguna métrica de cantidad de filas devueltas que permita calificarla de "masiva". Finalmente, todavía como `app_web`, se intenta `GRANT admin_datos TO app_web`, que el motor rechaza con un error de permisos explícito. La secuencia sugiere un intento de escalamiento de privilegios posterior a una fase de prueba de credenciales, bloqueado exitosamente por el control de acceso. No es posible, solo con este log, determinar qué cuenta de aplicación originó la sesión: todas las sentencias figuran bajo el usuario de conexión del sistema, no bajo `app_web`, pese a que la sesión estaba operando como `app_web` al momento del intento de escalamiento.

## 5. Contraste entre la reconstrucción de la IA y lo realmente ejecutado

| Punto | Reconstrucción de la IA | Lo que realmente pasó | Evaluación |
|---|---|---|---|
| Resultado de los 4 intentos de login | No pudo determinarlo — señaló correctamente la limitación | 3 fallidos + 1 exitoso (dato solo disponible en `log_autenticacion`, no en el log de PostgreSQL) | **Acertado al abstenerse de afirmar un resultado que el log no sustenta** — esto es justo lo que se evalúa: no inventó un dato que no tenía. |
| Calificar la lectura de `usuario` como "masiva" | No lo hizo, por falta de evidencia de cantidad de filas en el log | Devolvió las 5 filas de la tabla (la totalidad) | **Omisión razonable**, no un error: el log de sentencias no incluye el conteo de filas devueltas; para confirmarlo hace falta una fuente adicional (por ejemplo, `pg_stat_statements` o logging a nivel de pgaudit). |
| Identidad de quien originó la sesión | Señaló correctamente que no puede determinarse del log, por la ambigüedad de `SET ROLE` | La sesión completa corrió como una única conexión administrativa que hizo `SET ROLE app_web` (limitación ya documentada en `informe_auditoria.md`, punto 3) | **Acertado**; coincide con el hallazgo de auditoría. |
| Resultado del intento de escalamiento | Señaló correctamente que fue bloqueado por el motor | Confirmado: `permission denied to grant role "admin_datos"` | **Acertado**, bien sustentado por el log. |

**Conclusión del contraste:** en este caso la reconstrucción no incluyó afirmaciones no sustentadas por el log — el aspecto a validar críticamente fue, más bien, confirmar que la IA se abstuvo correctamente donde el log no alcanzaba (resultado de los logins, volumen de la lectura), en lugar de completar esos huecos con suposiciones. Esa es la validación humana que se deja documentada acá: se verificó cada afirmación contra la evidencia directa de la base (punto 2) antes de aceptar la reconstrucción como válida.

## 6. Decisión de contención

Dado que el escalamiento fue bloqueado por el propio motor y no se detectó ningún defecto en el esquema de permisos, la decisión del equipo —ante un caso real con este mismo patrón— sería:

1. **No rotar contraseñas de forma preventiva** en este caso puntual, porque el intento de escalamiento fracasó y no hay evidencia de que la cuenta `app_web` esté comprometida más allá de sus credenciales ya conocidas por la propia aplicación.
2. **Sí investigar el origen de la lectura masiva de `usuario`** aunque haya sido técnicamente autorizada: no es normal que la capa web lea la tabla completa de usuarios en una sola consulta; ameritaría revisar el código de la aplicación que generó esa consulta y, si no hay una razón de negocio legítima, **reducir aún más el alcance del permiso de lectura** (por ejemplo, mediante row-level security limitando `app_web` a leer solo su propia fila de contexto, si el caso de uso lo permite).
3. **Subir temporalmente `log_statement` a `'all'`** mientras dure la investigación del origen de la lectura masiva, y volver a `'mod'` una vez cerrada (tal como se hizo para esta misma captura).
4. Esta decisión es del equipo, tomada a partir de la evidencia reunida en los puntos 2 y 5 — no una acción ejecutada automáticamente a partir de lo que sugirió la reconstrucción de la IA.
