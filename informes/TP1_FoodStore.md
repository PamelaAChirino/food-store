# TP1 — Del dominio al esquema: modelo ER, modelo relacional, normalización y DDL

**Materia:** Base de Datos I
**Proyecto integrador:** Food Store (sistema de gestión de pedidos de un negocio de comidas)
**Integrantes:** Pamela Chirino, Mayra Mule, Lucas Agüero

---

## 1. Modelo entidad-relación

**Notación:** Chen. Subrayado = Clave Primaria (PK). (UK) = Clave Única.
Línea gruesa = participación total. Línea simple = participación parcial.

Entidades: `CATEGORIA`, `PRODUCTO`, `CLIENTE`, `PEDIDO`, y la relación N:M
`contiene` entre `PRODUCTO` y `PEDIDO` (con atributos propios `cantidad` y
`precio_unitario`).

*(Diagrama ER completo: ver archivo de imagen del proyecto — no se
transcribe acá, esto documenta el contenido textual que lo acompaña.)*

### Cardinalidades y participaciones

- **Relación `agrupa` (CATEGORIA – PRODUCTO):** Cardinalidad 1:N.
  Participación **parcial** en CATEGORIA (R1: puede existir una categoría
  recién creada sin productos) y **total** en PRODUCTO (todo producto
  pertenece obligatoriamente a una categoría).
- **Relación `realiza` (CLIENTE – PEDIDO):** Cardinalidad 1:N.
  Participación **parcial** en CLIENTE (R2: un cliente puede no haber hecho
  ningún pedido) y **total** en PEDIDO.
- **Relación `contiene` (PRODUCTO – PEDIDO):** Cardinalidad N:M.
  Participación **parcial** en PRODUCTO (R3: un producto puede existir en
  catálogo sin haberse vendido nunca) y **total** en PEDIDO.

### Diccionario de entidades y atributos

| Entidad | Atributo | Tipo conceptual | Restricción / Rol |
|---|---|---|---|
| CATEGORIA | id_categoria | Numérico | Clave Primaria (PK) |
| CATEGORIA | nombre | Texto | Clave Única (UK) |
| CATEGORIA | descripcion | Texto | — |
| CATEGORIA | activo | Booleano | — |
| PRODUCTO | id_producto | Numérico | Clave Primaria (PK) |
| PRODUCTO | nombre | Texto | — |
| PRODUCTO | descripcion | Texto | — |
| PRODUCTO | precio | Numérico | — |
| PRODUCTO | stock | Numérico | — |
| PRODUCTO | activo | Booleano | — |
| CLIENTE | id_cliente | Numérico | Clave Primaria (PK) |
| CLIENTE | nombre | Texto | — |
| CLIENTE | apellido | Texto | — |
| CLIENTE | telefono | Texto | — |
| CLIENTE | email | Texto | Clave Única (UK) |
| PEDIDO | id_pedido | Numérico | Clave Primaria (PK) |
| PEDIDO | fecha | Fecha/Hora | — |
| PEDIDO | forma_pago | Texto | — |
| Relación `contiene` | cantidad | Numérico | Atributo de relación M:N |
| Relación `contiene` | precio_unitario | Numérico | Atributo de relación M:N |

### Preguntas guía

**¿Por qué la relación entre producto y pedido no puede resolverse como una
relación binaria simple 1:N? ¿Qué información se perdería?**

No puede resolverse como 1:N porque la naturaleza del negocio es muchos a
muchos (M:N): un mismo pedido incluye varios productos distintos, y un mismo
producto (ej. "Pizza Muzzarella") se vende en muchos pedidos a lo largo del
tiempo. Si se fuerza una relación 1:N:
- Poniendo la clave de pedido en producto, un producto solo podría venderse
  una única vez en toda la historia.
- Poniendo la clave de producto en pedido, el cliente solo podría comprar un
  único artículo por ticket. Además, se perdería el lugar donde almacenar
  `cantidad` y `precio_unitario`; sin una tabla intermedia no se podría
  congelar el precio histórico (regla R4), y cualquier aumento de precios
  alteraría el total de pedidos ya facturados.

**¿Qué entidad tiene participación parcial en la relación con categoría, y
cuál tiene participación total? ¿Qué pasaría si invirtieras esa lectura?**

CATEGORIA tiene participación parcial (R1: puede existir una categoría
recién creada sin productos asociados). PRODUCTO tiene participación total
(todo producto registrado debe pertenecer obligatoriamente a una
categoría). En cuanto a la relación M:N con PEDIDO (`contiene`), un
producto del catálogo tiene participación parcial: puede estar dado de alta
sin haberse vendido nunca todavía.

**¿Alguno de tus atributos podría descomponerse en partes más simples
(por ejemplo, un nombre completo en nombre y apellido)? Justificá tu
decisión.**

Sí — en CLIENTE, el nombre se descompuso en `nombre` y `apellido`. Se
decidió separarlo porque facilita operaciones futuras (ordenar
alfabéticamente por apellido, búsquedas más precisas, personalizar correos
tipo "Hola, Lucas"). Dejarlo como un único atributo compuesto dificultaría
extraer solo el apellido o el nombre de pila sin recurrir a funciones
complejas de manipulación de cadenas.

---

## 2. Derivación al modelo relacional

```
categoria (id_categoria, nombre, descripcion, activo)
cliente   (id_cliente, nombre, apellido, telefono, email)
producto  (id_producto, nombre, descripcion, precio, stock, activo, id_categoria -> categoria)
pedido    (id_pedido, fecha, forma_pago, id_cliente -> cliente)
pedido_producto (id_pedido -> pedido, id_producto -> producto, cantidad, precio_unitario)
```

Para la tabla asociativa `pedido_producto`, se optó por una **clave primaria
compuesta** (`id_pedido`, `id_producto`) en vez de una clave sustituta.

**Justificación:** un mismo producto no debe repetirse en renglones
separados dentro del mismo ticket de compra — si el cliente pide varias
unidades de un mismo artículo, la cantidad se acumula en el atributo
`cantidad`. La clave compuesta garantiza esa unicidad a nivel de motor
relacional. Una clave sustituta (por ejemplo `id_detalle`) permitiría por
error insertar líneas duplicadas para el mismo producto en un pedido,
exigiendo una restricción `UNIQUE` adicional para lograr lo mismo que la
clave compuesta ya garantiza de forma nativa.

### Preguntas guía

**¿Qué pasaría con la integridad de tus datos si la tabla intermedia no
incluyera ambas claves foráneas como NOT NULL?**

Se generarían registros "huérfanos": si `id_pedido` pudiera ser nulo,
habría productos descontados del stock y "vendidos" sin saber a qué pedido
ni a qué cliente pertenecen; si `id_producto` pudiera ser nulo, se sabría
que se cobró un monto sin registro de qué se entregó. En ambos casos se
rompería cualquier reporte de ventas o facturación.

**Si el pedido pudiera existir sin ningún producto asociado (un "pedido
recién iniciado"), ¿cambia esto la participación definida en la Parte 1?**

Sí. En el diagrama, la participación de PEDIDO hacia la relación M:N está
marcada como total (todo pedido registrado debe tener al menos un
producto). Si se permitiera un pedido temporalmente vacío (tipo "carrito"
recién abierto), esa participación pasaría a ser **parcial**: sería válido
insertar en `pedido` y que pase un tiempo indefinido sin filas asociadas en
`pedido_producto`.

---

## 3. Normalización hasta 3FN/BCNF

Planilla de partida (una fila por línea de producto vendido dentro de un
pedido), con nombre de cliente y nombre de producto como identificadores
únicos dentro de esta muestra (en la base real se usan claves numéricas).

### 1. Clave primaria (claves candidatas)

No alcanza con el N.º de pedido solo (un pedido tiene varias filas si lleva
varios productos), ni con el Producto solo (el mismo producto aparece en
distintos pedidos).

**Clave primaria:** (N.º pedido, Producto).

### 2. Dependencias funcionales

- **DF1:** N.º pedido → Fecha, Cliente, Forma de pago (todo pedido ocurre
  en una fecha, pertenece a un cliente y se paga de una forma).
- **DF2:** Producto → Categoría (todo producto pertenece a una única
  categoría).
- **DF3:** (N.º pedido, Producto) → Precio unitario, Cantidad, Subtotal (la
  cantidad vendida y el precio en ese momento dependen de qué producto se
  pidió en qué pedido).
- **DF4:** Precio unitario, Cantidad → Subtotal (el subtotal es el
  resultado matemático de multiplicar estos dos atributos).

### 3. Primera Forma Normal (1FN)

La planilla original ya cumple 1FN: cada celda tiene un único valor
(sin listas separadas por comas) y ya se definió la clave primaria
compuesta.

**Tabla en 1FN:** PLANILLA (N.º pedido, Producto, Fecha, Cliente,
Categoría, Precio unitario, Cantidad, Subtotal, Forma de pago).

### 4. Segunda Forma Normal (2FN)

Se rompe por DF1 y DF2: la fecha y el cliente dependen solo del N.º de
pedido, y la categoría depende solo del Producto — ambas son dependencias
parciales de la clave compuesta. Se separan en tablas propias:

- **PEDIDO** (N.º pedido, Fecha, Cliente, Forma de pago)
- **PRODUCTO** (Producto, Categoría)
- **PEDIDO_DETALLE** (N.º pedido, Producto, Precio unitario, Cantidad, Subtotal)

### 5. Tercera Forma Normal (3FN)

PEDIDO y PRODUCTO ya están en 3FN. En PEDIDO_DETALLE queda una dependencia
transitiva (DF4): el Subtotal depende de Precio unitario y Cantidad, que no
son clave. Se elimina el atributo calculable.

**Tabla corregida:** PEDIDO_DETALLE (N.º pedido, Producto, Precio unitario,
Cantidad).

### 6. Forma Normal de Boyce-Codd (BCNF)

Para cada dependencia funcional X → Y, el determinante X debe ser clave
candidata:
- En PEDIDO, el único determinante es N.º pedido (PK). ✓
- En PRODUCTO, el único determinante es Producto (PK). ✓
- En PEDIDO_DETALLE, el determinante es (N.º pedido, Producto) (PK). ✓

**Conclusión:** no se encuentra ninguna excepción — las tablas ya están en
BCNF, todos los determinantes son las claves primarias de sus respectivas
relaciones.

### 7. Conjunto final de tablas normalizadas

- **pedido** (nro_pedido, fecha, cliente, forma_pago)
- **producto** (producto, categoria)
- **pedido_detalle** (nro_pedido → pedido, producto → producto,
  precio_unitario, cantidad)

### Preguntas de integración

**Comparación con las tablas de la Parte 2. ¿Qué te dice la diferencia
entre modelar desde un enunciado y normalizar desde datos históricos?**

La tabla `pedido` de acá corresponde a la entidad PEDIDO del ER; `producto`
a la entidad PRODUCTO; `pedido_detalle` a la tabla intermedia
`pedido_producto`. Faltan las entidades CLIENTE y CATEGORIA como tablas
separadas, y muchos atributos del ER que la planilla nunca registró
(`email`, `telefono`, `apellido`, `id_cliente`, `descripcion`, `activo`,
`stock`).

Normalizar desde una planilla histórica limita estrictamente a los datos
que ya están visibles: si la planilla nunca registró el teléfono del
cliente, la normalización jamás va a crear ese campo ni va a detectar que
"Cliente" debería ser una entidad separada, porque no hay datos que
demuestren esa dependencia funcional. Modelar desde el enunciado
(top-down) es más completo porque captura la realidad del negocio y sus
necesidades futuras, sin sesgarse por cómo se anotaban las cosas en el
pasado.

**¿Conviene almacenar el `subtotal`, o recalcularlo siempre al vuelo?
¿Viola alguna forma normal?**

Conviene recalcularlo al vuelo (con una consulta o vista) para evitar
redundancia y evitar que, si se actualiza la cantidad, alguien olvide
actualizar el subtotal. Almacenarlo físicamente **viola la 3FN**, porque
crea una dependencia transitiva matemática (precio_unitario, cantidad →
subtotal). A veces se hace igual por rendimiento (desnormalización
intencional), pero estrictamente hablando rompe las reglas de
normalización.

---

## 4. DDL en PostgreSQL

Ver `schema.sql` en la raíz del repositorio — es la pieza que concilia los
resultados de las Partes 2 y 3 de este documento, ejecutable de punta a
punta en PostgreSQL 16.
