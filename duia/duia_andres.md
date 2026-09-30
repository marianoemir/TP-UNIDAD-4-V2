# Declaración de Uso de IA (DUIA) — Andrés Fabre

**Integrante:** Andrés Fabre (Grupo 10)
**Materia:** Base de Datos II (UTN) — Unidad 4
**Proyecto Integrador:** Food Store
**Aporte:** spec de la Parte 1 (`specs/spec_parte_1_fnbc_control_lote.md`): diagnóstico teórico de FNBC y esquema objetivo de la descomposición
**Herramienta de IA utilizada:** Gemini

> Esta declaración cubre únicamente lo que hizo Andrés. El script final de la Parte 1
> (`tp_fnbc_control_lote.sql`), sus capturas y su verificación en pgAdmin fueron
> consolidados por Mariano Chirino y están declarados en `duia_mariano.md`.

---

## Registro de interacciones con IA

| Herramienta | Para qué se usó | Prompt (resumen) | Qué produjo | Se aceptó / se descartó — por qué |
|---|---|---|---|---|
| Gemini | Generar el diagnóstico teórico de la Parte 1 en Markdown para incluirlo en la spec | Se le dio la tabla `control_lote_almacen(lote_id, deposito_id, responsable_control_id)` y las dos reglas de negocio del enunciado, y se pidió: notación formal de las dependencias, clausuras paso a paso, claves candidatas con atributos primos y no primos, justificación de la violación de FNBC, las tres anomalías sobre la instancia de ejemplo y el esquema objetivo de la descomposición. El prompt completo está al final de este documento | Las secciones 3 (diagnóstico) y 4 (esquema objetivo) de la spec, que Andrés subió al repositorio en el commit `1e99381` | **Aceptado.** El diagnóstico es correcto y coincide con el análisis independiente de las demás versiones: F1 `{L,D} → R`, F2 `R → D`; claves candidatas `{L,D}` y `{L,R}`; los tres atributos son primos; viola FNBC por F2. Tiene dos puntos pendientes, indicados abajo |

## Puntos de la spec que se corrigieron después

La spec subida por Andrés tenía dos detalles que se revisaron en el grupo antes de la entrega:

1. **Ambigüedad en la sección 4.** Dejaba dos alternativas para la vista de compatibilidad (crear `v_control_lote_almacen` aparte, o "renombrar la tabla original") sin decidir una. La decisión del grupo fue la vista aparte, sin renombrar la tabla original.
2. **Nombre del archivo.** El prompt pedía guardarlo como `specs/parte1_control_lote.md`, pero el archivo se subió como `specs/spec_parte_1_fnbc_control_lote.md`; el repositorio usa este último nombre.

*(Andrés: confirmá si hiciste alguna otra modificación a mano sobre lo que devolvió Gemini antes de subirlo, y si usaste la IA para algo más de la Parte 1. Si fue así, agregalo como una fila nueva en la tabla.)*

## Verificación

- El diagnóstico se contrastó con el enunciado (punto 4.1) y con las otras versiones del análisis de la Parte 1 del grupo, que llegan a las mismas dependencias, claves y violación de FNBC.
- El esquema objetivo de la spec (`responsable_deposito` y `control_lote`) es el que finalmente se implementó en `tp_fnbc_control_lote.sql`, y se verificó en pgAdmin sobre `copia_fnbc`: los dos `EXCEPT` dieron 0 filas y el conteo coincidió (3 y 3). Esa ejecución la hizo Mariano; las capturas están en `capturas/`.

## Prompt utilizado (completo)

```text
Hola Gemini, necesito resolver el análisis teórico de Normalización (FNBC) para la Parte 1
(control_lote_almacen) del TP4 de Base de Datos 1.

La tabla original es control_lote_almacen(lote_id, deposito_id, responsable_control_id) y
cuenta con las siguientes reglas de negocio:

  - Para un lote y un depósito interviniente dados, el responsable de control queda
    unívocamente determinado ({lote_id, deposito_id} -> responsable_control_id).
  - Cada responsable pertenece a un único depósito (responsable_control_id -> deposito_id).

Por favor, generame el diagnóstico teórico completo en formato Markdown para incluirlo en la
spec specs/parte1_control_lote.md, incluyendo:

  - Notación formal de las dependencias funcionales (FDs).
  - Cálculo paso a paso de las clausuras de atributos.
  - Conjunto completo de claves candidatas, identificando atributos primos y no primos.
  - Verificación y justificación de por qué la relación viola la Forma Normal de Boyce-Codd
    (FNBC), indicando la FD violatoria.
  - Redacción detallada de las 3 anomalías clásicas de diseño (Inserción, Borrado y
    Actualización) aplicadas a la instancia de datos de ejemplo.
  - Esquema objetivo resultante de aplicar la descomposición sin pérdida de información.
```

## Resumen

| Aspecto | Resultado |
|---|---|
| Herramienta | Gemini |
| Uso declarado | Diagnóstico teórico de FNBC y esquema objetivo, para la spec de la Parte 1 |
| Resultado | Aceptado; correcto, con la ambigüedad de la vista resuelta por el grupo después |
| Verificación | Coincide con el enunciado y con las demás versiones; implementado y verificado en pgAdmin por Mariano |
