-- =====================================================================
-- TALLER PRÁCTICO: Consultas de fechas, DateTime e Intervalos
--                  a partir de casos de uso
-- Escenario: reservas de espacios de trabajo y salas de reunión
-- Base de datos: taller_fechas
-- =====================================================================
--
-- Cómo ejecutar (desde la máquina host, con el contenedor postgres_db arriba):
--
--   docker exec postgres_db psql -U bkseducate -d postgres -c "CREATE DATABASE taller_fechas;"
--   docker exec -i postgres_db psql -U bkseducate -d taller_fechas < taller_fechas_casos_uso.sql
--
-- La sesión trabaja en hora de Colombia (UTC-5). Los datos de prueba están
-- escritos con desfase -05, así que CURRENT_DATE / CURRENT_TIMESTAMP se
-- interpretan en la misma zona que el negocio.
-- =====================================================================

SET TIME ZONE 'America/Bogota';


-- =====================================================
-- Preparación: tabla y datos de prueba del escenario
-- =====================================================

DROP TABLE IF EXISTS reservas;

CREATE TABLE reservas (
    id                SERIAL PRIMARY KEY,
    cliente           VARCHAR(100) NOT NULL,
    sala              VARCHAR(80)  NOT NULL,
    fecha_reserva     DATE         NOT NULL,
    fecha_hora_inicio TIMESTAMPTZ  NOT NULL,
    fecha_hora_fin    TIMESTAMPTZ  NOT NULL,
    fecha_creacion    TIMESTAMPTZ  DEFAULT CURRENT_TIMESTAMP,
    estado            VARCHAR(30)  NOT NULL
);

INSERT INTO reservas
(cliente, sala, fecha_reserva, fecha_hora_inicio, fecha_hora_fin, estado)
VALUES
('Ana Torres',   'Sala A', '2026-09-15', '2026-09-15 08:00:00-05', '2026-09-15 10:00:00-05', 'CONFIRMADA'),
('Carlos Pérez', 'Sala B', '2026-09-16', '2026-09-16 14:30:00-05', '2026-09-16 16:00:00-05', 'CONFIRMADA'),
('Laura Gómez',  'Sala A', '2026-09-20', '2026-09-20 09:00:00-05', '2026-09-20 12:30:00-05', 'PENDIENTE'),
('Miguel Rojas', 'Sala C', '2026-09-10', '2026-09-10 13:00:00-05', '2026-09-10 15:00:00-05', 'FINALIZADA'),
('Diana Ruiz',   'Sala B', '2026-09-25', '2026-09-25 07:30:00-05', '2026-09-25 11:00:00-05', 'CONFIRMADA'),
('Andrés López', 'Sala A', '2026-10-02', '2026-10-02 15:00:00-05', '2026-10-02 18:30:00-05', 'PENDIENTE');


-- #####################################################################
-- PARTE 1. Consultas básicas de fecha
-- #####################################################################

-- =====================================================
-- Caso de uso 1
-- Reservas posteriores al 16 de septiembre de 2026
-- =====================================================
-- Lógica: fecha_reserva es DATE, así que se compara directamente contra
-- un literal de fecha en formato ISO (YYYY-MM-DD). El operador > excluye
-- el día 16.

SELECT id, cliente, sala, fecha_reserva
FROM reservas
WHERE fecha_reserva > DATE '2026-09-16'
ORDER BY fecha_reserva;


-- =====================================================
-- Caso de uso 2
-- Reservas entre el 15 y el 25 de septiembre de 2026 (ambos incluidos)
-- =====================================================
-- Lógica: BETWEEN es inclusivo en ambos extremos, por eso encaja con el
-- requisito "incluyendo ambas fechas". Equivale a >= '2026-09-15' AND <= '2026-09-25'.

SELECT id, cliente, sala, fecha_reserva
FROM reservas
WHERE fecha_reserva BETWEEN DATE '2026-09-15' AND DATE '2026-09-25'
ORDER BY fecha_reserva;


-- =====================================================
-- Caso de uso 3
-- Reservas del día actual
-- =====================================================
-- Lógica: CURRENT_DATE devuelve la fecha del servidor en la zona de la
-- sesión; nunca se escribe la fecha a mano, así la consulta sirve cualquier día.

SELECT id, cliente, sala, fecha_reserva
FROM reservas
WHERE fecha_reserva = CURRENT_DATE;


-- #####################################################################
-- PARTE 2. Fecha y hora
-- #####################################################################

-- =====================================================
-- Caso de uso 4
-- Reservas que todavía no han iniciado
-- =====================================================
-- Lógica: fecha_hora_inicio es TIMESTAMPTZ, por lo que se compara con
-- CURRENT_TIMESTAMP (también TIMESTAMPTZ). Si el inicio está en el futuro,
-- la reserva aún no ha comenzado.

SELECT id, cliente, sala, fecha_hora_inicio
FROM reservas
WHERE fecha_hora_inicio > CURRENT_TIMESTAMP
ORDER BY fecha_hora_inicio;


-- =====================================================
-- Caso de uso 5
-- Reservas que ya finalizaron
-- =====================================================
-- Lógica: una reserva terminó cuando su fecha_hora_fin quedó en el pasado.

SELECT cliente, sala, fecha_hora_inicio, fecha_hora_fin
FROM reservas
WHERE fecha_hora_fin < CURRENT_TIMESTAMP
ORDER BY fecha_hora_fin;


-- =====================================================
-- Caso de uso 6
-- Reservas activas en este momento
-- =====================================================
-- Lógica: el instante actual debe estar dentro del rango [inicio, fin].
-- Se puede escribir con dos comparaciones o con BETWEEN sobre CURRENT_TIMESTAMP.

SELECT id, cliente, sala, fecha_hora_inicio, fecha_hora_fin
FROM reservas
WHERE fecha_hora_inicio <= CURRENT_TIMESTAMP
  AND fecha_hora_fin    >= CURRENT_TIMESTAMP;


-- #####################################################################
-- PARTE 3. Intervalos
-- #####################################################################

-- =====================================================
-- Caso de uso 7
-- Duración de cada reserva
-- =====================================================
-- Lógica: restar dos TIMESTAMPTZ produce un INTERVAL, que es exactamente
-- el tipo adecuado para representar una duración.

SELECT cliente, sala, fecha_hora_fin - fecha_hora_inicio AS duracion
FROM reservas
ORDER BY duracion DESC;


-- =====================================================
-- Caso de uso 8
-- Reservas largas (más de 2 horas)
-- =====================================================
-- Lógica: el INTERVAL resultante de la resta se compara contra el
-- literal INTERVAL '2 hours'.

SELECT cliente, sala, fecha_hora_fin - fecha_hora_inicio AS duracion
FROM reservas
WHERE fecha_hora_fin - fecha_hora_inicio > INTERVAL '2 hours'
ORDER BY duracion DESC;


-- =====================================================
-- Caso de uso 9
-- Reservas confirmadas con 30 minutos adicionales (solo proyección)
-- =====================================================
-- Lógica: TIMESTAMPTZ + INTERVAL devuelve un nuevo TIMESTAMPTZ. Es un
-- SELECT: se muestra el valor propuesto sin tocar la tabla.

SELECT cliente,
       fecha_hora_fin,
       fecha_hora_fin + INTERVAL '30 minutes' AS nueva_fecha_hora_fin
FROM reservas
WHERE estado = 'CONFIRMADA';


-- =====================================================
-- Caso de uso 10
-- Fecha límite de cancelación gratuita (24 horas antes del inicio)
-- =====================================================
-- Lógica: restar un INTERVAL de 24 horas al inicio. Se usa '24 hours' y
-- no '1 day' para que sea un lapso exacto y no dependa de cambios de
-- horario de verano.

SELECT cliente,
       fecha_hora_inicio,
       fecha_hora_inicio - INTERVAL '24 hours' AS fecha_limite_cancelacion
FROM reservas
ORDER BY fecha_hora_inicio;


-- #####################################################################
-- PARTE 4. Extracción de componentes
-- #####################################################################

-- =====================================================
-- Caso de uso 11
-- Hora del día en que comienza cada reserva
-- =====================================================
-- Lógica: EXTRACT(HOUR FROM ...) devuelve la hora (0-23) del timestamp,
-- interpretada en la zona horaria de la sesión (America/Bogota).

SELECT cliente, EXTRACT(HOUR FROM fecha_hora_inicio) AS hora_inicio
FROM reservas
ORDER BY hora_inicio;


-- =====================================================
-- Caso de uso 12
-- Año, mes, día y hora de fecha_hora_inicio
-- =====================================================
-- Lógica: EXTRACT con cada campo (YEAR, MONTH, DAY, HOUR). Se usan alias
-- sin tilde para evitar tener que entrecomillar identificadores.

SELECT cliente,
       EXTRACT(YEAR  FROM fecha_hora_inicio) AS anio,
       EXTRACT(MONTH FROM fecha_hora_inicio) AS mes,
       EXTRACT(DAY   FROM fecha_hora_inicio) AS dia,
       EXTRACT(HOUR  FROM fecha_hora_inicio) AS hora
FROM reservas
ORDER BY fecha_hora_inicio;


-- =====================================================
-- Caso de uso 13
-- Cantidad de reservas por mes
-- =====================================================
-- Lógica: se agrupa por año y mes (ambos, para no mezclar septiembre de
-- distintos años) y se cuenta con COUNT(*).

SELECT EXTRACT(YEAR  FROM fecha_reserva) AS anio,
       EXTRACT(MONTH FROM fecha_reserva) AS mes,
       COUNT(*)                          AS cantidad_reservas
FROM reservas
GROUP BY anio, mes
ORDER BY anio, mes;


-- #####################################################################
-- PARTE 5. Consultas por períodos
-- #####################################################################

-- =====================================================
-- Caso de uso 14
-- Reservas del mes actual
-- =====================================================
-- Lógica: DATE_TRUNC('month', x) lleva cualquier fecha al día 1 de su mes.
-- Si el mes truncado de la reserva coincide con el mes truncado de hoy,
-- pertenece al mes en curso. Funciona en cualquier mes sin escribir fechas.

SELECT id, cliente, sala, fecha_reserva
FROM reservas
WHERE DATE_TRUNC('month', fecha_reserva) = DATE_TRUNC('month', CURRENT_DATE)
ORDER BY fecha_reserva;


-- =====================================================
-- Caso de uso 15
-- Reservas creadas durante el año actual
-- =====================================================
-- Lógica: se compara el año de fecha_creacion con el año de CURRENT_DATE
-- mediante EXTRACT(YEAR ...). "Creadas" apunta a fecha_creacion, no a
-- fecha_reserva.

SELECT id, cliente, sala, fecha_creacion
FROM reservas
WHERE EXTRACT(YEAR FROM fecha_creacion) = EXTRACT(YEAR FROM CURRENT_DATE)
ORDER BY fecha_creacion;


-- =====================================================
-- Caso de uso 16
-- Reservas de la semana actual
-- =====================================================
-- Lógica: DATE_TRUNC('week', x) devuelve el lunes de la semana de x
-- (semana ISO). Comparar el lunes de la reserva con el lunes de hoy
-- identifica la semana en curso.

SELECT id, cliente, sala, fecha_reserva,
       DATE_TRUNC('week', fecha_reserva)::DATE AS lunes_de_la_semana
FROM reservas
WHERE DATE_TRUNC('week', fecha_reserva) = DATE_TRUNC('week', CURRENT_DATE)
ORDER BY fecha_reserva;


-- #####################################################################
-- PARTE 6. Formato de fechas
-- #####################################################################

-- =====================================================
-- Caso de uso 17
-- Fecha y hora de inicio con formato DD/MM/YYYY HH24:MI
-- =====================================================
-- Lógica: TO_CHAR convierte el timestamp a texto usando una plantilla.
-- HH24 es hora en formato 24 h y MI son los minutos.

SELECT cliente,
       TO_CHAR(fecha_hora_inicio, 'DD/MM/YYYY HH24:MI') AS inicio_formateado
FROM reservas
ORDER BY fecha_hora_inicio;


-- =====================================================
-- Caso de uso 18
-- Reporte "Cliente | Sala | 15/09/2026 08:00"
-- =====================================================
-- Lógica: se concatenan columnas de texto con el operador || y en medio
-- el separador ' | '; la fecha se formatea con TO_CHAR antes de concatenar.

SELECT cliente || ' | ' || sala || ' | ' ||
       TO_CHAR(fecha_hora_inicio, 'DD/MM/YYYY HH24:MI') AS reporte
FROM reservas
ORDER BY fecha_hora_inicio;


-- #####################################################################
-- PARTE 7. Zonas horarias
-- #####################################################################

-- =====================================================
-- Caso de uso 19
-- Hora de inicio en Colombia y en Madrid
-- =====================================================
-- Lógica: fecha_hora_inicio es TIMESTAMPTZ (un instante absoluto).
-- TIMESTAMPTZ AT TIME ZONE 'zona' devuelve un TIMESTAMP (sin zona) con la
-- hora local de esa zona. Madrid está 6 o 7 horas adelante de Bogotá
-- según el horario de verano europeo; PostgreSQL lo resuelve solo.

SELECT cliente,
       fecha_hora_inicio AT TIME ZONE 'America/Bogota' AS hora_colombia,
       fecha_hora_inicio AT TIME ZONE 'Europe/Madrid'  AS hora_madrid
FROM reservas
ORDER BY fecha_hora_inicio;


-- =====================================================
-- Caso de uso 20
-- Fechas de inicio expresadas en UTC
-- =====================================================
-- Lógica: misma operación pero con la zona 'UTC'. Como los datos están
-- en -05, la hora UTC aparece 5 horas después.

SELECT cliente,
       fecha_hora_inicio                    AS inicio_sesion,
       fecha_hora_inicio AT TIME ZONE 'UTC' AS inicio_utc
FROM reservas
ORDER BY fecha_hora_inicio;


-- #####################################################################
-- PARTE 8. Cálculos con fechas
-- #####################################################################

-- =====================================================
-- Caso de uso 21
-- Días que faltan para cada reserva
-- =====================================================
-- Lógica: DATE - DATE devuelve un INTEGER con el número de días.
-- Las reservas pasadas dan valores negativos, como indica el enunciado.

SELECT cliente,
       fecha_reserva,
       fecha_reserva - CURRENT_DATE AS dias_faltantes
FROM reservas
ORDER BY dias_faltantes;


-- =====================================================
-- Caso de uso 22
-- Reservas creadas con al menos 5 días de anticipación
-- =====================================================
-- Lógica: fecha_reserva es DATE y fecha_creacion es TIMESTAMPTZ; no se
-- pueden restar directamente en días enteros. Se convierte fecha_creacion
-- a DATE (::DATE) para que la resta devuelva un INTEGER de días.

SELECT cliente,
       fecha_reserva,
       fecha_creacion::DATE                 AS fecha_creacion,
       fecha_reserva - fecha_creacion::DATE AS dias_anticipacion
FROM reservas
WHERE fecha_reserva - fecha_creacion::DATE >= 5
ORDER BY dias_anticipacion DESC;


-- =====================================================
-- Caso de uso 23
-- Reservas de último minuto (menos de 24 horas de anticipación)
-- =====================================================
-- Lógica: aquí sí conviene precisión de horas, así que se restan los dos
-- TIMESTAMPTZ (inicio - creación) y el INTERVAL se compara con '24 hours'.
-- Se exige además que la anticipación sea positiva: una reserva creada
-- después de su inicio no es "de último minuto", es una reserva pasada.

SELECT cliente,
       fecha_hora_inicio,
       fecha_creacion,
       fecha_hora_inicio - fecha_creacion AS anticipacion
FROM reservas
WHERE fecha_hora_inicio - fecha_creacion <  INTERVAL '24 hours'
  AND fecha_hora_inicio - fecha_creacion >= INTERVAL '0'
ORDER BY anticipacion;


-- #####################################################################
-- PARTE 9. AGE
-- #####################################################################

-- =====================================================
-- Caso de uso 24
-- Tiempo transcurrido desde la creación hasta el inicio de la reserva
-- =====================================================
-- Lógica: AGE(fin, inicio) devuelve un INTERVAL "humano" (años, meses,
-- días, horas...) en lugar de solo días y horas como la resta simple.
-- Con el orden AGE(fecha_hora_inicio, fecha_creacion) el resultado es
-- positivo para reservas futuras y negativo para las ya pasadas.

SELECT cliente,
       AGE(fecha_hora_inicio, fecha_creacion) AS tiempo_anticipacion
FROM reservas
ORDER BY fecha_hora_inicio;


-- #####################################################################
-- PARTE 10. Consultas combinadas
-- #####################################################################

-- =====================================================
-- Caso de uso 25
-- Confirmadas + duración > 2 h + fecha posterior a hoy
-- =====================================================
-- Lógica: tres condiciones unidas con AND: igualdad de texto, comparación
-- de INTERVAL y comparación de DATE contra CURRENT_DATE.

SELECT id, cliente, sala, fecha_reserva, estado,
       fecha_hora_fin - fecha_hora_inicio AS duracion
FROM reservas
WHERE estado = 'CONFIRMADA'
  AND fecha_hora_fin - fecha_hora_inicio > INTERVAL '2 hours'
  AND fecha_reserva > CURRENT_DATE;


-- =====================================================
-- Caso de uso 26
-- Reservas futuras de la Sala A, de la más próxima a la más lejana
-- =====================================================
-- Lógica: filtro por sala y por inicio futuro; ORDER BY ascendente sobre
-- fecha_hora_inicio pone primero la más cercana.

SELECT id, cliente, sala, fecha_hora_inicio, estado
FROM reservas
WHERE sala = 'Sala A'
  AND fecha_hora_inicio > CURRENT_TIMESTAMP
ORDER BY fecha_hora_inicio ASC;


-- =====================================================
-- Caso de uso 27
-- Reserva futura más cercana (un solo registro)
-- =====================================================
-- Lógica: mismo filtro de futuro, orden ascendente y LIMIT 1.

SELECT id, cliente, sala, fecha_hora_inicio, estado
FROM reservas
WHERE fecha_hora_inicio > CURRENT_TIMESTAMP
ORDER BY fecha_hora_inicio ASC
LIMIT 1;


-- =====================================================
-- Caso de uso 28
-- Reserva futura más lejana
-- =====================================================
-- Lógica: igual que el anterior pero con orden descendente.

SELECT id, cliente, sala, fecha_hora_inicio, estado
FROM reservas
WHERE fecha_hora_inicio > CURRENT_TIMESTAMP
ORDER BY fecha_hora_inicio DESC
LIMIT 1;


-- #####################################################################
-- PARTE 11. Agregaciones
-- #####################################################################

-- =====================================================
-- Caso de uso 29
-- Duración promedio de las reservas
-- =====================================================
-- Lógica: AVG acepta INTERVAL y devuelve un INTERVAL promedio.

SELECT AVG(fecha_hora_fin - fecha_hora_inicio) AS duracion_promedio
FROM reservas;


-- =====================================================
-- Caso de uso 30
-- Duración total de todas las reservas
-- =====================================================
-- Lógica: SUM también funciona sobre INTERVAL.

SELECT SUM(fecha_hora_fin - fecha_hora_inicio) AS duracion_total
FROM reservas;


-- =====================================================
-- Caso de uso 31
-- Cantidad de reservas por día
-- =====================================================
-- Lógica: fecha_reserva ya es DATE, así que sirve directamente como
-- clave de agrupación.

SELECT fecha_reserva AS fecha,
       COUNT(*)      AS cantidad_reservas
FROM reservas
GROUP BY fecha_reserva
ORDER BY fecha;


-- =====================================================
-- Caso de uso 32
-- Cantidad de reservas por sala en septiembre de 2026
-- =====================================================
-- Lógica: se acota el mes con un rango semiabierto [1 sep, 1 oct), que
-- es la forma más segura de filtrar un mes completo, y se agrupa por sala.

SELECT sala,
       COUNT(*) AS cantidad_reservas
FROM reservas
WHERE fecha_reserva >= DATE '2026-09-01'
  AND fecha_reserva <  DATE '2026-10-01'
GROUP BY sala
ORDER BY sala;


-- #####################################################################
-- PARTE 12. Reto de actualización
-- #####################################################################

-- =====================================================
-- Caso de uso 33
-- Reservas futuras de la Sala A comienzan una hora más tarde
-- =====================================================
-- Lógica: primero el SELECT con el mismo WHERE para ver qué filas
-- cambiarán; luego el UPDATE suma INTERVAL '1 hour' al inicio.
-- Solo se mueve el inicio (así lo pide el enunciado), por lo que la
-- duración de esas reservas se reduce en una hora.

-- Verificación previa:
SELECT id, cliente, sala, fecha_hora_inicio,
       fecha_hora_inicio + INTERVAL '1 hour' AS nuevo_inicio
FROM reservas
WHERE sala = 'Sala A'
  AND fecha_hora_inicio > CURRENT_TIMESTAMP;

-- Actualización:
UPDATE reservas
SET fecha_hora_inicio = fecha_hora_inicio + INTERVAL '1 hour'
WHERE sala = 'Sala A'
  AND fecha_hora_inicio > CURRENT_TIMESTAMP;


-- =====================================================
-- Caso de uso 34
-- Reservas pendientes extienden su fin 30 minutos
-- =====================================================
-- Lógica: mismo patrón SELECT -> UPDATE, filtrando por estado.

-- Verificación previa:
SELECT id, cliente, estado, fecha_hora_fin,
       fecha_hora_fin + INTERVAL '30 minutes' AS nuevo_fin
FROM reservas
WHERE estado = 'PENDIENTE';

-- Actualización:
UPDATE reservas
SET fecha_hora_fin = fecha_hora_fin + INTERVAL '30 minutes'
WHERE estado = 'PENDIENTE';


-- =====================================================
-- Caso de uso 35
-- Marcar como FINALIZADA las reservas cuyo fin ya pasó
-- =====================================================
-- Lógica: se comparan fecha_hora_fin con CURRENT_TIMESTAMP. Se excluyen
-- las que ya están FINALIZADA para no reescribir filas sin cambio.

-- Verificación previa:
SELECT id, cliente, estado, fecha_hora_fin
FROM reservas
WHERE fecha_hora_fin < CURRENT_TIMESTAMP
  AND estado <> 'FINALIZADA';

-- Actualización:
UPDATE reservas
SET estado = 'FINALIZADA'
WHERE fecha_hora_fin < CURRENT_TIMESTAMP
  AND estado <> 'FINALIZADA';

-- Estado de la tabla después de las actualizaciones:
SELECT id, cliente, sala, fecha_hora_inicio, fecha_hora_fin, estado
FROM reservas
ORDER BY fecha_hora_inicio;


-- #####################################################################
-- PARTE 13. Reto integrador
-- #####################################################################

-- =====================================================
-- Reto integrador
-- Reservas prioritarias: confirmadas, > 3 horas, inician en los próximos 15 días
-- =====================================================
-- Lógica: "próximos 15 días" es la ventana entre ahora y ahora + 15 días,
-- construida con CURRENT_TIMESTAMP + INTERVAL '15 days'. El inicio debe
-- ser mayor que ahora (todavía no empezó) y menor o igual al límite.
-- La duración se calcula una vez en una subconsulta para no repetir la resta.

SELECT id, cliente, sala, fecha_hora_inicio, fecha_hora_fin, duracion
FROM (
    SELECT id, cliente, sala, fecha_hora_inicio, fecha_hora_fin, estado,
           fecha_hora_fin - fecha_hora_inicio AS duracion
    FROM reservas
) r
WHERE estado = 'CONFIRMADA'
  AND duracion > INTERVAL '3 hours'
  AND fecha_hora_inicio >  CURRENT_TIMESTAMP
  AND fecha_hora_inicio <= CURRENT_TIMESTAMP + INTERVAL '15 days'
ORDER BY fecha_hora_inicio;


-- #####################################################################
-- PARTE 14. Caso de uso avanzado
-- #####################################################################

-- =====================================================
-- Caso de uso avanzado
-- Reporte gerencial de reservas
-- =====================================================
-- Lógica:
--   fecha_formateada  -> TO_CHAR(fecha_hora_inicio, 'DD/MM/YYYY')
--   hora_inicio       -> TO_CHAR(fecha_hora_inicio, 'HH24:MI') (solo hora y minutos)
--   duracion          -> INTERVAL de fin - inicio
--   dias_para_reserva -> DATE - DATE = INTEGER de días (negativo si ya pasó)
--   ORDER BY sobre la columna TIMESTAMPTZ original, no sobre el texto
--   formateado, para que el orden sea cronológico real.

SELECT cliente,
       sala,
       TO_CHAR(fecha_hora_inicio, 'DD/MM/YYYY') AS fecha_formateada,
       TO_CHAR(fecha_hora_inicio, 'HH24:MI')    AS hora_inicio,
       fecha_hora_fin - fecha_hora_inicio       AS duracion,
       fecha_reserva - CURRENT_DATE             AS dias_para_reserva,
       estado
FROM reservas
ORDER BY fecha_hora_inicio;
