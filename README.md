# Food Store — TP: FNBC y Desnormalización Controlada (Base de Datos II)

Proyecto integrador de un sistema de venta de comida, implementado en
PostgreSQL. Este repositorio contiene el Trabajo Práctico de la **Unidad 4**
— *Forma Normal de Boyce-Codd y Desnormalización Controlada en Food Store* —
resuelto en grupo de 3 integrantes con OpenCode y Kiro como herramientas de
IA.

## Grupo

Grupo 10

**Integrantes:**
- Mariano Chirino
- Andrés Fabre
- Facundo Quiroga

## Formato de entrega

`.zip` de este repositorio completo (confirmado por la cátedra), con la
misma estructura de carpetas usada en la entrega de la Unidad 3.

## Requisitos previos (heredados de entregas anteriores)

Este TP no vuelve a crear el modelo de datos ni a poblar la base desde cero:
parte de `plantilla_food_store`/`copia_trabajo` tal como quedaron al cierre
de la Unidad 3, y agrega dos entregables independientes sobre esa base.

**Nota:** estos archivos están **sin fusionar**, cada uno correspondiente a
una entrega semanal distinta (criterio confirmado por la cátedra para este
TP — la versión fusionada de `schema.sql`/`objects.sql` fue un pedido
específico del Parcial 1, no de la línea de TPs semanales).

| Archivo | Contenido |
|---|---|
| `archivos necesarios para la BD/schema.sql` | Tipos ENUM, tablas, constraints y los 3 índices originales |
| `archivos necesarios para la BD/objects.sql` | Las 4 vistas base, función de cálculo, triggers, `sp_crear_pedido` |
| `archivos necesarios para la BD/data.sql` | Datos de prueba chicos |
| `archivos necesarios para la BD/carga_masiva.sql` | Población masiva (~200.000 pedidos, ~400.000 detalles) |
| `archivos necesarios para la BD/indices_semana3.sql` | 2 índices de una entrega previa a la U3 |
| `archivos necesarios para la BD/indices.sql` | 1 índice entregable de la U3 (búsqueda de productos por nombre) |
| `archivos necesarios para la BD/views.sql` | Vista `v_usuario_seguro`, entregable de la U3 |
| `archivos necesarios para la BD/materializadas.sql` | Vista materializada `mv_facturacion_categoria_mes`, entregable de la U3 |
| `archivos necesarios para la BD/queries.sql` | Historias de usuario resueltas + consultas analíticas |
| `archivos necesarios para la BD/transacciones.sql` | Transacciones de referencia de entregas anteriores |

**Orden de ejecución (heredado, no forma parte de esta entrega):**
`schema.sql → objects.sql → data.sql` (en `plantilla_food_store`) →
`carga_masiva.sql → indices_semana3.sql → indices.sql → views.sql →
materializadas.sql` (en `copia_trabajo`, creada con `TEMPLATE
plantilla_food_store`)

## Entregables de este TP

| Archivo | Qué contiene |
|---|---|
| `tp_fnbc_control_lote.sql` | Parte 1 — Esquema `control_lote_almacen` (con `lote` y `deposito` como tablas maestras nuevas), análisis de dependencias funcionales y claves candidatas, demostración de violación de FNBC, descomposición sin pérdida (`up.sql`/`down.sql`), vista de compatibilidad, migración de datos verificada |
| `tp_desnormalizacion_top_categorias.sql` | Parte 2 — Vista materializada `mv_ventas_categoria_dia` para el reporte "top 5 categorías por venta del día", índice único, consulta optimizada, script de auditoría |
| `specs/` | Especificaciones de Kiro, una por parte, redactadas antes de generar el SQL con OpenCode |
| `duia/` | Declaración de Uso de IA, un archivo por integrante |
| `protocolo_seguridad.md` | Protocolo obligatorio: copia de trabajo, transacción reversible, respaldo previo, patrón expandir-migrar-verificar-contraer, los 4 requisitos de desnormalización controlada |
| `division_tareas_tp4.md` | Reparto de tareas y dependencias entre integrantes |
| `informe_tp4.md` (o `.pdf`/`.docx`) | Informe breve con dependencias funcionales, claves candidatas, demostración de FNBC, justificación de unión sin pérdida, capturas de `EXPLAIN ANALYZE` antes/después y justificación del patrón de desnormalización |

### Quién hizo qué

| Parte | Integrante | Contenido |
|---|---|---|
| Parte 1 — Análisis FNBC | Facundo Quiroga | Dependencias funcionales, clausuras, claves candidatas, demostración formal de violación de FNBC, anomalías clásicas |
| Parte 1 — Esquema, descomposición y migración | Andrés Fabre | Esquema inicial (`lote`, `deposito`, `control_lote_almacen`), descomposición sin pérdida, vista de compatibilidad, migración de datos verificada con los dos `EXCEPT` |
| Parte 2 — Desnormalización controlada | Mariano Chirino | Baseline medido (1301.956 ms), vista materializada `mv_ventas_categoria_dia`, consulta optimizada (1.393 ms — ~935x más rápida), script de auditoría (0 filas de diferencia) |

El detalle completo de cada parte (spec usada, qué generó la IA, qué se
aceptó o descartó y por qué) está en `informe_tp4.md` y en el `duia/` de
cada integrante.

## Cómo reproducir las pruebas de este trabajo

```bash
# 1. Crear la plantilla con el esquema y el seed chico (si no existe ya)
createdb plantilla_food_store
psql -d plantilla_food_store -f "archivos necesarios para la BD/schema.sql"
psql -d plantilla_food_store -f "archivos necesarios para la BD/objects.sql"
psql -d plantilla_food_store -f "archivos necesarios para la BD/data.sql"

# 2. Crear una copia de trabajo descartable a partir de la plantilla
createdb -T plantilla_food_store copia_trabajo

# 3. Aplicar la carga masiva (necesaria para medir la Parte 2 con volumen real)
psql -d copia_trabajo -f "archivos necesarios para la BD/carga_masiva.sql"

# 4. Aplicar los objetos nuevos de este TP
psql -d plantilla_food_store -f "tp_fnbc_control_lote.sql"   # esquema chico, sin volumen
psql -d copia_trabajo -f "tp_desnormalizacion_top_categorias.sql"  # necesita volumen
```

Antes de aplicar cualquier cambio sobre la base se sigue el flujo de
`protocolo_seguridad.md`: nunca se trabaja sobre `plantilla_food_store` con
cambios destructivos; siempre se prueba primero dentro de
`BEGIN...ROLLBACK`; se saca respaldo antes de cualquier cambio estructural;
toda migración de tablas en uso sigue el patrón expandir-migrar-verificar-
contraer con `up.sql`/`down.sql` probado; y toda vista se verifica con
conteo + los dos `EXCEPT` antes de darla por válida.

## Criterio de aceptación

Ninguna propuesta de la IA se aplicó "porque lo dijo la IA": cada decisión
se tomó después de medir con `EXPLAIN ANALYZE` (Parte 2) o de calcular
formalmente clausuras y claves candidatas (Parte 1), documentando el
razonamiento completo en `duia/` y en las specs de `specs/`.
