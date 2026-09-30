-- ============================================================
-- TP Unidad 4 — Parte 2: Desnormalización controlada
-- "Top 5 categorías por monto vendido en el día" (panel de administración)
-- Autor: Mariano Chirino
-- Corre sobre: copia_trabajo (carga_masiva.sql + indices_semana3.sql ya aplicados)
-- Protocolo aplicado: ver protocolo_seguridad.md, Pasos 3, 4 y 7.
-- Evidencia: capturas mariano/explain_antes.txt y explain_despues.txt
-- ============================================================


-- ============================================================
-- Preparación del escenario (simula un día con volumen)
-- ============================================================
-- carga_masiva.sql pobló solo fechas históricas: con CURRENT_DATE quedaban
-- unos pocos pedidos (los del seed de data.sql), un volumen no
-- representativo del escenario del enunciado ("a medida que la base crece,
-- la consulta demanda un tiempo de respuesta notorio").
-- En copia_trabajo (base descartable) se reasignaron a CURRENT_DATE los 400
-- pedidos del 2025-10-09. Así el día de hoy queda con 406 pedidos (405
-- vigentes, 811 detalles vigentes, 5 categorías) y la consulta del
-- enunciado se mide TAL CUAL, con CURRENT_DATE, sin sustituir fechas.
-- Nota: la medición solo es reproducible el mismo día en que se hace el
-- UPDATE (CURRENT_DATE cambia cada día).

UPDATE pedido SET fecha = CURRENT_DATE WHERE fecha = '2025-10-09';
ANALYZE pedido;


-- ============================================================
-- 5.2 (a) — BASELINE: consulta original (4 tablas, sin desnormalizar)
-- ============================================================
-- Ejecutada 3 veces seguidas; se reporta la tercera (caché caliente:
-- todos los bloques salen de shared buffers, sin lecturas de disco).
-- Plan completo en capturas mariano/explain_antes.txt

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

-- Resultado medido:
--   Execution Time: 6.546 ms   |   Buffers: shared hit=4464
--   Nodo dominante: Nested Loop. Del join (5.003 ms), 4.723 ms son del
--   Nested Loop, cuyo costo está en los Index Scan repetidos fila por
--   fila: detalle_pedido con loops=405 (uno por pedido del día) y
--   producto_pkey con loops=811 (uno por detalle). Entre ambos suman
--   ~4450 de los 4464 buffers leídos.


-- ============================================================
-- 5.2 (b) — Elección del patrón: VISTA MATERIALIZADA
-- ============================================================
-- Se descarta columna precalculada + trigger y se elige vista
-- materializada, cumpliendo los 4 requisitos de desnormalización
-- controlada (protocolo_seguridad.md, Paso 7):
--
-- 1. Motivo medido: EXPLAIN ANALYZE de 5.2(a). El costo lo domina el
--    Nested Loop, que repite 405 + 811 búsquedas por índice y crece con
--    la cantidad de pedidos del día (4464 buffers leídos para devolver
--    5 filas).
--
-- 2. Único dueño del dato: un solo REFRESH MATERIALIZED VIEW es el único
--    mecanismo que escribe mv_ventas_categoria_dia. Ningún trigger ni
--    proceso adicional la modifica.
--
-- 3. Consulta de conciliación: ver 5.2(e).
--
-- 4. Documentado y reversible: revertir es un DROP MATERIALIZED VIEW; la
--    fuente de verdad normalizada (pedido, detalle_pedido, producto,
--    categoria) permanece intacta, sin pérdida de información.
--
-- Por qué vista materializada y no columna + trigger:
-- - Es un reporte AGREGADO (SUM + GROUP BY + ORDER BY + LIMIT), no un
--   valor por fila. Un trigger tendría que recalcular el agregado en cada
--   INSERT/UPDATE de detalle_pedido, mucho más caro que un refresco
--   periódico.
-- - El panel lo consulta "muchas veces por minuto" (lectura muy frecuente)
--   y tolera una ventana chica de desactualización: no es un dato crítico
--   transaccional como el stock.
-- - Ya existe un precedente en el proyecto (mv_facturacion_categoria_mes)
--   con el mismo mecanismo (índice único + REFRESH CONCURRENTLY), solo que
--   agrupado por mes en vez de por día.
--
-- Relación lectura/escritura: el panel lee el reporte muchas veces por
-- minuto, mientras que detalle_pedido se escribe con la frecuencia normal
-- de altas de pedidos, un orden de magnitud menor. El costo de mantener
-- la vista al día (un REFRESH) se paga muchas menos veces que el ahorro
-- por cada lectura que evita el join completo.


-- ============================================================
-- 5.2 (c) — Implementación: estructura desnormalizada + sincronización
-- ============================================================
-- Cambio estructural (CREATE MATERIALIZED VIEW): en copia_trabajo, que es
-- descartable y se recrea desde plantilla_food_store, no se requirió
-- respaldo previo (protocolo_seguridad.md, Paso 3).

DROP MATERIALIZED VIEW IF EXISTS mv_ventas_categoria_dia;

CREATE MATERIALIZED VIEW mv_ventas_categoria_dia AS
SELECT
    c.id        AS categoria_id,
    c.nombre    AS categoria,
    ped.fecha   AS fecha,
    SUM(dp.subtotal)        AS total_vendido,
    COUNT(DISTINCT ped.id)  AS cantidad_pedidos
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.id, c.nombre, ped.fecha
WITH DATA;

-- Índice único: requisito de Postgres para refrescar con CONCURRENTLY
-- (las lecturas siguen viendo la versión anterior mientras se recalcula
-- la nueva, sin bloquear el panel que la consulta).
CREATE UNIQUE INDEX idx_mv_ventas_categoria_dia_pk
ON mv_ventas_categoria_dia (categoria_id, fecha);

ANALYZE mv_ventas_categoria_dia;

-- Mecanismo de sincronización (único dueño del dato — requisito 2).
-- Es la única sentencia que actualiza la vista. Se ejecuta bajo demanda o
-- de forma programada (por ejemplo con pg_cron si el entorno de
-- despliegue lo permite; este proyecto no tiene esa infraestructura):
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_dia;
-- Medido: 6 s 800 ms sobre copia_trabajo (~200.000 pedidos, ~400.000
-- detalles).
--
-- Ventana de inconsistencia: los datos son los del último REFRESH. Es una
-- consistencia eventual, aceptable para un panel de reportes (no para un
-- dato operativo crítico como el stock). Cuanto más seguido se ejecute
-- el REFRESH, menor la desactualización y mayor el costo de mantenimiento.


-- ============================================================
-- 5.2 (d) — Consulta que lee de la estructura desnormalizada
-- ============================================================
-- Reemplaza los 3 JOIN de la consulta original por una lectura directa de
-- la vista materializada, ya agregada por categoría y fecha.
-- Ejecutada 3 veces seguidas; se reporta la tercera (caché caliente).
-- Plan completo en capturas mariano/explain_despues.txt

EXPLAIN (ANALYZE, BUFFERS)
SELECT categoria,
       total_vendido
FROM mv_ventas_categoria_dia
WHERE fecha = CURRENT_DATE
ORDER BY total_vendido DESC
LIMIT 5;

-- Comparación medida (mismo día, mismos datos, caché caliente):
--
-- | Momento  | Execution Time | Buffers | Nodo dominante                          |
-- |----------|----------------|---------|-----------------------------------------|
-- | Antes    | 6.546 ms       | 4464    | Nested Loop (Index Scan repetido:       |
-- |          |                |         | detalle_pedido loops=405, producto      |
-- |          |                |         | loops=811)                              |
-- | Después  | 0.106 ms       | 13      | Bitmap Index Scan sobre                 |
-- |          |                |         | idx_mv_ventas_categoria_dia_pk          |
--
-- Mejora: ~62x en tiempo (6.546 / 0.106) y ~340x en bloques leídos
-- (4464 / 13). El recorrido fila por fila de 405 pedidos y 811 detalles se
-- reemplaza por una única lectura de índice sobre datos ya agregados.


-- ============================================================
-- 5.2 (e) — Script de auditoría: detección de desincronización
-- ============================================================
-- Requisito 3 de la desnormalización controlada (consulta de
-- conciliación). Recalcula el total desde la fuente de verdad y lo compara
-- con lo almacenado en la vista. Usa FULL OUTER JOIN para detectar también
-- los pares (categoría, fecha) que existen en un lado y faltan en el otro
-- (por ejemplo, ventas nuevas todavía no reflejadas en la vista).
-- Debe devolver 0 filas.
--
-- Resultado real sobre la base migrada: 0 filas.

SELECT COALESCE(mv.categoria_id, f.categoria_id) AS categoria_id,
       COALESCE(mv.fecha, f.fecha)               AS fecha,
       mv.total_vendido                          AS total_almacenado,
       f.total_vendido                           AS total_recalculado
FROM mv_ventas_categoria_dia mv
FULL OUTER JOIN (
    SELECT c.id AS categoria_id, ped.fecha AS fecha, SUM(dp.subtotal) AS total_vendido
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id = dp.producto_id
    JOIN categoria c ON c.id = pr.categoria_id
    JOIN pedido ped  ON ped.id = dp.pedido_id
    WHERE dp.eliminado = FALSE AND ped.eliminado = FALSE
    GROUP BY c.id, ped.fecha
) f ON f.categoria_id = mv.categoria_id AND f.fecha = mv.fecha
WHERE mv.total_vendido IS DISTINCT FROM f.total_vendido;

-- Prueba de que la auditoría detecta una desincronización (se ejecuta
-- dentro de una transacción que se deshace, no deja datos modificados):
/*
BEGIN;

UPDATE detalle_pedido
SET cantidad = cantidad + 5
WHERE id = (
    SELECT dp.id
    FROM detalle_pedido dp
    JOIN pedido p ON p.id = dp.pedido_id
    WHERE p.fecha = CURRENT_DATE
      AND dp.eliminado = FALSE AND p.eliminado = FALSE
    ORDER BY dp.id
    LIMIT 1
);

-- (acá se corre la consulta de auditoría de arriba)
-- Resultado real: 1 fila -> categoria_id = 1, fecha = hoy,
--   total_almacenado = 2315289.36, total_recalculado = 2367789.36
--   (diferencia de 52500.00, el efecto de las 5 unidades agregadas que la
--   vista todavía no refleja).

ROLLBACK;
-- Después del ROLLBACK la auditoría vuelve a devolver 0 filas.
*/


-- ============================================================
-- Reversión (down): elimina la estructura desnormalizada sin afectar la
-- fuente de verdad normalizada (pedido, detalle_pedido, producto y
-- categoria quedan intactas).
-- ============================================================
-- DROP MATERIALIZED VIEW IF EXISTS mv_ventas_categoria_dia;
