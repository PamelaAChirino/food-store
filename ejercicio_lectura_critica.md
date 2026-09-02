# Ejercicio de lectura crítica

Análisis de los dos scripts del enunciado (esquema genérico de cátedra), antes
de ejecutar nada, siguiendo el protocolo de la Parte 0.

---

## Script 1

```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE;
```

**Qué haría realmente:** no tiene cláusula `WHERE`. Un `UPDATE` sin `WHERE`
afecta **todas las filas de la tabla**, sin excepción. Este script desactiva
absolutamente todas las funciones — incluidas las que están vigentes o
programadas a futuro — no solo las "retiradas de cartel".

**Por qué no coincide con la consigna:** la consigna pide dar de baja un
subconjunto (las retiradas de cartel), pero el script no filtra nada; el
comentario ("Generado para...") describe una intención que el código no
implementa. Es exactamente el tipo de discrepancia entre "lo que dice hacer"
y "lo que hace" que el protocolo de la cátedra obliga a detectar leyendo el
diff antes de aplicar, no confiando en el comentario ni en el nombre del
archivo.

**Versión corregida** (asumiendo que "retirada de cartel" se identifica por
una fecha de fin ya pasada, y evitando reescribir filas que ya estaban
inactivas):

```sql
UPDATE funcion
SET activa = FALSE
WHERE fecha_fin < CURRENT_DATE
  AND activa = TRUE;
```

Si la tabla del proyecto real usa otro campo para marcar "retirada de cartel"
(por ejemplo un `estado`), el `WHERE` se ajusta a ese campo — el punto no
negociable es que exista un filtro que corresponda a la regla de negocio
enunciada.

---

## Script 2

```sql
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

**Qué haría realmente:** `NOT IN` con una subconsulta que puede devolver
`NULL` es una trampa clásica de SQL. Si **una sola fila** de `producto` tiene
`categoria_id` en `NULL`, la subconsulta devuelve un conjunto que incluye
`NULL`, y la comparación `id NOT IN (1, 2, NULL)` se evalúa como
`id <> 1 AND id <> 2 AND id <> NULL`. Como cualquier comparación contra `NULL`
da `UNKNOWN` (no `TRUE` ni `FALSE`), el `AND` completo nunca puede dar `TRUE`
para ninguna fila. Resultado: el `DELETE` no borra **ninguna** fila, sin
ningún error — se comprobó en el motor:

```sql
-- cat_test(id) = 1,2,3 ; prod_test(categoria_id) = 1, NULL
SELECT id FROM cat_test WHERE id NOT IN (SELECT categoria_id FROM prod_test);
-- 0 rows   ← nada, aunque 2 y 3 sí están huérfanas

SELECT c.id FROM cat_test c
  WHERE NOT EXISTS (SELECT 1 FROM prod_test p WHERE p.categoria_id = c.id);
-- 2, 3     ← correcto
```

**Por qué no coincide con la consigna:** el script parece funcionar (no tira
error) pero silenciosamente no hace nada apenas exista un producto sin
categoría asignada. Es peor que un error visible: alguien puede creer que la
limpieza se hizo y no se hizo. En el schema real del proyecto `id_categoria`
es `NOT NULL`, así que este caso puntual no ocurriría — pero el patrón
`NOT IN` con subconsulta es peligroso en general y no depende de que el
alumno recuerde revisar la nulabilidad cada vez.

**Versión corregida** (usa `NOT EXISTS`, que maneja `NULL` correctamente sin
depender de que la columna sea `NOT NULL`):

```sql
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1 FROM producto p WHERE p.categoria_id = c.id
);
```

---

## DUIA de esta parte

Ver `DUIA.md`, sección "Parte 3".
