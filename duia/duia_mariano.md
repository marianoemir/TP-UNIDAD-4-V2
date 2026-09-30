# Declaración de Uso de IA (DUIA) — Mariano Chirino

**Integrante:** Mariano Chirino (Grupo 10)
**Materia:** Base de Datos II (UTN) — Unidad 4
**Proyecto Integrador:** Food Store
**Alcance:** versión final de la Parte 1 (FNBC) y de la Parte 2 (desnormalización controlada)
**Herramienta principal:** Claude (chat), además de OpenCode/Kiro en las primeras versiones del grupo

> Esta declaración cubre únicamente lo que hice y usé yo. Andrés Fabre y Facundo Quiroga
> declaran su propio uso de IA en `duia_andres.md` y `duia_facundo.md`.

---

## Registro de interacciones y decisiones con IA

### Parte 2 — Desnormalización controlada

| Herramienta | Para qué se usó | Se aceptó / se descartó — por qué |
|---|---|---|
| Claude | Medir la consulta del punto 5.1 con `EXPLAIN ANALYZE` y detectar el nodo dominante | Con `CURRENT_DATE` la carga masiva dejaba muy pocos pedidos (la carga solo pobló fechas históricas). **Primera versión (descartada):** se sustituyó la fecha por `'2025-01-01'` y se midió 1301.956 ms. Esa medición fue en caché fría y con solo 2 categorías, así que no era comparable con la del "después". **Versión final:** se reasignaron a `CURRENT_DATE` los 400 pedidos del 2025-10-09 (`UPDATE` + `ANALYZE`), quedando 406 pedidos hoy (405 vigentes, 811 detalles, 5 categorías), y se midió la consulta del enunciado tal cual, en la tercera corrida (caché caliente): **6.546 ms**, 4464 buffers, `Nested Loop` dominante. |
| Claude | Proponer el patrón (vista materializada vs. columna + trigger) | Se aceptó **vista materializada** `mv_ventas_categoria_dia`: es un reporte agregado, de lectura muy frecuente y tolerante a una ventana chica de desactualización; un trigger tendría que recalcular el agregado en cada escritura de `detalle_pedido`. Mismo mecanismo que el precedente `mv_facturacion_categoria_mes` (índice único + `REFRESH CONCURRENTLY`). |
| Claude | Generar el DDL, la consulta optimizada y la auditoría | El DDL se verificó contra las columnas reales de `schema.sql`. Se corrigió que la vista incluyera `categoria_id` como clave canónica de agrupación. Consulta sobre la vista: **0.106 ms**, 13 buffers (~62x en tiempo, ~340x en buffers). |
| Claude | Auditoría de desincronización | **Error detectado y corregido:** la primera auditoría usaba `JOIN` interno y daba un falso negativo (no detectaba pares categoría-fecha ausentes en la vista). Se reemplazó por `FULL OUTER JOIN ... IS DISTINCT FROM`. Se probó dentro de `BEGIN ... ROLLBACK`: tras un `UPDATE` de `detalle_pedido` devolvió 1 fila (diferencia 52500.00) y tras el `ROLLBACK` volvió a 0 filas. |

### Parte 1 — FNBC sobre `control_lote_almacen`

| Herramienta | Para qué se usó | Se aceptó / se descartó — por qué |
|---|---|---|
| Claude | Primera versión del script de la Parte 1 | **Descartada:** inventaba un esquema propio (tabla `almacenero`, etc.) que no correspondía al enunciado. Se rehízo con el esquema y la instancia EXACTOS del punto 4.1 (lotes 501-503, depósitos 30-31, responsables 801-802). |
| Claude | Dependencias funcionales, clausuras, claves candidatas y verificación de FNBC | Se aceptó y **se revisó a mano**: F1 `{L,D}->R`, F2 `R->D`; claves candidatas `{L,D}` y `{L,R}`; los tres atributos son primos; viola FNBC por F2 (`{R}+ = {R,D}` no es superclave) pero cumple 3FN. |
| Claude | Descomposición, vista de compatibilidad y verificación | `responsable_deposito` (PK `responsable_control_id`) y `control_lote` (PK `(lote_id, responsable_control_id)`); vista con `NATURAL JOIN`. Verificada con conteo y los dos `EXCEPT` (0 filas cada uno). Se agregó la **limitación** de que la descomposición no preserva `{L,D}->R` (contraejemplo ejecutado en `BEGIN ... ROLLBACK`). |

---

## Verificación sobre el motor real

Todo se probó en PostgreSQL 18 con pgAdmin 4: la Parte 2 en `copia_trabajo` y la Parte 1 en `copia_fnbc`, ambas creadas con `TEMPLATE plantilla_food_store`. La plantilla no se tocó.

1. Parte 2: `EXPLAIN (ANALYZE, BUFFERS)` antes (6.546 ms) y después (0.106 ms); auditoría con 0 filas y prueba de detección.
2. Parte 1: script completo ejecutado sin errores; capturas de la tabla original, las dos tablas, la vista, los dos `EXCEPT` y el conteo (3 y 3); anomalía de actualización y limitación de la descomposición probadas con `ROLLBACK`.
3. Bloque "down" de la Parte 1 probado: up → down → up.

Ninguna propuesta de la IA se aceptó sin correrla y verificar el resultado en pgAdmin.

## Resumen de decisiones

| Aspecto | Resultado |
|---|---|
| Patrón elegido (Parte 2) | Vista materializada `mv_ventas_categoria_dia` |
| Motivo medido | 6.546 ms, `Nested Loop` (`loops=405` y `loops=811`), 4464 buffers |
| Mejora | 0.106 ms, 13 buffers — ~62x en tiempo, ~340x en buffers |
| Único dueño del dato | `REFRESH MATERIALIZED VIEW CONCURRENTLY` (ningún trigger) |
| Conciliación | 0 filas entre lo almacenado y lo recalculado |
| Reversible | `DROP MATERIALIZED VIEW` — fuente de verdad intacta |
| Parte 1 | No cumple FNBC por `R -> D`; descomposición sin pérdida verificada con los dos `EXCEPT` |
