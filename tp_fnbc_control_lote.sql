-- =============================================================================
-- TRABAJO PRÁCTICO UNIDAD 4 - PARTE 1 (FNBC)
-- Roles: Facundo (análisis FNBC) + Andrés (esquema, descomposición y migración)
-- Archivo: tp_fnbc_control_lote.sql
-- Repositorio: TP-UNIDAD-4-V2
--
-- CORRECCIÓN sobre la versión anterior: el esquema, los nombres de columna
-- y la instancia de ejemplo deben coincidir EXACTAMENTE con los que da el
-- enunciado del TP (punto 4.1), no ser un caso inventado. Este archivo usa
-- el esquema real de la consigna.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ESQUEMA INICIAL E INSTANCIA DE EJEMPLO (tal como los da el enunciado)
-- -----------------------------------------------------------------------------
-- Se asume que las tablas maestras lote y deposito ya existen (de manera
-- análoga a como sucursal se asumió existente en el caso AsignacionEntrega).
-- Se crean acá como tablas mínimas, siguiendo la convención del proyecto
-- (BIGINT GENERATED ALWAYS AS IDENTITY), únicamente para poder ejecutar y
-- probar este script de punta a punta.

CREATE TABLE IF NOT EXISTS lote (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo  VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS deposito (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre  VARCHAR(100) NOT NULL
);

-- Esquema a analizar, EXACTO al del enunciado (4.1)
CREATE TABLE control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

-- Carga de tablas maestras necesarias para poder insertar la instancia de
-- ejemplo (los ids 501-503 de lote y 30-31 de deposito y 801-802 de usuario
-- del enunciado son ilustrativos; acá se generan con IDENTITY, así que se
-- referencian por variable para no asumir que van a salir esos números
-- exactos — lo importante es que la FORMA de los datos sea la misma).
INSERT INTO lote (codigo) VALUES ('LOTE-501'), ('LOTE-502'), ('LOTE-503');
INSERT INTO deposito (nombre) VALUES ('Depósito 30'), ('Depósito 31');
-- responsable_control_id referencia usuario(id), que ya existe en el
-- proyecto Food Store con datos de data.sql. Se usan dos ids de usuario ya
-- cargados (reemplazar por los ids reales de la instancia local si difieren).

-- Instancia de ejemplo EXACTA del enunciado (misma forma: 3 filas, el
-- mismo lote+depósito nunca se repite, el mismo responsable aparece dos
-- veces siempre en el mismo depósito):
INSERT INTO control_lote_almacen (lote_id, deposito_id, responsable_control_id)
SELECT l.id, d.id, u.id
FROM lote l, deposito d, usuario u
WHERE (l.codigo, d.nombre, u.id) IN (
    -- (lote 501, depósito 30, responsable 801)
    ('LOTE-501', 'Depósito 30', (SELECT id FROM usuario ORDER BY id LIMIT 1 OFFSET 0)),
    -- (lote 502, depósito 30, responsable 801) — mismo responsable, mismo depósito
    ('LOTE-502', 'Depósito 30', (SELECT id FROM usuario ORDER BY id LIMIT 1 OFFSET 0)),
    -- (lote 503, depósito 31, responsable 802) — responsable distinto, depósito distinto
    ('LOTE-503', 'Depósito 31', (SELECT id FROM usuario ORDER BY id LIMIT 1 OFFSET 1))
);


-- -----------------------------------------------------------------------------
-- 2. ANÁLISIS DE DEPENDENCIAS FUNCIONALES Y CLAVES CANDIDATAS (4.2 a, b, c)
-- -----------------------------------------------------------------------------
-- Regla de negocio (enunciado 4.1), en notación formal, usando LoteID,
-- DepositoID y ResponsableControlID:
--
--   R1: "Para un lote y un depósito interviniente dados, el responsable de
--        control queda unívocamente determinado."
--        => F1: {LoteID, DepositoID} -> ResponsableControlID
--
--   R2: "Cada responsable de control pertenece a un único depósito: no
--        controla lotes coordinados desde depósitos distintos."
--        => F2: ResponsableControlID -> DepositoID
--
-- Cálculo de clausuras sobre los subconjuntos candidatos razonables:
--
--   {LoteID, DepositoID}+ :
--     Por F1, agrego ResponsableControlID.
--     {LoteID, DepositoID}+ = {LoteID, DepositoID, ResponsableControlID} = TODOS los atributos.
--     => {LoteID, DepositoID} ES clave candidata (determina todo y es mínima:
--        ni LoteID solo ni DepositoID solo alcanzan, ninguna FD los tiene
--        como determinante único).
--
--   {LoteID, ResponsableControlID}+ :
--     Por F2, agrego DepositoID.
--     {LoteID, ResponsableControlID}+ = {LoteID, ResponsableControlID, DepositoID} = TODOS los atributos.
--     => {LoteID, ResponsableControlID} ES clave candidata (mismo argumento de minimalidad).
--
-- Conjunto COMPLETO de claves candidatas: { {LoteID, DepositoID},
--                                            {LoteID, ResponsableControlID} }
--
-- Atributos primos (participan de alguna clave candidata): LoteID,
--   DepositoID, ResponsableControlID — LOS TRES son primos, porque las dos
--   claves candidatas comparten LoteID y cada atributo aparece en al menos
--   una de las dos.
-- No hay atributos no primos en este esquema (son solo 3 columnas y las
-- 3 participan de alguna clave candidata).
--
-- Determinación de FNBC (4.2 c):
--   FNBC exige que TODO determinante de una dependencia no trivial sea
--   superclave. F1 tiene como determinante {LoteID, DepositoID}, que SÍ es
--   superclave (es clave candidata) — no viola FNBC.
--   F2 tiene como determinante ResponsableControlID SOLO, que NO es
--   superclave (su clausura no incluye LoteID: {ResponsableControlID}+ =
--   {ResponsableControlID, DepositoID} ≠ todos los atributos).
--
--   => control_lote_almacen NO CUMPLE FNBC. La dependencia violatoria es
--      F2: ResponsableControlID -> DepositoID, porque su determinante
--      (ResponsableControlID) no es superclave del esquema.
--
--   (Nota: si se aplicara la definición de 3FN en lugar de FNBC, F2 se
--   salvaría por la cláusula de excepción "o el atributo determinado es
--   primo" — DepositoID es primo. Por eso el esquema SÍ cumple 3FN pero
--   NO cumple FNBC; la consigna pide explícitamente evaluar con FNBC, no
--   con 3FN.)

-- Evidencia en los datos (no prueba la regla de negocio, solo la
-- contrasta contra los datos de ejemplo cargados):
-- ¿Hay algún responsable con más de un depósito distinto?
SELECT responsable_control_id, COUNT(DISTINCT deposito_id) AS depositos_distintos
FROM control_lote_almacen
GROUP BY responsable_control_id
HAVING COUNT(DISTINCT deposito_id) > 1;
-- Con la instancia de ejemplo, debe devolver 0 filas (el responsable del
-- enunciado nunca aparece con dos depósitos distintos) — eso no prueba que
-- F2 sea una regla real, la regla la confirma el enunciado, no la consulta.


-- -----------------------------------------------------------------------------
-- 3. ANOMALÍAS CLÁSICAS SOBRE LA INSTANCIA DE EJEMPLO (4.2 d)
-- -----------------------------------------------------------------------------
-- Anomalía de ACTUALIZACIÓN: si el responsable que hoy controla desde el
-- depósito 30 (el que aparece en los lotes 501 y 502) se muda al depósito
-- 32, hay que actualizar deposito_id en TODAS las filas donde aparece ese
-- responsable_control_id (en el ejemplo son 2 filas; en producción pueden
-- ser cientos). Si se actualiza una sola fila y se olvida la otra, el
-- mismo responsable queda figurando en dos depósitos distintos según qué
-- fila se consulte — contradiciendo la regla de negocio R2 sin que el
-- motor lo detecte, porque no hay ninguna restricción que impida esa
-- inconsistencia dentro de esta única tabla.
--
-- Anomalía de INSERCIÓN: no se puede registrar que un responsable nuevo
-- (por ejemplo, uno recién contratado) pertenece al depósito 31 hasta que
-- se le asigne el control de al menos un lote. El dato "a qué depósito
-- pertenece cada responsable" queda preso dentro de una tabla que en
-- realidad es de control de lotes, no de recursos humanos.
--
-- Anomalía de BORRADO: si se cancela o se depura el único lote (503) que
-- tiene asignado el responsable del depósito 31, se borra esa fila y con
-- ella se pierde el único registro de que ese responsable pertenece al
-- depósito 31 — un dato de recursos humanos desaparece como efecto
-- colateral de borrar un dato transaccional de logística.


-- -----------------------------------------------------------------------------
-- 4. DESCOMPOSICIÓN A FNBC (UP.SQL) — 4.2 e
-- -----------------------------------------------------------------------------
-- Dependencia funcional violatoria: ResponsableControlID -> DepositoID
-- Determinante: responsable_control_id (NO es superclave en control_lote_almacen)
--
-- Receta de descomposición (tres pasos):
--   1. Tabla nueva: responsable_control_id (determinante) + deposito_id
--      (lo que determina). responsable_control_id es la clave primaria.
--   2. Tabla vieja: pierde deposito_id, se queda con lote_id +
--      responsable_control_id (ahora FK a la tabla nueva).
--   3. Vista de compatibilidad: JOIN de las dos, con el nombre viejo.

-- Paso 1: tabla nueva con el dato maestro (responsable -> depósito)
CREATE TABLE responsable_deposito (
    responsable_control_id  BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id)
);

-- Paso 1 (cont.): tabla transaccional sin la columna redundante
CREATE TABLE control_lote_almacen_fnbc (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- Paso 2: migración de datos, SIN destruir el origen (patrón
-- expandir-migrar-verificar-contraer, protocolo_seguridad.md Paso 6)
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM control_lote_almacen;
-- Si este INSERT fallara por clave duplicada, sería la señal de que la
-- regla de negocio F2 no se cumple en los datos reales (un responsable
-- con dos depósitos distintos) — se resolvería con el negocio antes de
-- seguir, nunca forzando el script.

INSERT INTO control_lote_almacen_fnbc (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id
FROM control_lote_almacen;


-- -----------------------------------------------------------------------------
-- 5. VISTA DE COMPATIBILIDAD Y JUSTIFICACIÓN DE UNIÓN SIN PÉRDIDA (4.2 e, f)
-- -----------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT
    c.lote_id,
    rd.deposito_id,
    c.responsable_control_id
FROM control_lote_almacen_fnbc c
JOIN responsable_deposito rd ON rd.responsable_control_id = c.responsable_control_id;

-- Justificación de la unión sin pérdida (4.2 f): la columna común de la
-- descomposición es responsable_control_id. Esa columna es CLAVE PRIMARIA
-- de responsable_deposito (una de las dos tablas resultantes) — por lo
-- tanto es superclave de al menos una de las dos, que es exactamente la
-- condición que garantiza que el JOIN de reconstrucción no pierda ni
-- invente filas (ver protocolo_seguridad.md / material de cátedra,
-- sección "2.5 ¿Por qué no se pierde información?").

-- VERIFICACIÓN BIDIRECCIONAL DE UNIÓN SIN PÉRDIDA (protocolo_seguridad.md,
-- Paso 5 — obligatorio en los dos sentidos, no alcanza con uno solo)

-- Check 1: filas de la tabla original que falten en la vista (pérdida de datos)
-- Debe devolver 0 filas.
SELECT lote_id, deposito_id, responsable_control_id
FROM control_lote_almacen
EXCEPT
SELECT lote_id, deposito_id, responsable_control_id
FROM v_control_lote_almacen;

-- Check 2: filas espurias en la vista que no existan en la tabla original
-- (JOIN que no era sin pérdida). Debe devolver 0 filas.
SELECT lote_id, deposito_id, responsable_control_id
FROM v_control_lote_almacen
EXCEPT
SELECT lote_id, deposito_id, responsable_control_id
FROM control_lote_almacen;

-- Conteo de filas, como verificación complementaria:
SELECT (SELECT COUNT(*) FROM control_lote_almacen) AS antes,
       (SELECT COUNT(*) FROM v_control_lote_almacen) AS despues;


-- -----------------------------------------------------------------------------
-- 6. SCRIPT DE REVERSIÓN (DOWN.SQL)
-- -----------------------------------------------------------------------------
-- Probado ejecutando up -> down -> confirmando que la base vuelve al
-- estado inicial (protocolo_seguridad.md, Paso 6, regla dura de down.sql).
/*
BEGIN;
DROP VIEW IF EXISTS v_control_lote_almacen;
DROP TABLE IF EXISTS control_lote_almacen_fnbc;
DROP TABLE IF EXISTS responsable_deposito;
-- control_lote_almacen, deposito, lote y usuario NO se tocan: son la
-- fuente de verdad original / tablas del proyecto, no algo generado por
-- esta descomposición.
COMMIT;
*/
