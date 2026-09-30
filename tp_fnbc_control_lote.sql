-- =============================================================================
-- TRABAJO PRÁCTICO UNIDAD 4 - PARTE 1: FNBC sobre control_lote_almacen
-- Grupo 10 — Base de Datos II (UTN, Tecnicatura Universitaria en Programación)
-- Proyecto integrador: Food Store (PostgreSQL)
--
-- Cómo ejecutarlo (pgAdmin, base copia_fnbc creada desde plantilla_food_store):
--   1) Abrir este archivo en el Query Tool y ejecutarlo completo (F5).
--      Empieza con una limpieza, así que se puede volver a correr las veces
--      que haga falta.
--   2) Para las capturas, seleccionar SOLO la consulta marcada como
--      "CAPTURA n" y ejecutarla (F5 corre únicamente lo seleccionado).
--      pgAdmin muestra solo el resultado de la última sentencia ejecutada.
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 0. LIMPIEZA (permite re-ejecutar el script; solo tocar en una copia de trabajo)
-- -----------------------------------------------------------------------------
DROP VIEW  IF EXISTS v_control_lote_almacen;
DROP TABLE IF EXISTS control_lote;
DROP TABLE IF EXISTS responsable_deposito;
DROP TABLE IF EXISTS control_lote_almacen;
DROP TABLE IF EXISTS lote;
DROP TABLE IF EXISTS deposito;
DELETE FROM usuario WHERE id IN (801, 802, 803);


-- -----------------------------------------------------------------------------
-- 1. ESQUEMA INICIAL E INSTANCIA DE EJEMPLO (los del enunciado, punto 4.1)
-- -----------------------------------------------------------------------------
-- El enunciado asume que las tablas maestras lote y deposito ya existen. Se
-- crean acá como tablas mínimas (convención del proyecto: BIGINT GENERATED
-- ALWAYS AS IDENTITY) solo para poder ejecutar el ejemplo de punta a punta.
-- Se insertan con OVERRIDING SYSTEM VALUE para que los ids sean EXACTAMENTE
-- los del enunciado (lotes 501-503, depósitos 30-31, responsables 801-802).
-- El depósito 32 y el responsable 803 no forman parte de la instancia: se
-- usan solo en las pruebas de anomalías de la sección 3 y de la sección 7.

CREATE TABLE lote (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo  VARCHAR(50) NOT NULL
);

CREATE TABLE deposito (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre  VARCHAR(100) NOT NULL
);

INSERT INTO lote (id, codigo) OVERRIDING SYSTEM VALUE VALUES
    (501, 'LOTE-501'),
    (502, 'LOTE-502'),
    (503, 'LOTE-503');

INSERT INTO deposito (id, nombre) OVERRIDING SYSTEM VALUE VALUES
    (30, 'Depósito 30'),
    (31, 'Depósito 31'),
    (32, 'Depósito 32');

-- Los responsables de control son usuarios del sistema (usuario ya existe en
-- Food Store): se agregan tres con los ids del enunciado.
INSERT INTO usuario (id, nombre, apellido, mail, contrasena) OVERRIDING SYSTEM VALUE VALUES
    (801, 'Responsable', 'Control 801', 'resp801@foodstore.com', 'hash_resp801'),
    (802, 'Responsable', 'Control 802', 'resp802@foodstore.com', 'hash_resp802'),
    (803, 'Responsable', 'Control 803', 'resp803@foodstore.com', 'hash_resp803');

-- Esquema a analizar, EXACTO al del enunciado
CREATE TABLE control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

-- Instancia de ejemplo EXACTA del enunciado
INSERT INTO control_lote_almacen VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- CAPTURA 1: esquema original con su instancia de ejemplo
SELECT * FROM control_lote_almacen ORDER BY lote_id, deposito_id;


-- -----------------------------------------------------------------------------
-- 2. DEPENDENCIAS FUNCIONALES, CLAUSURAS, CLAVES Y FNBC  (4.2 a, b, c)
-- -----------------------------------------------------------------------------
-- Notación: L = LoteID, D = DepositoID, R = ResponsableControlID.
--
-- (a) Dependencias funcionales de la regla de negocio
--   Regla 1: "para un lote y un depósito interviniente dados, el responsable
--            de control queda unívocamente determinado"
--       F1:  {LoteID, DepositoID} -> ResponsableControlID     ({L, D} -> R)
--   Regla 2: "cada responsable de control pertenece a un único depósito"
--       F2:  ResponsableControlID -> DepositoID               (R -> D)
--
-- (b) Clausuras de los subconjuntos candidatos (con F = {F1, F2})
--   {L}+     = {L}                 (ninguna dependencia parte de L solo)
--   {D}+     = {D}                 (ninguna dependencia parte de D solo)
--   {R}+     = {R, D}              (por F2)                   no es clave
--   {L, D}+  = {L, D, R}           (por F1)                   TODOS los atributos
--   {L, R}+  = {L, R, D}           (por F2)                   TODOS los atributos
--   {D, R}+  = {D, R}              (F2 aporta D, que ya está) no incluye L
--
--   Claves candidatas (superclaves mínimas):
--       {LoteID, DepositoID}  y  {LoteID, ResponsableControlID}
--   Ambas son mínimas: ni {L}, ni {D}, ni {R} determinan todos los atributos.
--   Conjunto COMPLETO de claves candidatas = { {L, D}, {L, R} }.
--
--   Atributos primos (participan de alguna clave candidata): L, D y R.
--   Atributos no primos: ninguno.
--
-- (c) Determinación de FNBC (definición formal, no la de 3FN)
--   Un esquema está en FNBC si, para toda dependencia funcional no trivial
--   X -> A, el determinante X es superclave.
--     F1: X = {L, D}, que es clave candidata (superclave)  -> cumple.
--     F2: X = {R}. Su clausura {R}+ = {R, D} no contiene L, o sea que
--         {R} NO es superclave -> VIOLA FNBC.
--   => control_lote_almacen NO está en FNBC. Dependencia violatoria:
--          ResponsableControlID -> DepositoID
--      porque su determinante no es superclave.
--   Observación: sí cumple 3FN, porque en F2 el atributo determinado (D) es
--   primo, y 3FN admite esa excepción; FNBC no. Por eso la consigna pide
--   evaluar con FNBC.

-- Contraste con los datos (no prueba la regla, solo la confirma en la
-- instancia): ¿algún responsable aparece con más de un depósito?
-- CAPTURA 2 (opcional): debe devolver 0 filas
SELECT responsable_control_id, COUNT(DISTINCT deposito_id) AS depositos_distintos
FROM control_lote_almacen
GROUP BY responsable_control_id
HAVING COUNT(DISTINCT deposito_id) > 1;


-- -----------------------------------------------------------------------------
-- 3. ANOMALÍAS CLÁSICAS SOBRE LA INSTANCIA DE EJEMPLO  (4.2 d)
-- -----------------------------------------------------------------------------
-- Todas nacen de que el hecho "a qué depósito pertenece cada responsable"
-- (R -> D) está mezclado con el hecho "qué responsable controla cada lote en
-- cada depósito" (F1) en una misma tabla.
--
-- ANOMALÍA DE ACTUALIZACIÓN. El responsable 801 aparece en dos filas, (501,30)
-- y (502,30). Si 801 pasa a pertenecer al depósito 32 hay que modificar las
-- dos filas. Si solo se modifica una, 801 queda en dos depósitos a la vez
-- (30 y 32), violando la regla 2, y el motor no lo impide porque ninguna
-- restricción de esta tabla expresa R -> D. Con más lotes por responsable
-- el riesgo crece: hay que tocar tantas filas como lotes controle.
--
-- ANOMALÍA DE INSERCIÓN. No se puede registrar que un responsable nuevo (por
-- ejemplo, el 803) pertenece al depósito 31 mientras no tenga un lote
-- asignado: lote_id forma parte de la clave primaria y no admite NULL. Un
-- dato de personal queda atado a que exista una fila de control de lotes.
--
-- ANOMALÍA DE BORRADO. El responsable 802 aparece en una única fila, la del
-- lote 503. Si se borra esa fila (por ejemplo, porque el lote 503 se
-- cancela), se pierde la única constancia de que 802 pertenece al depósito
-- 31: se borra un dato del personal como efecto colateral de borrar un dato
-- de logística.

-- Prueba ejecutable de la anomalía de actualización (correr paso a paso; se
-- deshace con ROLLBACK, no deja datos modificados):
/*
BEGIN;

UPDATE control_lote_almacen
SET deposito_id = 32
WHERE lote_id = 501 AND responsable_control_id = 801;   -- solo UNA de las dos filas
-- El motor lo acepta sin error.

-- CAPTURA 3: ahora el responsable 801 figura en dos depósitos (debe devolver 1 fila)
SELECT responsable_control_id, COUNT(DISTINCT deposito_id) AS depositos_distintos
FROM control_lote_almacen
GROUP BY responsable_control_id
HAVING COUNT(DISTINCT deposito_id) > 1;

ROLLBACK;
*/


-- -----------------------------------------------------------------------------
-- 4. DESCOMPOSICIÓN SIN PÉRDIDA A FNBC  (4.2 e)  — "up"
-- -----------------------------------------------------------------------------
-- Algoritmo: dada la dependencia violatoria X -> Y (acá R -> D) sobre el
-- esquema S = {L, D, R}:
--     S1 = X u Y   = {R, D}      (el determinante con lo que determina)
--     S2 = S - Y   = {L, R}      (el resto, conservando el determinante)
-- S1 y S2 están en FNBC: en S1 el único determinante es R, que es su clave;
-- S2 no tiene dependencias no triviales.
--
-- Patrón expandir - migrar - verificar - contraer: primero se crean las tablas
-- nuevas, se migran los datos SIN tocar la original, se verifica, y la
-- original solo se retiraría al final (acá se conserva para poder comparar).

CREATE TABLE responsable_deposito (
    responsable_control_id  BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id)
);

CREATE TABLE control_lote (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- Migración de datos (la tabla original no se modifica ni se borra)
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM control_lote_almacen;
-- Si este INSERT fallara por clave duplicada, sería la señal de que la regla
-- de negocio R -> D no se cumple en los datos reales; se resolvería con el
-- negocio antes de seguir, nunca forzando el script.

INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id
FROM control_lote_almacen;

-- CAPTURA 4: contenido de las dos tablas resultantes (ejecutar una por vez)
SELECT * FROM responsable_deposito ORDER BY responsable_control_id;
SELECT * FROM control_lote ORDER BY lote_id, responsable_control_id;


-- -----------------------------------------------------------------------------
-- 5. VISTA DE COMPATIBILIDAD  (4.2 e)
-- -----------------------------------------------------------------------------
-- Reconstruye la relación original con una reunión natural: la única columna
-- común entre las dos tablas es responsable_control_id.

CREATE VIEW v_control_lote_almacen AS
SELECT lote_id, deposito_id, responsable_control_id
FROM control_lote
NATURAL JOIN responsable_deposito;

-- CAPTURA 5: la vista reconstruye la relación original
SELECT * FROM v_control_lote_almacen ORDER BY lote_id, deposito_id;


-- -----------------------------------------------------------------------------
-- 6. JUSTIFICACIÓN DE LA UNIÓN SIN PÉRDIDA Y VERIFICACIÓN  (4.2 f)
-- -----------------------------------------------------------------------------
-- Criterio: la descomposición de S en S1 y S2 es sin pérdida si el atributo
-- común (S1 n S2) es superclave de S1 o de S2. Acá:
--     S1 n S2 = {ResponsableControlID}
--     ResponsableControlID es la clave primaria de responsable_deposito (S1),
--     o sea, es superclave de S1: R -> D vale en S1.
-- Como la reunión natural combina cada fila de control_lote con EXACTAMENTE
-- una fila de responsable_deposito (la de su responsable), no puede perder
-- filas ni inventar filas espurias: la reunión reconstruye la relación
-- original. (Si el atributo común no fuera superclave de ninguna de las
-- dos, cada fila podría combinarse con varias y aparecerían filas
-- espurias.)

-- Verificación de la equivalencia, en los DOS sentidos (no alcanza con uno):

-- CAPTURA 6: filas de la original que faltan en la vista (pérdida de datos).
-- Debe devolver 0 filas.
SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
EXCEPT
SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen;

-- CAPTURA 7: filas de la vista que no existen en la original (filas
-- espurias). Debe devolver 0 filas.
SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
EXCEPT
SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen;

-- CAPTURA 8: conteo de filas, verificación complementaria (3 y 3).
SELECT (SELECT COUNT(*) FROM control_lote_almacen) AS antes,
       (SELECT COUNT(*) FROM v_control_lote_almacen) AS despues;


-- -----------------------------------------------------------------------------
-- 7. LIMITACIÓN DE LA DESCOMPOSICIÓN: NO PRESERVA LA DEPENDENCIA F1
-- -----------------------------------------------------------------------------
-- La descomposición es sin pérdida, pero no preserva {L, D} -> R: esa regla
-- ya no se puede verificar con una clave ni una FK de una sola tabla. Es la
-- limitación conocida de FNBC frente a 3FN. Ejemplo: el lote 501 ya tiene
-- como responsable en el depósito 30 al 801; nada impide agregar también al
-- 803 (depósito 30) como responsable del mismo lote:
--
-- En la tabla original esa fila se rechaza (violaría la PK (lote_id,
-- deposito_id)); en el esquema descompuesto se acepta, y la vista devuelve
-- dos responsables para el mismo lote y depósito. Para imponer F1 habría que
-- agregar un trigger o una verificación por consulta.
/*
BEGIN;
INSERT INTO responsable_deposito (responsable_control_id, deposito_id) VALUES (803, 30);
INSERT INTO control_lote (lote_id, responsable_control_id) VALUES (501, 803);

-- CAPTURA 9 (opcional): dos filas para (lote 501, depósito 30)
SELECT * FROM v_control_lote_almacen WHERE lote_id = 501 ORDER BY responsable_control_id;

ROLLBACK;
*/


-- -----------------------------------------------------------------------------
-- 8. REVERSIÓN — "down"
-- -----------------------------------------------------------------------------
-- Elimina la vista y las dos tablas descompuestas. control_lote_almacen,
-- lote, deposito y usuario NO se tocan. Para probarlo: ejecutar este bloque
-- (sin los marcadores de comentario), verificar que desaparecen la vista y
-- las dos tablas, y volver a ejecutar el script completo (empieza con la
-- limpieza y reconstruye todo).
/*
BEGIN;
DROP VIEW  IF EXISTS v_control_lote_almacen;
DROP TABLE IF EXISTS control_lote;
DROP TABLE IF EXISTS responsable_deposito;
COMMIT;
*/
