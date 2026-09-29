# Food Store — Visión General del Proyecto

## Descripción

Sistema de venta de comida implementado íntegramente en **PostgreSQL**.
Cubre el ciclo completo: categorías → productos → usuarios → pedidos con sus detalles.

## Metodología: dos bases (plantilla + copia de trabajo)

El grupo trabaja con dos bases separadas, creadas y administradas con
**pgAdmin**: `plantilla_food_store` (base limpia, solo `schema.sql` →
`objects.sql` → `data.sql`, nunca recibe `carga_masiva.sql`) y
`copia_trabajo` (creada en pgAdmin con `Create > Database...` eligiendo
`plantilla_food_store` como **Template**; ahí sí se corre `carga_masiva.sql`
y cualquier medición con volumen). Ver el detalle completo en `AGENTS.md`.

## Trabajo Práctico en curso: Unidad 4 (FNBC y Desnormalización)

Se está resolviendo un TP nuevo con dos partes independientes entre sí:
1. Llevar un esquema nuevo (`control_lote_almacen`, más las tablas de apoyo
   `lote` y `deposito` que aún no existen en el proyecto) a Forma Normal de
   Boyce-Codd.
2. Desnormalizar de forma controlada una consulta real sobre las tablas
   existentes (`pedido`, `detalle_pedido`, `producto`, `categoria`) para un
   reporte de "top 5 categorías por venta del día".

Detalle de archivos esperados y en qué base corre cada uno, en `AGENTS.md`
(sección "Trabajo Práctico en curso — Unidad 4").

## Archivos del proyecto (estructura U3, sin fusionar)

**Nota sobre el cambio de criterio:** hubo una versión fusionada de
`schema.sql`/`objects.sql` (con todo consolidado en dos archivos), pero esa
fusión fue un pedido específico del **Parcial 1**, una entrega distinta. Para
el TP4 y los TPs semanales, la cátedra pidió mantener la estructura
**sin fusionar** de la Unidad 3, donde cada entrega deja su propio archivo.
Este repo usa esa estructura U3, no la consolidada.

| Archivo | Contenido |
|---|---|
| `schema.sql` | Tipos ENUM, tablas, constraints y los 3 índices originales (versión U3) |
| `objects.sql` | Las 4 vistas base, función de cálculo, triggers (incluido el de transición de estado) y `sp_crear_pedido` (versión U3, sin `v_usuario_seguro`) |
| `data.sql` | Datos de prueba chicos (categorías, productos, usuarios, pedidos de ejemplo) |
| `carga_masiva.sql` | Script de población masiva: ≥50.000 productos, ≥20.000 usuarios, ≥200.000 pedidos con detalles |
| `indices_semana3.sql` | 2 índices de una entrega previa a la U3 (`idx_pedido_fecha_estado_vigente`, `idx_pedido_usuario_total_estado`) |
| `indices.sql` | 1 índice entregable de la U3 (`idx_producto_nombre_lower_vigente`) |
| `views.sql` | Vista `v_usuario_seguro`, entregable de la U3 |
| `materializadas.sql` | Vista materializada `mv_facturacion_categoria_mes` + su índice único, entregable de la U3 |
| `queries.sql` | Historias de usuario resueltas + consultas analíticas (versión U3) |
| `transacciones.sql` | Escenarios de atomicidad, aislamiento y bloqueo concurrente |

## Tablas del modelo

```
categoria
producto       → FK categoria_id → categoria
usuario
pedido         → FK usuario_id   → usuario
detalle_pedido → FK pedido_id    → pedido
               → FK producto_id  → producto
```

## Tipos ENUM definidos

```sql
CREATE TYPE rol          AS ENUM ('ADMIN','USUARIO');
CREATE TYPE estado_pedido AS ENUM ('PENDIENTE','CONFIRMADO','TERMINADO','CANCELADO');
CREATE TYPE forma_pago   AS ENUM ('TARJETA','TRANSFERENCIA','EFECTIVO');
```

## Orden de ejecución

```
schema.sql → objects.sql → data.sql → carga_masiva.sql (opcional)
  → indices_semana3.sql → indices.sql → views.sql → materializadas.sql
  → queries.sql
```

Cada archivo depende del anterior; ejecutarlos fuera de orden producirá
errores de referencia. `transacciones.sql` es independiente y corre sobre la
base ya poblada, en cualquier momento después de `data.sql`. `queries.sql` no
se ejecuta de una sola vez: es un banco de consultas sueltas.

## Vistas disponibles

| Vista | Descripción | Archivo |
|---|---|---|
| `v_categorias_vigentes` | Categorías con `eliminado = FALSE` | `objects.sql` |
| `v_productos_vigentes` | Productos y categorías activos, con JOIN entre ambas tablas | `objects.sql` |
| `v_pedidos_resumen` | Pedidos vigentes con nombre completo del usuario | `objects.sql` |
| `v_pedido_detalle` | Líneas de detalle vigentes con nombre del producto | `objects.sql` |
| `v_usuario_seguro` | Usuarios sin la columna `contrasena` | `views.sql` |

## Vista materializada

| Vista materializada | Descripción | Archivo |
|---|---|---|
| `mv_facturacion_categoria_mes` | Facturación agregada por categoría y mes. Requiere `REFRESH MATERIALIZED VIEW CONCURRENTLY` para actualizarse — no se actualiza sola. Tiene índice único `(categoria_id, mes)` que habilita el refresh concurrente. | `materializadas.sql` |
