# Declaración de Uso de IA (DUIA) — Parte 1: Análisis FNBC

**Integrante:** Facundo Quiroga
**Rol / Asignación:** Parte 1 — Análisis de dependencias funcionales, claves
candidatas y violación de FNBC sobre `control_lote_almacen`
**Materia:** Base de Datos II (UTN) — Unidad 4
**Proyecto Integrador:** Food Store
**Herramienta de IA utilizada:** Gemini



---

## Registro de Interacciones y Decisiones con IA

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| Gemini | Primer intento de armar el esquema `control_lote_almacen` y su análisis de dependencias, a partir de la consigna del TP | Se le pidió generar un esquema para "control de lotes en depósitos con un responsable a cargo" | **Se descartó la primera versión.** Gemini inventó una tabla distinta a la del enunciado (`almacenero` con columnas `nombre_almacenero`, `turnos`, `resultado_inspection`, sin respetar los nombres de columna (`lote_id`, `deposito_id`, `responsable_control_id`) ni la instancia de datos exacta que da la consigna (lotes 501-503, depósitos 30-31, responsables 801-802). Se detectó al contrastar la salida contra el PDF del enunciado punto 4.1, y se corrigió rehaciendo el análisis sobre el esquema real. |
| Gemini | Recalcular dependencias funcionales, clausuras y claves candidatas sobre el esquema **correcto** (`lote_id`, `deposito_id`, `responsable_control_id`) | Se le pasaron las dos reglas de negocio del enunciado (4.1) y se pidió la notación formal, el cálculo de clausuras de `{L,D}`, `{L,R}` y `{R}`, y la determinación de FNBC | Se aceptó: F1 = `{LoteID, DepositoID} -> ResponsableControlID`, F2 = `ResponsableControlID -> DepositoID`; claves candidatas `{L,D}` y `{L,R}`; los tres atributos son primos; F2 viola FNBC porque `ResponsableControlID` no es superclave. Se verificó a mano el cálculo de clausuras antes de darlo por bueno. |
| Gemini | Redactar las 3 anomalías clásicas (inserción, borrado, actualización) sobre la instancia de ejemplo | Se pidió un escenario concreto para cada anomalía, usando los datos de la instancia (lotes 501/502/503, responsables 801/802) | Se aceptó con ajustes menores de redacción para que cada anomalía citara explícitamente qué filas de la instancia la ilustran |

---

## Verificación sobre el motor real

El análisis no se dio por válido solo por venir de la IA — se contrastó
contra los datos reales cargados en `plantilla_food_store`:

- `SELECT * FROM control_lote_almacen` → confirmó que la instancia cargada
  coincide con la del enunciado (ver `capturas/p1_captura1_original.png`).
- Prueba en vivo de la anomalía de actualización: se modificó
  `deposito_id` en una sola de las dos filas del responsable 801 (dentro de
  una transacción con `ROLLBACK`, sin dejar datos corruptos) y se confirmó
  que el motor lo permite sin error, generando la inconsistencia descripta
  (ver `capturas/p1_captura3_anomalia_actualizacion.png`).

## Resumen de decisiones

| Aspecto | Resultado |
|---|---|
| Dependencias funcionales | F1: `{LoteID, DepositoID} -> ResponsableControlID`; F2: `ResponsableControlID -> DepositoID` |
| Claves candidatas | `{LoteID, DepositoID}` y `{LoteID, ResponsableControlID}` |
| Atributos primos | Los 3 (LoteID, DepositoID, ResponsableControlID) — ninguno no-primo |
| ¿Cumple FNBC? | No — F2 la viola, porque `ResponsableControlID` no es superclave |
| ¿Cumple 3FN? | Sí — F2 se salva por la excepción de la 3FN (DepositoID es primo) |
| Error detectado y corregido | Primera versión con esquema inventado (tabla `almacenero`), reemplazada por el esquema exacto del enunciado |

Detalle completo del análisis, con la notación formal completa, en los
comentarios de `tp_fnbc_control_lote.sql` (sección 2) y en las 3 anomalías
redactadas (sección 3).
