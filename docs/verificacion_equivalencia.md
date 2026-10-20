# Verificación de equivalencia — Parte D (Unidad 5)

## 1. Script

`sql/usuario_anon.sql` construye `usuario_anon` a partir de `usuario` (nombre de usuario y email anonimizados de forma determinista vía `md5`; nombre completo reemplazado por un rótulo genérico; `rol`, `activo` y `fecha_alta` preservados sin cambios, ya que no son datos identificables por sí solos).

## 2. Consultas de agregación (cantidad de usuarios por rol y por mes de alta)

**Sobre `usuario_anon` (anonimizada):**

| rol | mes_alta | total_usuarios |
|---|---|---|
| rol_app_escritura | 2026-08-01 | 1 |
| rol_app_lectura | 2026-08-01 | 1 |
| rol_reportes | 2026-09-01 | 1 |
| rol_soporte | 2026-09-01 | 1 |
| rol_soporte | 2026-10-01 | 1 |

**Sobre `usuario` (real):**

| rol | mes_alta | total_usuarios |
|---|---|---|
| rol_app_escritura | 2026-08-01 | 1 |
| rol_app_lectura | 2026-08-01 | 1 |
| rol_reportes | 2026-09-01 | 1 |
| rol_soporte | 2026-09-01 | 1 |
| rol_soporte | 2026-10-01 | 1 |

## 3. Verificación de equivalencia total

```sql
(SELECT rol, date_trunc('month', fecha_alta)::date, COUNT(*) FROM usuario_anon GROUP BY 1,2)
EXCEPT
(SELECT rol, date_trunc('month', fecha_alta)::date, COUNT(*) FROM usuario GROUP BY 1,2);
```

**Resultado: 0 filas.** Los resultados agregados coinciden exactamente — mismos conteos, mismos agrupamientos por rol y por mes de alta. La anonimización no distorsiona lo que la base tiene para decir en conjunto.

## 4. Qué no debería salir nunca hacia un asistente de IA sin pasar por este proceso

`nombre_usuario`, `nombre_completo` y `email` de la tabla `usuario` identifican directamente a una persona y no deberían compartirse en texto plano con un asistente de IA, ni siquiera en un entorno de prueba — es exactamente el hábito que esta parte practica. `password_hash` nunca debería salir hacia ningún destino externo a la base bajo ninguna circunstancia, anonimizado o no: aun siendo un hash, es un secreto de autenticación y su filtración facilita ataques de fuerza bruta offline. Los campos `rol`, `activo` y `fecha_alta` no identifican por sí solos a una persona y pueden compartirse sin anonimizar cuando el análisis los necesita en conjunto (como en este caso), siempre que no se combinen con las columnas identificables de arriba.
