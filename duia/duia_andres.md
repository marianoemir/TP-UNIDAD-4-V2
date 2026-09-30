# Declaración de Uso de IA (DUIA) — Parte 1: Esquema, Descomposición y Migración

**Integrante:** Andrés Fabre
**Rol / Asignación:** Parte 1 — Esquema inicial, descomposición sin pérdida
a FNBC, vista de compatibilidad y migración de `control_lote_almacen`
**Materia:** Base de Datos II (UTN) — Unidad 4
**Proyecto Integrador:** Food Store
**Herramienta de IA utilizada:** Gemini

---

## Registro de Interacciones y Decisiones con IA

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| Gemini | Redactar la spec de la Parte 1 (`specs/spec_parte_1_fnbc_control_lote.md`) siguiendo la plantilla del protocolo del grupo, a partir del diagnóstico de FNBC ya corregido | Se le dio el esquema real (`lote_id`, `deposito_id`, `responsable_control_id`), las dos reglas de negocio, y se pidió completar las 8 secciones de la plantilla de spec | Se aceptó casi completo. Se corrigió manualmente una ambigüedad en la sección 4 (la spec dejaba dos alternativas para la vista de compatibilidad — crearla aparte, o renombrar la tabla original — sin decidir una); se optó por la vista aparte, sin tocar `control_lote_almacen` |
| Gemini | Generar el DDL de la descomposición (`responsable_deposito`, tabla transaccional sin `deposito_id`) y la migración de datos | Se pidió aplicar la "receta de tres pasos" del material de cátedra sobre la dependencia violatoria `ResponsableControlID -> DepositoID` | Se aceptó, con un ajuste de nombre: la tabla transaccional se llamó `control_lote` (no `control_lote_almacen_fnbc`, como tenía una versión anterior del archivo) — se unificó el nombre entre la spec y el `.sql` |
| Gemini | Reescribir el script para que fuera re-ejecutable de punta a punta (bloque de limpieza al inicio) y para que la instancia de ejemplo usara exactamente los IDs del enunciado (501-503, 30-31, 801-802) en vez de IDs autogenerados | Se pidió agregar `OVERRIDING SYSTEM VALUE` en los `INSERT` de `lote`, `deposito` y `usuario` para fijar esos IDs | Se aceptó — mejora la fidelidad del script respecto al enunciado y facilita que las capturas muestren exactamente los mismos números que la consigna |
| Gemini | Proponer una sección adicional mostrando una limitación conocida de BCNF: la descomposición no preserva la dependencia `{LoteID, DepositoID} -> ResponsableControlID` | Se le pidió, en base al material de cátedra (sección "el costo de BCNF"), armar una prueba en vivo que mostrara el problema | Se aceptó e implementó como sección 7 del script: se inserta un segundo responsable para el mismo (lote, depósito) en las tablas descompuestas — algo que la tabla original hubiera rechazado por su clave primaria — y se confirma que la vista permite la inconsistencia. Probado con `ROLLBACK` para no dejar datos corruptos |

---

## Verificación sobre el motor real

Todo lo generado se ejecutó y se verificó en `plantilla_food_store`
(protocolo del grupo: nunca `copia_trabajo` para este esquema chico, que no
necesita volumen):

1. Esquema inicial + instancia de ejemplo → confirmado con
   `capturas/p1_captura1_original.png`.
2. Descomposición (`responsable_deposito`, `control_lote`) + migración →
   confirmado con `capturas/p1_captura4a_responsable_deposito.png` y
   `p1_captura4b_control_lote.png`.
3. Vista de compatibilidad `v_control_lote_almacen` → confirmado con
   `capturas/p1_captura5_vista.png`.
4. Verificación bidireccional (los dos `EXCEPT`) → **0 filas en ambos
   sentidos**, confirmado con `p1_captura6_except_original_menos_vista.png`
   y `p1_captura7_except_vista_menos_original.png`.
5. Conteo de filas (antes/después) → confirmado con `p1_captura8_conteo.png`.
6. Limitación de F1 no preservada → confirmado con
   `p1_captura9_limitacion_no_preserva_F1.png`.
7. `down.sql` probado: se ejecutó, se confirmó que las tablas nuevas
   desaparecieron (`p1_down_1_antes.png`, `p1_down_2_despues.png`), y se
   volvió a correr el `up` completo para dejar la base en el estado final
   (`p1_down_3_up_de_nuevo.png`).
8. Corrida completa del script sin errores →
   `p1_00_script_completo_ok.png`.

Nada de esto se aceptó "porque lo dijo la IA": cada paso se corrió en
pgAdmin sobre datos reales antes de darlo por válido.

## Resumen de decisiones

| Aspecto | Resultado |
|---|---|
| Tablas resultantes | `responsable_deposito(responsable_control_id PK, deposito_id)` y `control_lote(lote_id, responsable_control_id)` |
| Atributo común de la descomposición | `responsable_control_id` — es clave primaria de `responsable_deposito`, por eso la unión es sin pérdida |
| Vista de compatibilidad | `v_control_lote_almacen`, reconstruye la relación original vía `JOIN` |
| Verificación | Los dos `EXCEPT` (en ambos sentidos) dieron 0 filas |
| Limitación documentada | La descomposición no preserva `{LoteID, DepositoID} -> ResponsableControlID`; demostrado con una prueba en vivo (sección 7 del script) |
| `down.sql` | Probado: ejecutado, verificado, y el `up` se volvió a correr después |

Detalle completo en `tp_fnbc_control_lote.sql` y en
`specs/spec_parte_1_fnbc_control_lote.md`.
