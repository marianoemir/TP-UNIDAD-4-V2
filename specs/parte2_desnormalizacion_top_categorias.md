# Spec: refactorización top_categorias_dia

## 1. Contexto

Tablas afectadas: `detalle_pedido`, `producto`, `categoria`, `pedido`
(lectura únicamente, no se modifican). Volumen en `copia_trabajo`: 200.006
pedidos en total; para el día de la medición hay 406 pedidos (405 vigentes,
811 detalles vigentes, 5 categorías), ver nota más abajo. La consulta la ejecuta el panel de administración "muchas veces por
minuto" (dato del enunciado del TP).

## 2. Reglas de negocio (confirmadas con: enunciado del TP, punto 5.1)

- No hay una dependencia funcional nueva involucrada: esto no es una
  refactorización de esquema, es una desnormalización de una consulta de
  reporte ya existente.
- Regla de negocio: el panel necesita, en tiempo real, el top 5 de
  categorías por monto vendido en el día.

Evidencia en los datos (consulta original, con `EXPLAIN ANALYZE`):

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE ped.fecha = CURRENT_DATE
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;
```

Resultado obtenido (tercera corrida, caché caliente): **Execution Time:
6.546 ms**, 4464 buffers. Nodo dominante: `Nested Loop`, con `Index Scan` sobre
`detalle_pedido` ejecutado 405 veces (`loops=405`, uno por pedido del día) y
sobre `producto_pkey` 811 veces (`loops=811`, uno por detalle).

> Nota: la carga masiva pobló solo fechas históricas, así que `CURRENT_DATE`
> no tenía volumen. En `copia_trabajo` (base descartable) se reasignaron a
> `CURRENT_DATE` los 400 pedidos del 2025-10-09
> (`UPDATE pedido SET fecha = CURRENT_DATE WHERE fecha = '2025-10-09'`) y se
> corrió `ANALYZE pedido`. Así la consulta del enunciado se mide tal cual,
> sin sustituir la fecha. Solo es reproducible el mismo día del `UPDATE`.
> Documentado en `tp_desnormalizacion_top_categorias.sql`.

## 3. Diagnóstico

No aplica cálculo de claves candidatas (no es una descomposición de
esquema). El "diagnóstico" acá es de rendimiento: el costo está en unir 4
tablas y recorrer el detalle de cada pedido del día fila por fila para
agregar por categoría, en una consulta que se ejecuta con mucha frecuencia.

## 4. Esquema objetivo

Vista materializada `mv_ventas_categoria_dia`, agregada por categoría y
fecha, con índice único para permitir `REFRESH CONCURRENTLY`. DDL completo
en `tp_desnormalizacion_top_categorias.sql`, punto 5.2(c).

## 5. Plan de migración

No aplica el patrón expandir-migrar-verificar-contraer (eso es para
reestructurar tablas transaccionales ya en uso). Acá el "plan" es más simple
porque no se reemplaza ninguna tabla existente, solo se agrega una
estructura de lectura nueva:

1. Crear `mv_ventas_categoria_dia` + índice único (`CREATE MATERIALIZED
   VIEW ... WITH DATA`).
2. Medir la consulta optimizada contra la vista.
3. Verificar con el script de conciliación que el dato coincide con la
   fuente de verdad.
4. Documentar el mecanismo de refresco (manual/programado) como el único
   dueño del dato.

Reversible sin pérdida: `DROP MATERIALIZED VIEW mv_ventas_categoria_dia;` —
las tablas fuente (`pedido`, `detalle_pedido`, `producto`, `categoria`)
nunca se tocan.

## 6. Criterios de aceptación

- [x] Motivo medido con `EXPLAIN ANALYZE` (6.546 ms, 4464 buffers,
      ver `capturas/explain_antes.txt`)
- [x] Un único dueño del dato: solo `REFRESH MATERIALIZED VIEW
      CONCURRENTLY` escribe la vista, ningún trigger
- [x] Consulta de conciliación entregada y ejecutada (0 filas de diferencia; con
      prueba de detección dentro de `BEGIN ... ROLLBACK`, que devolvió 1 fila)
- [x] Documentado en `tp_desnormalizacion_top_categorias.sql` y reversible
      con `DROP MATERIALIZED VIEW`
- [x] Consulta optimizada medida: 0.106 ms, 13 buffers (~62x en tiempo, ~340x en
      buffers; ver `capturas/explain_despues.txt`)

## 7. Plan de reversión

`DROP MATERIALIZED VIEW IF EXISTS mv_ventas_categoria_dia;` — no hay pérdida
de información porque la vista es 100% derivada de las tablas fuente, que
permanecen intactas. Si se revierte después de escribir nuevos pedidos, el
único efecto es que el panel vuelve a leer directo de las 4 tablas (más
lento, pero correcto) hasta que se decida otra estrategia.

## 8. Riesgos

- Ventana de inconsistencia: la vista queda desactualizada hasta el próximo
  `REFRESH`. Mitigado documentando la frecuencia esperada de refresco y
  comunicándolo como una limitación conocida del reporte (no es un dato
  operativo crítico como el stock).
- Si en el futuro se agrega un trigger que también escriba sobre la misma
  información derivada, se rompe el requisito de "único dueño del dato" —
  cualquier cambio futuro sobre este reporte debe pasar por esta misma spec,
  no agregar un mecanismo paralelo.
