# Declaración de Uso de IA (DUIA) — Facundo Quiroga

**Integrante:** Facundo Quiroga (Grupo 10)
**Materia:** Base de Datos II (UTN) — Unidad 4
**Proyecto Integrador:** Food Store
**Aporte:** primera versión de `tp_fnbc_control_lote.sql` (Parte 1), subida en la rama `integrante-3` (commit `28cdbca`)
**Herramienta de IA utilizada:** Gemini *(Facundo: confirmá que fue esta herramienta; si usaste otra, corregilo)*

> Esta declaración cubre únicamente lo que hizo Facundo. La versión final del script de la Parte 1,
> sus capturas y su verificación en pgAdmin fueron consolidadas por Mariano Chirino y están
> declaradas en `duia_mariano.md`.

---

## Registro de interacciones con IA

Según lo declarado por Facundo, usó **un único prompt**, para generar el archivo completo.

| Herramienta | Para qué se usó | Prompt (resumen) | Qué produjo | Se aceptó / se descartó — por qué |
|---|---|---|---|---|
| Gemini | Generar de una sola vez el contenido completo de `tp_fnbc_control_lote.sql` | Rol de DBA PostgreSQL; se pidió un script en 5 fases (esquema e instancia, diagnóstico teórico en comentarios, descomposición y migración, verificación con conteo y los dos `EXCEPT`, reversión) bajo el patrón expandir–migrar–verificar–contraer. El prompt completo está al final de este documento | Una primera versión del script, subida al repositorio en el commit `28cdbca` | **Descartada y reemplazada.** El prompt no incluía las columnas de la tabla ni los datos del enunciado (decía solo "los 3 registros del enunciado"), y el resultado inventó un esquema propio: una tabla `almacenero` con columnas como `id_almacenero`, `nombre_almacenero` y `turnos`, que no corresponde al punto 4.1 del enunciado (columnas `lote_id`, `deposito_id`, `responsable_control_id`; lotes 501-503, depósitos 30-31, responsables 801-802). Por eso el análisis de dependencias de esa versión (`id_almacenero -> nombre_almacenero, turnos`) tampoco aplicaba. El grupo la rehízo sobre el esquema exacto del enunciado (commit `f583fd1`, "parte de facu corregida") |

*(Facundo: confirmá si ejecutaste ese script en pgAdmin antes de subirlo, y si modificaste algo a mano sobre lo que devolvió la IA. Si fue así, agregalo a la tabla.)*

## Lo que se aprovechó de esa versión

La **estructura en fases** que pedía el prompt (esquema e instancia, diagnóstico, descomposición y migración, verificación con los dos `EXCEPT`, reversión) es la que quedó en el script final. El contenido concreto (esquema, instancia, dependencias, tablas descompuestas) es el de la versión corregida por el grupo, no el de la primera versión.

## Verificación

- La primera versión **no se dio por válida**: al contrastarla con el punto 4.1 del enunciado se comprobó que no respetaba el esquema, y se reemplazó.
- El análisis correcto, sobre el esquema real, es: F1 `{LoteID, DepositoID} → ResponsableControlID`, F2 `ResponsableControlID → DepositoID`; claves candidatas `{L,D}` y `{L,R}`; los tres atributos son primos; viola FNBC por F2 y cumple 3FN.
- La versión final se ejecutó en pgAdmin sobre `copia_fnbc` (por Mariano): los dos `EXCEPT` dieron 0 filas y el conteo coincidió (3 y 3). Capturas en `capturas/`.

## Prompt utilizado (completo)

```text
Actúa como un DBA y experto en bases de datos PostgreSQL. Necesito que generes el contenido
completo y definitivo para el archivo tp_fnbc_control_lote.sql, correspondiente al ejercicio de
Normalización en Forma Normal de Boyce-Codd (FNBC) del Trabajo Práctico de Base de Datos.

El script debe estar completamente articulado, estructurado en secciones claras con comentarios
explicativos, ser ejecutable de principio a fin sin errores y cumplir rigurosamente con el patrón
de migración "Expandir – Migrar – Verificar – Contraer".

Estructura requerida para el archivo tp_fnbc_control_lote.sql:

1. FASE 1: ESQUEMA INICIAL E INSTANCIA DE EJEMPLO
   - DDL para crear las tablas base originales: lote, deposito y control_lote_almacen (con sus
     PKs y FKs correspondientes).
   - DML con la inserción de la instancia de datos de ejemplo (los 3 registros/INSERT del
     enunciado).

2. FASE 2: DIAGNÓSTICO Y JUSTIFICACIÓN TEÓRICA (En comentarios SQL)
   - Notación formal de Dependencias Funcionales (FDs).
   - Cálculo de clausuras y determinación del conjunto completo de claves candidatas
     (distinguiendo atributos primos y no primos).
   - Justificación formal de por qué control_lote_almacen viola FNBC (identificando la FD
     violatoria y demostrando que su determinante no es superclave).
   - Explicación breve de las 3 anomalías clásicas (Inserción, Modificación, Eliminación)
     presentes en el esquema original.

3. FASE 3: DESCOMPOSICIÓN Y MIGRACIÓN (UP.SQL)
   - DDL para crear las nuevas tablas normalizadas en FNBC con sus PKs y FKs.
   - DML de migración: Instrucciones INSERT INTO ... SELECT para trasvasar los datos desde la
     tabla original hacia las nuevas tablas sin pérdida de información.
   - Creación de la Vista de Compatibilidad que emule la estructura de la tabla original para no
     romper consultas existentes.

4. FASE 4: VERIFICACIÓN Y AUDITORÍA DE INTEGRIDAD
   - Consultas de verificación de conteo de filas (COUNT).
   - Consultas con AMBOS EXCEPT (en las dos direcciones) para demostrar matemáticamente que la
     unión/join es sin pérdida de información y sin generación de tuplas espurias:
     * (Datos de la vista de compatibilidad) EXCEPT (Datos de la tabla original)
     * (Datos de la tabla original) EXCEPT (Datos de la vista de compatibilidad)
     Ambas deben retornar 0 filas.

5. FASE 5: REVERSIÓN Y LIMPIEZA (DOWN.SQL)
   - Bloque de script que permita revertir exactamente los cambios aplicados en la migración
     (eliminar vista, eliminar tablas descompuestas) y restaurar el estado inicial limpiamente.

Por favor, genera el código SQL limpio, formateado profesionalmente y listo para ser copiado
directamente al archivo tp_fnbc_control_lote.sql.
```

## Resumen

| Aspecto | Resultado |
|---|---|
| Herramienta | Gemini (a confirmar por Facundo) |
| Uso declarado | Un único prompt para generar el script completo de la Parte 1 |
| Resultado | Primera versión descartada: inventó un esquema que no correspondía al enunciado |
| Corrección | El grupo rehízo el script sobre el esquema exacto del punto 4.1 (commit `f583fd1`) |
| Aprovechado | La estructura en fases del prompt (incluidos los dos `EXCEPT` y la reversión) |
