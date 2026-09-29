# Spec: refactorización control_lote_almacen (FNBC)

## 1. Contexto

Tabla afectada: `control_lote_almacen(lote_id, deposito_id, responsable_control_id)`.
Extensión del dominio de Food Store para la distribución mayorista. Un lote de gran volumen puede fraccionarse y controlarse desde más de un depósito, requiriendo un responsable de control por cada depósito interviniente.
Volumen inicial: Instancia de ejemplo con 3 filas.

## 2. Reglas de negocio (confirmadas con: enunciado del TP, punto 4.1)

- R1: "Para un lote y un depósito interviniente dados, el responsable de control queda unívocamente determinado."
  → Notación formal: `{LoteID, DepositoID} -> ResponsableControlID`
- R2: "Cada responsable de control pertenece, como dato maestro de la dotación de personal, a un único depósito: no controla lotes coordinados desde depósitos distintos."
  → Notación formal: `ResponsableControlID -> DepositoID`

Evidencia / Verificación de la relación en los datos:

```sql
-- Verificar que cada responsable pertenece a un único depósito:
SELECT responsable_control_id, COUNT(DISTINCT deposito_id) AS cantidad_depositos
FROM control_lote_almacen
GROUP BY responsable_control_id
HAVING COUNT(DISTINCT deposito_id) > 1;
-- Resultado esperado: 0 filas.
```

## 3. Diagnóstico

### Notación formal de atributos
- `L`: LoteID (`lote_id`)
- `D`: DepositoID (`deposito_id`)
- `R`: ResponsableControlID (`responsable_control_id`)

### Clausuras de atributos
1. `{L, D}+`:
   - `{L, D}^(0) = {L, D}`
   - Aplicando R1 (`{L, D} -> R`): `{L, D}^(1) = {L, D, R}`
   - Genera todos los atributos de la relación.

2. `{L, R}+`:
   - `{L, R}^(0) = {L, R}`
   - Aplicando R2 (`R -> D`): `{L, R}^(1) = {L, R, D}`
   - Genera todos los atributos de la relación.

3. `{R}+`:
   - `{R}^(0) = {R}`
   - Aplicando R2 (`R -> D`): `{R}^(1) = {R, D}` (No genera `{L}`, no es superclave).

### Conjunto completo de claves candidatas
- Claves candidatas: `{{LoteID, DepositoID}, {LoteID, ResponsableControlID}}`
- Atributos primos: `LoteID`, `DepositoID`, `ResponsableControlID` (todos los atributos son primos).
- Atributos no primos: Ninguno (`∅`).

### Evaluación de FNBC
- La relación **NO cumple la Forma Normal de Boyce-Codd (FNBC)**.
- **Dependencia funcional violatoria:** `ResponsableControlID -> DepositoID` (R2).
- **Justificación:** El determinante `ResponsableControlID` NO es superclave, ya que `{ResponsableControlID}+ = {ResponsableControlID, DepositoID} ≠ {LoteID, DepositoID, ResponsableControlID}`.

---

### Anomalías detectadas sobre la instancia de ejemplo

1. **Anomalía de Inserción:**
   No es posible registrar un nuevo responsable de control y su depósito asignado (ej. responsable `803` en depósito `32`) sin asignarle simultáneamente un lote (`lote_id`), ya que `lote_id` forma parte de la clave primaria original y no admite valores nulos (`NULL`).

2. **Anomalía de Borrado:**
   Si se eliminan las inspecciones de los lotes `501` y `502` (`(501, 30, 801)` y `(502, 30, 801)`), se borran todas las referencias al responsable `801`, perdiendo de la base de datos el dato maestro de que el responsable `801` pertenece al depósito `30`.

3. **Anomalía de Actualización:**
   Si el responsable `801` cambia del depósito `30` al `32`, se deben actualizar múltiples filas en la tabla. Si una actualización falla o queda incompleta, la base de datos quedará en un estado inconsistente donde `801` figurará asignado a dos depósitos distintos.

---

## 4. Esquema objetivo (Descomposición sin pérdida)

Aplicando el algoritmo de descomposición sin pérdida sobre la dependencia violatoria `R -> D`:

1. **Tabla de Maestro de Personal / Responsable:**
   - Nombre: `responsable_deposito`
   - Atributos: `(responsable_control_id, deposito_id)`
   - PK: `responsable_control_id`
   - FK: `deposito_id REFERENCES deposito(id)`

2. **Tabla de Asignación / Control Lote:**
   - Nombre: `control_lote`
   - Atributos: `(lote_id, responsable_control_id)`
   - PK: `(lote_id, responsable_control_id)`
   - FK: `lote_id REFERENCES lote(id)`, `responsable_control_id REFERENCES responsable_deposito(responsable_control_id)`

3. **Vista de compatibilidad:**
   - Nombre: `v_control_lote_almacen` (o la misma `control_lote_almacen` tras renombrar la tabla original) que realiza un `NATURAL JOIN` o `JOIN` por `responsable_control_id` para reconstruir exactamente la relación original.

## 5. Plan de migración (expandir–migrar–verificar–contraer)

1. Crear tablas maestras soporte `lote` y `deposito` (si no existen) y la tabla original `control_lote_almacen` con la instancia de ejemplo (3 filas).
2. Crear las nuevas tablas resultantes `responsable_deposito` y `control_lote` (`up.sql`).
3. Migrar los datos desde `control_lote_almacen` hacia las dos tablas nuevas sin destruir la tabla original.
4. Crear la vista de compatibilidad.
5. Verificar la integridad y equivalencia exacta utilizando conteos y **los dos `EXCEPT`** en ambas direcciones.
6. Probar el script de reversión (`down.sql`).

## 6. Criterios de aceptación

- [ ] `COUNT(*)` coincide entre la relación original y la reconstruida por la vista.
- [ ] Los dos `EXCEPT` (original `EXCEPT` vista y vista `EXCEPT` original) devuelven 0 filas.
- [ ] La unión entre las tablas descompuestas es sin pérdida (el atributo común `responsable_control_id` es clave primaria/superclave en `responsable_deposito`).
- [ ] `down.sql` ejecuta sin errores y restaura la base a su estado inicial.

## 7. Plan de reversión

Contenido de `down.sql`:
Elimina la vista de compatibilidad y las tablas descompuestas `control_lote` y `responsable_deposito`, manteniendo intactas las tablas originales.

## 8. Riesgos

- Perder restricciones de FK si las tablas maestras `lote` y `deposito` no están correctamente creadas antes de la descomposición.