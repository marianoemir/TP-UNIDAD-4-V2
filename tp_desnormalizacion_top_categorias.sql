-- ============================================================
-- TP Unidad 4 — Parte 2: Desnormalización controlada
-- "Top 5 categorías por monto vendido en el día" (panel de administración)
-- Autor: Mariano
-- Corre sobre: copia_trabajo (con carga_masiva.sql ya ejecutado)
-- Protocolo aplicado: ver protocolo_seguridad.md, Pasos 3, 4 y 7.
-- ============================================================


-- ============================================================
-- 5.2 (a) — BASELINE: consulta original (4 tablas, sin desnormalizar)
-- ============================================================
-- Consulta tal como aparece en el enunciado (5.1). Se corrió con
-- EXPLAIN ANALYZE sobre copia_trabajo (post carga_masiva.sql, ~400
-- pedidos/día distribuidos parejo en el rango cargado).
--
-- Aclaración metodológica: el enunciado usa `ped.fecha = CURRENT_DATE`,
-- pero carga_masiva.sql pobló fechas históricas (no la fecha de hoy del
-- servidor), donde CURRENT_DATE solo matcheaba 5 pedidos — un volumen no
-- representativo del escenario que describe el enunciado ("a medida que
-- la base crece, la consulta demanda un tiempo de respuesta notorio").
-- Se sustituyó CURRENT_DATE por '2025-01-01' (una fecha del rango
-- poblado, con ~400 pedidos) para medir un caso representativo. El
-- resultado completo del EXPLAIN ANALYZE con ambas fechas está en
-- Parte2-Mariano-Capturas.docx (o capturas mariano/explain_antes.txt).
--
-- EXPLAIN ANALYZE
-- SELECT c.nombre AS categoria,
--        SUM(dp.subtotal) AS total_vendido
-- FROM detalle_pedido dp
-- JOIN producto pr ON pr.id = dp.producto_id
-- JOIN categoria c ON c.id = pr.categoria_id
-- JOIN pedido ped ON ped.id = dp.pedido_id
-- WHERE ped.fecha = '2025-01-01'
--   AND dp.eliminado = FALSE
--   AND ped.eliminado = FALSE
-- GROUP BY c.nombre
-- ORDER BY total_vendido DESC
-- LIMIT 5;
--
-- Resultado medido (ver Parte2-Mariano-Capturas.docx (o capturas mariano/explain_antes.txt)):
--   Execution Time: 1301.956 ms
--   Nodo dominante: Nested Loop (pedido -> detalle_pedido), con
--   Index Scan sobre detalle_pedido ejecutado 400 veces (loops=400),
--   uno por cada pedido del día — ese acceso repetitivo fila por fila,
--   más varios bloques leídos de disco (Buffers: ... read=126), es lo
--   que explica el salto de 14.7 ms (con 5 pedidos) a 1301.9 ms
--   (con 400 pedidos).


-- ============================================================
-- 5.2 (b) — Elección del patrón: VISTA MATERIALIZADA
-- ============================================================
-- Se descarta columna precalculada + trigger y se elige vista
-- materializada, cumpliendo los 4 requisitos de desnormalización
-- controlada (protocolo_seguridad.md, Paso 7):
--
-- 1. Motivo medido: EXPLAIN ANALYZE de 5.2(a) — 1301.956 ms, con el
--    Nested Loop sobre detalle_pedido como nodo dominante.
--
-- 2. Único dueño del dato: un solo REFRESH MATERIALIZED VIEW
--    (ejecutado manualmente o programado) es el único mecanismo que
--    escribe mv_ventas_categoria_dia. Ningún trigger ni proceso
--    adicional la modifica.
--
-- 3. Consulta de conciliación: ver 5.2(e) más abajo.
--
-- 4. Documentado y reversible: este archivo documenta el patrón
--    elegido y el motivo; revertir es un DROP MATERIALIZED VIEW (la
--    fuente de verdad normalizada — pedido/detalle_pedido/producto/
--    categoria — permanece intacta, sin pérdida de información).
--
-- Por qué vista materializada y no columna + trigger:
-- - Es un reporte AGREGADO (SUM + GROUP BY + ORDER BY + LIMIT), no un
--   valor por fila. Un trigger tendría que recalcular el top-5
--   completo en cada INSERT/UPDATE de detalle_pedido — mucho más caro
--   que un refresco periódico.
-- - El panel lo consulta "muchas veces por minuto" (lectura muy
--   frecuente) y tolera una ventana chica de desactualización — no es
--   un dato crítico transaccional como el stock.
-- - Ya existe un precedente en el proyecto (mv_facturacion_categoria_mes,
--   en objects.sql) con el mismo mecanismo (índice único + REFRESH
--   CONCURRENTLY), solo que agrupado por mes en vez de por día.


-- ============================================================
-- 5.2 (c) — Implementación: estructura desnormalizada + sincronización
-- ============================================================
-- Cambio estructural (CREATE MATERIALIZED VIEW): sacar respaldo antes
-- de correr esto en copia_trabajo, según protocolo_seguridad.md Paso 3:
--   pg_dump copia_trabajo > respaldos/copia_trabajo_antes_mv_ventas_categoria_dia.sql

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

-- Índice único: requisito de Postgres para poder refrescar con CONCURRENTLY
-- (permite que las lecturas sigan viendo la versión anterior mientras se
-- recalcula la nueva, sin bloquear el panel que la consulta).
CREATE UNIQUE INDEX idx_mv_ventas_categoria_dia_pk
ON mv_ventas_categoria_dia (categoria_id, fecha);

-- Mecanismo de sincronización (único dueño del dato — requisito 2):
-- se refresca de forma periódica o bajo demanda con esta única sentencia.
-- En este proyecto (sin infraestructura de cron/pg_cron), el refresco se
-- documenta como manual/bajo demanda antes de cada lectura del panel, o
-- programable con pg_cron si el entorno de despliegue lo permite:
--
--   REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_categoria_dia;
--
-- Ventana de inconsistencia: los datos de mv_ventas_categoria_dia están
-- actualizados "a la fecha del último REFRESH". Es una consistencia
-- eventual, aceptable para un panel de reportes (no para un dato
-- operativo crítico como el stock).


-- ============================================================
-- 5.2 (d) — Consulta que lee de la estructura desnormalizada
-- ============================================================
-- Reemplaza los 3 JOIN de la consulta original por una lectura directa
-- de la vista materializada, ya agregada por categoría y fecha.

EXPLAIN ANALYZE
SELECT categoria,
       total_vendido
FROM mv_ventas_categoria_dia
WHERE fecha = '2025-01-01'
ORDER BY total_vendido DESC
LIMIT 5;

-- Tabla comparativa (medición real, ver Parte2-Mariano-Capturas.docx (o capturas mariano/explain_antes.txt) y
-- Parte2-Mariano-Capturas.docx (o capturas mariano/explain_despues.txt)):
--
-- | Momento  | Execution Time | Nodo dominante                          |
-- |----------|-----------------|------------------------------------------|
-- | Antes    | 1301.956 ms     | Nested Loop (pedido -> detalle_pedido,   |
-- |          |                 | Index Scan con loops=400)                |
-- | Después  | 1.393 ms        | Bitmap Index Scan sobre                  |
-- |          |                 | idx_mv_ventas_categoria_dia_pk           |
--
-- Mejora: ~935x más rápido (de 1301.956 ms a 1.393 ms). El JOIN de 4
-- tablas con recorrido fila por fila de 400 pedidos se reemplaza por
-- una única lectura de índice sobre datos ya agregados.


-- ============================================================
-- 5.2 (e) — Script de auditoría: detección de desincronización
-- ============================================================
-- Requisito 3 de la desnormalización controlada (consulta de
-- conciliación). Recalcula el total real desde la fuente de verdad y
-- lo compara contra lo almacenado en la vista materializada. Debe
-- devolver 0 filas — un resultado no vacío indica que la vista no se
-- refrescó después de cambios en los datos base (deuda técnica
-- silenciosa: no es necesariamente un error de programación, puede ser
-- simplemente que faltó correr el REFRESH).
--
-- Resultado real obtenido: 0 filas — la vista está sincronizada con la
-- fuente de verdad (esperable, ya que no se modificaron datos después
-- de crear mv_ventas_categoria_dia).

SELECT
    mv.categoria_id,
    mv.fecha,
    mv.total_vendido        AS total_almacenado,
    real.total_vendido_real AS total_recalculado,
    mv.total_vendido - real.total_vendido_real AS diferencia
FROM mv_ventas_categoria_dia mv
JOIN (
    SELECT
        c.id      AS categoria_id,
        ped.fecha AS fecha,
        SUM(dp.subtotal) AS total_vendido_real
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id = dp.producto_id
    JOIN categoria c ON c.id = pr.categoria_id
    JOIN pedido ped ON ped.id = dp.pedido_id
    WHERE dp.eliminado = FALSE
      AND ped.eliminado = FALSE
    GROUP BY c.id, ped.fecha
) AS real
  ON real.categoria_id = mv.categoria_id
 AND real.fecha = mv.fecha
WHERE mv.total_vendido <> real.total_vendido_real;

-- Antigüedad del último refresco (complementario, no reemplaza la
-- conciliación de arriba): en versiones de Postgres sin last_refresh
-- nativo para vistas materializadas, se recomienda una tabla de
-- bitácora propia que registre el timestamp de cada REFRESH ejecutado,
-- por ejemplo:
--
-- CREATE TABLE bitacora_refresh_mv (
--     mv_nombre    VARCHAR(100) NOT NULL,
--     refrescado_en TIMESTAMPTZ NOT NULL DEFAULT now()
-- );
-- -- y agregar, después de cada REFRESH:
-- INSERT INTO bitacora_refresh_mv (mv_nombre) VALUES ('mv_ventas_categoria_dia');


-- ============================================================
-- Reversión (down): elimina la estructura desnormalizada sin afectar
-- la fuente de verdad normalizada (pedido, detalle_pedido, producto,
-- categoria quedan intactas).
-- ============================================================
-- DROP MATERIALIZED VIEW IF EXISTS mv_ventas_categoria_dia;
