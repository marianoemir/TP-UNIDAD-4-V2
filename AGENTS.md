# Food Store — Instrucciones para Agentes

## Stack Tecnológico

| Componente | Tecnología / Versión | Propósito |
|---|---|---|
| Motor BD | PostgreSQL 16+ | Base de datos relacional |
| Lenguaje | SQL / PL/pgSQL | Definición de esquema, vistas, funciones y procedimientos |

## Metodología de trabajo: Plantilla y Copia de Trabajo

El grupo (3 integrantes) trabaja siempre con **dos bases de datos separadas**
en el mismo servidor Postgres local, creadas y administradas con **pgAdmin**
(editor gráfico incluido en el instalador oficial de PostgreSQL para
Windows). Nunca se corren `schema.sql`/`objects.sql`/`data.sql` ni
`carga_masiva.sql` sobre una única base mezclada.

1. **`plantilla_food_store`** — la base "limpia" y de referencia.
   - Se crea desde cero (`Create > Database...` en pgAdmin).
   - Se corren, en orden, únicamente: `schema.sql` → `objects.sql` → `data.sql`.
   - Queda con los datos de prueba chicos del seed (pocos registros).
   - **Nunca** se le corre `carga_masiva.sql` ni ningún script destructivo o
     de volumen. Es la base que cada integrante puede volver a copiar si algo
     sale mal en su copia de trabajo.

2. **`copia_trabajo`** — la base sobre la que se experimenta y se mide.
   - Se crea en pgAdmin con `Create > Database...`, y en la pestaña
     **"Template"** del diálogo se elige `plantilla_food_store` como base
     (esto ejecuta por debajo un `CREATE DATABASE copia_trabajo TEMPLATE
     plantilla_food_store` de Postgres — pgAdmin es solo la interfaz gráfica
     de ese comando).
   - Recién ahí se corre `carga_masiva.sql` (población masiva) y cualquier
     script que altere estructura (`ALTER TABLE`), pruebe transacciones
     (`transacciones.sql`) o mida rendimiento con `EXPLAIN ANALYZE`.
   - Si una copia de trabajo queda en mal estado, se borra y se vuelve a
     crear desde `plantilla_food_store` (no hay que rehacer el seed a mano).

**Regla dura:** ningún integrante corre `carga_masiva.sql` ni un `ALTER
TABLE`/`DROP` experimental sobre `plantilla_food_store`. Esa base debe poder
usarse en cualquier momento como origen limpio de una nueva `copia_trabajo`.

## Protocolo de seguridad (obligatorio, ver `protocolo_seguridad.md`)

Antes de correr cualquier script (propio o generado por IA) sobre
`copia_trabajo`: especificar primero en una spec dentro de `specs/`
(plantilla en `specs/_plantilla_spec.md`), probar dentro de
`BEGIN...ROLLBACK`, sacar respaldo si el cambio es estructural
(`ALTER`/`DROP`/`CREATE INDEX`/`CREATE VIEW`/`CREATE MATERIALIZED
VIEW`/`CREATE TRIGGER`/migración de datos), correr `ANALYZE` después de un
índice nuevo, y verificar cualquier vista nueva con conteo de filas + los
**dos** `EXCEPT` (en ambos sentidos, no uno solo). Toda migración que
reestructure tablas ya en uso sigue el patrón expandir-migrar-verificar-
contraer con su `up.sql` y su `down.sql` probado. Toda redundancia
introducida a propósito debe cumplir los cuatro requisitos de
desnormalización controlada (motivo medido, único dueño del dato, consulta
de conciliación, documentado y reversible). El detalle completo está en
`protocolo_seguridad.md`, en la raíz del repo.

## Estructura de carpetas

**Cambio de criterio confirmado por la cátedra para el TP4:** la fusión de
`schema.sql`/`objects.sql` en un solo archivo consolidado fue un pedido
específico del **Parcial 1** (una entrega distinta). Para los TPs semanales
—incluido este TP4— el profesor pidió usar la estructura **sin fusionar**
de la Unidad 3, que es más prolija porque cada entrega deja su propio
archivo, sin mezclar el trabajo de varias semanas en uno solo.

Todos los archivos `.sql` heredados están dentro de
`archivos necesarios para la BD/`, **sin fusionar**, cada uno correspondiente
a una entrega semanal distinta:

```
archivos necesarios para la BD/
├── schema.sql            (tipos, tablas, constraints, 3 índices originales)
├── objects.sql           (4 vistas base, función de cálculo, triggers, sp_crear_pedido)
├── data.sql              Datos de prueba chicos
├── carga_masiva.sql      Población masiva (≥50.000 productos, ≥20.000 usuarios, ≥200.000 pedidos)
├── indices_semana3.sql   2 índices agregados en una entrega previa a la U3
├── queries.sql           Historias de usuario resueltas + consultas analíticas (versión U3)
├── transacciones.sql     Escenarios de atomicidad, aislamiento y bloqueo concurrente
├── indices.sql           1 índice aceptado en la U3 (búsqueda de productos por nombre)
├── views.sql             1 vista nueva de la U3: v_usuario_seguro
└── materializadas.sql    1 vista materializada de la U3: mv_facturacion_categoria_mes
```

**Importante:** `schema.sql` y `objects.sql` de este repo son la versión
**de la U3** (sin los índices/vistas agregados después) — no la versión
consolidada que se usó para el Parcial 1. No traer esa versión fusionada a
este TP ni a ningún TP semanal siguiente.

## Orden de ejecución

```
En plantilla_food_store:
  schema.sql → objects.sql → data.sql

En copia_trabajo (creada con TEMPLATE plantilla_food_store, ver metodología arriba):
  carga_masiva.sql (opcional) → indices_semana3.sql → indices.sql → views.sql
  → materializadas.sql → queries.sql
```

Cada archivo depende del anterior dentro de su base. `transacciones.sql` es
independiente — corre sobre cualquiera de las dos bases ya pobladas
(`plantilla_food_store` para probar concurrencia con pocos datos, o
`copia_trabajo` si se quiere reproducir un escenario con volumen real), en
cualquier momento después de `data.sql`.

## Base de Conocimiento y Steering

- `schema.sql`: Tipos ENUM, tablas, constraints (incluye los 2 CHECK de mail
  y fecha) y los 3 índices originales únicamente (versión U3, sin los
  agregados después).
- `objects.sql`: Las 4 vistas base (sin `v_usuario_seguro`, que vive en
  `views.sql`), la función de cálculo, los 4 triggers (incluido el de
  transición de estado) y `sp_crear_pedido`.
- `data.sql`: Datos de prueba chicos.
- `carga_masiva.sql`: Población masiva, para medir performance con volumen real.
- `indices_semana3.sql`: 2 índices de una entrega previa a la U3
  (`idx_pedido_fecha_estado_vigente`, `idx_pedido_usuario_total_estado`).
- `indices.sql`: 1 índice aceptado en la U3
  (`idx_producto_nombre_lower_vigente`, con `text_pattern_ops`).
- `views.sql`: la vista de seguridad `v_usuario_seguro` (usuario sin
  `contrasena`), entregable de la U3.
- `materializadas.sql`: la vista materializada `mv_facturacion_categoria_mes`
  + su índice único, entregable de la U3.
- `queries.sql`: Historias de usuario resueltas + consultas analíticas
  (versión de la U3).
- `transacciones.sql`: Escenarios de atomicidad, aislamiento y concurrencia.
- `.kiro/steering/project-overview.md`: visión general y orden de ejecución.
- `.kiro/steering/conventions.md`: convenciones + índices y constraints existentes.
- `.kiro/steering/objects-and-patterns.md`: vistas, triggers, `sp_crear_pedido`, patrones.

## Índices existentes (NO recrear, ni duplicar)

**En `schema.sql`:**
- `idx_producto_categoria_id` — `producto(categoria_id)`
- `idx_pedido_usuario_id` — `pedido(usuario_id)`
- `idx_producto_nombre_vigente` — `producto(nombre) WHERE eliminado = FALSE` (parcial)

**En `indices_semana3.sql`:**
- `idx_pedido_fecha_estado_vigente` — `pedido(fecha, estado) WHERE eliminado = FALSE` (parcial)
- `idx_pedido_usuario_total_estado` — `pedido(usuario_id, total) WHERE eliminado = FALSE AND estado IN ('CONFIRMADO','TERMINADO')` (parcial)

**En `indices.sql`:**
- `idx_producto_nombre_lower_vigente` — `producto(lower(nombre) text_pattern_ops) WHERE eliminado = FALSE` (parcial)

Antes de proponer un índice nuevo, verificar contra esta lista (los 6, sin
importar en qué archivo esté cada uno). Un índice que duplica o es
redundante con alguno de estos es candidato directo al descarte por
sobreindexación.

## Vistas y objetos existentes (NO recrear)

**En `objects.sql`:**
- `v_categorias_vigentes`, `v_productos_vigentes`, `v_pedidos_resumen`,
  `v_pedido_detalle` — vistas simples, todas filtran `eliminado = FALSE`.

**En `views.sql`:**
- `v_usuario_seguro` — expone `usuario` sin la columna `contrasena`. Usar
  siempre esta vista quien necesite listar usuarios; nunca hacer
  `SELECT *` directo sobre `usuario` fuera de autenticación.

**En `materializadas.sql`:**
- `mv_facturacion_categoria_mes` — vista MATERIALIZADA de facturación por
  categoría y mes. No se actualiza sola: requiere
  `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;`
  después de cambios relevantes en pedidos.

## Reglas Duras del Proyecto

1. **Nombres de tablas:** singular y español (`categoria`, `producto`, `usuario`, `pedido`, `detalle_pedido`).
2. **Borrado lógico:** nunca `DELETE`. Usar `UPDATE <tabla> SET eliminado = TRUE WHERE id = :id AND eliminado = FALSE`.
3. **Altas de pedidos:** siempre `CALL sp_crear_pedido(...)`.
4. **Triggers automáticos:** no modificar `trg_subtotal`, `trg_total_ins`, `trg_total_upd`, `trg_validar_estado_pedido`.
5. **Vistas vigentes:** usarlas para filtrar registros activos en vez de escribir el filtro a mano.
6. **JOINs y borrado lógico:** el filtro `eliminado = FALSE` debe aplicarse en cada tabla involucrada.
7. **Índices propuestos:** ninguno se aplica sin poder explicar qué nodo del
   plan ataca y por qué se espera que mejore — ni sin verificar primero que
   no duplique uno de los 6 ya existentes.
8. **Vistas de seguridad:** ninguna vista de usuario expuesta debe incluir la
   columna `contrasena` (usar `v_usuario_seguro`).
9. **Datos sensibles:** `usuario.mail` debe respetar el formato validado por
   `chk_usuario_mail_formato`; `pedido.fecha` nunca puede ser futura
   (`fecha <= CURRENT_DATE`).

## Trabajo Práctico en curso — Unidad 4 (FNBC y Desnormalización Controlada)

**Formato de entrega confirmado por la cátedra:** `.zip`, con la misma
estructura de carpetas que se usó en la entrega de la Unidad 3 (no un link a
GitHub). Los archivos nuevos de esta entrega van **sueltos en la raíz** del
repositorio (no en una subcarpeta como `TP4_FNBC_Desnormalizacion/`), junto a
`AGENTS.md`, `protocolo_seguridad.md`, `README.md` y `division_tareas_tp4.md`
— exactamente igual que en la U3, donde `indices.sql`, `views.sql`,
`materializadas.sql` e `informe_mediciones.md` estaban en la raíz.

Las carpetas `specs/` y `duia/` también van en la raíz, con un archivo por
integrante/spec adentro, igual que en la U3.

```
Trabajo-Practico-Unidad-4-/
├── archivos necesarios para la BD/
├── AGENTS.md
├── protocolo_seguridad.md
├── division_tareas_tp4.md
├── README.md
├── tp_fnbc_control_lote.sql              (Parte 1 — Andrés / Facundo)
├── tp_desnormalizacion_top_categorias.sql (Parte 2 — Mariano)
├── informe_tp4.md (o .pdf/.docx al empaquetar)
├── specs/
│   ├── parte1_control_lote.md
│   └── parte2_desnormalizacion_top_categorias.md
├── duia/
│   ├── duia_mariano.md
│   ├── duia_andres.md
│   └── duia_facundo.md
└── Parte2-Mariano-Capturas.docx           (evidencia de EXPLAIN ANALYZE)
```

No modifica `schema.sql`, `objects.sql` ni `data.sql` existentes.

| Archivo (nuevo) | Contenido | Responsable | Corre sobre |
|---|---|---|---|
| `tp_fnbc_control_lote.sql` | Extensión mayorista: tablas `lote`, `deposito` (nuevas, no existían en el proyecto) y `control_lote_almacen`; instancia de ejemplo; tablas descompuestas por FNBC; vista de compatibilidad; migración de datos; `up.sql`/`down.sql` del patrón expandir-migrar-verificar-contraer | Andrés (esquema y descomposición) + Facundo (análisis FNBC) | `plantilla_food_store` (esquema nuevo y chico, no necesita volumen) |
| `tp_desnormalizacion_top_categorias.sql` | Vista materializada `mv_ventas_categoria_dia` para el reporte "top 5 categorías por venta del día"; índice único; mecanismo de sincronización (`REFRESH CONCURRENTLY`); consulta optimizada; script de auditoría — **completo** | Mariano | `copia_trabajo` (necesita volumen real para que el `EXPLAIN ANALYZE` muestre diferencia) |

**Tablas nuevas a crear como prerrequisito de `control_lote_almacen`:**
`lote` y `deposito` no existen todavía en el proyecto. El enunciado las da
por existentes (de forma análoga a como se asumió `sucursal` en un caso
anterior de la cursada), así que hay que crearlas como tablas maestras
mínimas antes de crear `control_lote_almacen`, respetando las convenciones
del proyecto (nombres en singular y español, `id BIGINT GENERATED ALWAYS AS
IDENTITY PRIMARY KEY`).

**Atención con `mv_facturacion_categoria_mes`:** esa vista materializada
existente agrupa por **mes** y filtra `estado = 'CONFIRMADO'`. El reporte de
este TP necesita **el día** (se usó `2025-01-01` como fecha representativa,
ver justificación en `tp_desnormalizacion_top_categorias.sql`) sin filtrar
por estado — no alcanza con reutilizarla tal cual; sirve solo como
referencia de patrón (índice único + `REFRESH CONCURRENTLY`), no como la
solución en sí. La vista nueva de este TP se llama `mv_ventas_categoria_dia`,
sin reemplazar ni tocar `mv_facturacion_categoria_mes`.
