# Spec: refactorización top_categorias_dia

## 1. Contexto

Tablas afectadas: `detalle_pedido`, `producto`, `categoria`, `pedido`
(lectura únicamente, no se modifican). Volumen en `copia_trabajo`: ~400
pedidos/día en el rango poblado por `carga_masiva.sql` (200.000+ pedidos en
total). La consulta la ejecuta el panel de administración "muchas veces por
minuto" (dato del enunciado del TP).

## 2. Reglas de negocio (confirmadas con: enunciado del TP, punto 5.1)

- No hay una dependencia funcional nueva involucrada: esto no es una
  refactorización de esquema, es una desnormalización de una consulta de
  reporte ya existente.
- Regla de negocio: el panel necesita, en tiempo real, el top 5 de
  categorías por monto vendido en el día.

Evidencia en los datos (consulta original, con `EXPLAIN ANALYZE`):

```sql
EXPLAIN ANALYZE
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE ped.fecha = '2025-01-01'  -- sustituye CURRENT_DATE, ver nota abajo
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;
```

Resultado obtenido: **Execution Time: 1301.956 ms**. Nodo dominante: `Nested
Loop` (pedido → detalle_pedido), con `Index Scan` sobre `detalle_pedido`
ejecutado 400 veces (`loops=400`), uno por cada pedido del día.

> Nota: `CURRENT_DATE` no tenía volumen representativo en `copia_trabajo`
> (la carga masiva pobló fechas históricas, no la fecha real del sistema —
> solo 5 pedidos matcheaban). Se sustituyó por `'2025-01-01'` para medir un
> escenario con volumen realista (~400 pedidos), documentado en
> `tp_desnormalizacion_top_categorias.sql`.

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

- [x] Motivo medido con `EXPLAIN ANALYZE` (1301.956 ms, ver
      `capturas mariano/explain_antes.txt` o `Parte2-Mariano-Capturas.docx`)
- [x] Un único dueño del dato: solo `REFRESH MATERIALIZED VIEW
      CONCURRENTLY` escribe la vista, ningún trigger
- [x] Consulta de conciliación entregada y ejecutada (0 filas de diferencia)
- [x] Documentado en `tp_desnormalizacion_top_categorias.sql` y reversible
      con `DROP MATERIALIZED VIEW`
- [x] Consulta optimizada medida: 1.393 ms (ver `explain_despues.txt`)

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
