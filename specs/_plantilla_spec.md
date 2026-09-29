# Spec: refactorización <nombre>

> Copiar este archivo como `specs/<nombre-de-la-refactorizacion>.md` y
> completarlo ANTES de pedirle a OpenCode que genere el `up.sql`/`down.sql`.
> Ver `protocolo_seguridad.md` (sección "Plantilla de spec") para el porqué
> de cada campo.

## 1. Contexto

Tabla(s) afectadas, volumen aproximado de filas, quién las consulta hoy.

## 2. Reglas de negocio (confirmadas con: ______)

- R1: <en castellano> → <notación formal X → Y>
- R2: ...

Evidencia en los datos:

```sql
-- <consulta de verificación, ej: GROUP BY ... HAVING COUNT(DISTINCT y) > 1>
```

Resultado obtenido: <pegar resultado>

> Recordar: que esta consulta devuelva 0 filas NO prueba que la dependencia
> exista como regla de negocio, solo que se cumple en los datos de hoy.

## 3. Diagnóstico

Claves candidatas: ...

Forma normal actual: ... porque la dependencia <Fn> tiene determinante no
superclave / dependencia multivaluada con determinante no superclave.

## 4. Esquema objetivo

DDL de las tablas resultantes + vista de compatibilidad.

## 5. Plan de migración (expandir–migrar–verificar–contraer)

Paso a paso, en orden, indicando qué paso es reversible sin pérdida.

## 6. Criterios de aceptación

- [ ] `COUNT(*)` coincide antes y después
- [ ] Los dos `EXCEPT` (en ambos sentidos) devuelven 0 filas
- [ ] Todas las consultas existentes siguen funcionando (vista de
      compatibilidad)
- [ ] `down.sql` ejecutado y verificado: la base vuelve al estado inicial

## 7. Plan de reversión

Contenido de `down.sql` y qué se pierde si se revierte después de que ya se
escribieron datos nuevos con el esquema nuevo.

## 8. Riesgos

Qué puede salir mal y cómo se detecta.
