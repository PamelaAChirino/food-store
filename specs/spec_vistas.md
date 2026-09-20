# spec: vistas_food_store

## 1. Objetivo
Crear vistas lógicas para simplificar consultas complejas, reutilizar lógica de negocio y restringir el acceso a datos sensibles.

## 2. Vistas a implementar
- `v_productos_vigentes`: Muestra los productos activos junto con su categoría.
- `v_pedidos_usuario`: Facilita la consulta de pedidos uniendo los datos básicos del cliente.
- `v_usuario_seguro`: Vista de seguridad que expone los datos del usuario omitiendo información sensible.