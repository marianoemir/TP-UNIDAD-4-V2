# Declaración de Uso de IA (DUIA) — Parte 2

**Integrante:** Mariano Chirino
**Rol / Asignación:** Parte 2 — Desnormalización controlada (top 5 categorías por venta del día)
**Materia:** Base de Datos II (UTN) — Unidad 4
**Proyecto Integrador:** Food Store

---

## Registro de Interacciones y Decisiones con IA

| Herramienta | Para qué se usó | Spec / Prompt (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| Claude | Medir la consulta original del punto 5.1 con `EXPLAIN ANALYZE` sobre `copia_trabajo` y detectar el nodo que dominaba el costo | Se corrió la consulta tal cual la da el enunciado, con `CURRENT_DATE` | **Se detectó un problema en el enunciado antes que en el índice**: `CURRENT_DATE` solo matcheaba 5 pedidos en `copia_trabajo` (la carga masiva pobló fechas históricas), dando un plan liviano (14.7 ms) no representativo. Se identificó primero, con `SELECT fecha, COUNT(*) FROM pedido GROUP BY fecha ORDER BY COUNT(*) DESC`, una fecha con volumen real (~400 pedidos/día) y se sustituyó `CURRENT_DATE` por `'2025-01-01'` para la medición. Se documentó la sustitución en vez de ocultarla. |
| Claude | Proponer el patrón de desnormalización (vista materializada vs. columna + trigger) a partir del `EXPLAIN ANALYZE` medido | Se le pasó el plan completo (1301.956 ms, `Nested Loop` con `loops=400` sobre `detalle_pedido`) y se pidió justificar la elección contra los 4 requisitos del protocolo de la cátedra | **Se aceptó vista materializada**, con el argumento de que es un reporte agregado (SUM + GROUP BY + LIMIT) consultado con alta frecuencia y tolerancia a una ventana chica de desactualización — un trigger recalcularía el top-5 completo en cada escritura de `detalle_pedido`, mucho más caro. Se contrastó con el precedente ya existente en el proyecto (`mv_facturacion_categoria_mes`), que usa el mismo mecanismo (índice único + `REFRESH CONCURRENTLY`). |
| Claude | Generar el DDL de `mv_ventas_categoria_dia`, su índice único, la consulta optimizada y el script de auditoría | Se pidió que la vista agrupe por categoría y fecha (no por mes, a diferencia de `mv_facturacion_categoria_mes`) y que respete el mismo filtro de `eliminado = FALSE` que la consulta original (sin el filtro de `estado` que sí tiene la vista existente) | Se aceptó el DDL propuesto, verificándolo contra las columnas reales de `schema.sql` antes de ejecutarlo. Se corrigió manualmente al ejecutar: la primera versión no incluía `categoria_id` como columna propia (solo `categoria` por nombre), se agregó para tener una clave de agrupación canónica y no depender de agrupar por texto. |

---

## Verificación sobre el motor real

Todo lo generado se probó en `copia_trabajo` (nunca en `plantilla_food_store`),
siguiendo el protocolo del grupo:

1. `EXPLAIN ANALYZE` de la consulta original → **1301.956 ms**, `Nested Loop`
   como nodo dominante.
2. `CREATE MATERIALIZED VIEW mv_ventas_categoria_dia` + índice único →
   ejecutado sin errores (confirmado por el mensaje `CREATE INDEX` en pgAdmin).
3. `EXPLAIN ANALYZE` de la consulta contra la vista → **1.393 ms**,
   `Bitmap Index Scan` sobre el índice único.
4. Script de auditoría (comparación vista vs. recálculo desde la fuente de
   verdad) → **0 filas**, confirmando sincronización.

Nada de esto se aceptó "porque lo dijo la IA": cada paso se corrió en pgAdmin
sobre datos reales y se verificó el resultado antes de darlo por válido.

## Resumen de decisiones

| Aspecto | Resultado |
|---|---|
| Patrón elegido | Vista materializada (`mv_ventas_categoria_dia`) |
| Motivo medido | 1301.956 ms, `Nested Loop` con `loops=400` |
| Mejora | 1.393 ms — **~935x más rápido** |
| Único dueño del dato | `REFRESH MATERIALIZED VIEW CONCURRENTLY` (ningún trigger) |
| Conciliación | 0 filas de diferencia entre lo almacenado y lo recalculado |
| Reversible | `DROP MATERIALIZED VIEW` — fuente de verdad intacta |

Detalle completo de la spec en `specs/parte2_desnormalizacion_top_categorias.md`
y del script en `tp_desnormalizacion_top_categorias.sql`.
