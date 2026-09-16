# Taller: Consultas de fechas, DateTime e intervalos en PostgreSQL

Resolucion de 35 casos de uso, un reto integrador y un caso avanzado sobre el manejo de
fechas en PostgreSQL, a partir de un escenario de **reservas de espacios de trabajo y
salas de reunion**. Cada consulta esta acompanada de la explicacion de la logica aplicada.

Base de datos: `taller_fechas`. Tabla: `reservas`.

## Contenido del repositorio

| Archivo | Descripcion |
|---|---|
| `taller_fechas_casos_uso.sql` | Script completo: creacion de la tabla, datos de prueba y los 35 casos de uso comentados |
| `README.md` | Este documento |

## Escenario

Una empresa administra reservas de salas. Cada reserva registra el cliente, la sala, la fecha,
el instante de inicio y fin, la fecha de creacion y su estado (`CONFIRMADA`, `PENDIENTE`,
`FINALIZADA`).

```sql
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
```

Se cargan 6 reservas de prueba entre el 10 de septiembre y el 2 de octubre de 2026, todas
con desfase `-05` (hora de Colombia).

### Decisiones de diseno

- `fecha_reserva` es `DATE` porque solo interesa el dia; `fecha_hora_inicio` y
  `fecha_hora_fin` son `TIMESTAMPTZ` porque representan un instante absoluto y permiten
  convertir entre zonas horarias sin ambiguedad.
- El script fija `SET TIME ZONE 'America/Bogota'` al inicio para que `CURRENT_DATE`,
  `CURRENT_TIMESTAMP` y `EXTRACT` se interpreten en la misma zona que el negocio.
- Las consultas que dependen de "hoy" o "ahora" usan `CURRENT_DATE` y `CURRENT_TIMESTAMP`
  en lugar de fechas escritas a mano, para que sigan siendo validas cualquier dia.

## Como ejecutar

Requisitos: contenedor `postgres_db` (imagen `postgres:16`) en Docker Desktop, usuario
`bkseducate`. Desde PowerShell en Windows:

```powershell
docker exec postgres_db psql -U bkseducate -d postgres -c "CREATE DATABASE taller_fechas;"
```

```powershell
docker exec -i postgres_db psql -U bkseducate -d taller_fechas < taller_fechas_casos_uso.sql
```

Para explorar de forma interactiva:

```powershell
docker exec -it postgres_db psql -U bkseducate -d taller_fechas
```

Tambien puede ejecutarse desde pgAdmin abriendo el archivo en el Query Tool sobre la base
`taller_fechas` y ejecutandolo completo.

## Casos de uso resueltos

### Parte 1. Consultas basicas de fecha

| # | Caso de uso | Tecnica |
|---|---|---|
| 1 | Reservas posteriores al 16 de septiembre de 2026 | Comparacion `DATE > DATE 'YYYY-MM-DD'` |
| 2 | Reservas entre el 15 y el 25 de septiembre (ambos incluidos) | `BETWEEN`, que es inclusivo en ambos extremos |
| 3 | Reservas del dia actual | `fecha_reserva = CURRENT_DATE` |

### Parte 2. Fecha y hora

| # | Caso de uso | Tecnica |
|---|---|---|
| 4 | Reservas que todavia no han iniciado | `fecha_hora_inicio > CURRENT_TIMESTAMP` |
| 5 | Reservas que ya finalizaron | `fecha_hora_fin < CURRENT_TIMESTAMP` |
| 6 | Reservas activas en este momento | `inicio <= ahora AND fin >= ahora` |

### Parte 3. Intervalos

| # | Caso de uso | Tecnica |
|---|---|---|
| 7 | Duracion de cada reserva | `TIMESTAMPTZ - TIMESTAMPTZ` produce un `INTERVAL` |
| 8 | Reservas de mas de 2 horas | Comparacion con `INTERVAL '2 hours'` |
| 9 | Fin de las confirmadas con 30 minutos adicionales (solo proyeccion) | `TIMESTAMPTZ + INTERVAL '30 minutes'` |
| 10 | Fecha limite de cancelacion gratuita (24 h antes) | `inicio - INTERVAL '24 hours'`; se usa `'24 hours'` y no `'1 day'` para un lapso exacto |

### Parte 4. Extraccion de componentes

| # | Caso de uso | Tecnica |
|---|---|---|
| 11 | Hora del dia en que comienza cada reserva | `EXTRACT(HOUR FROM ...)` |
| 12 | Anio, mes, dia y hora de inicio | `EXTRACT` con `YEAR`, `MONTH`, `DAY`, `HOUR` |
| 13 | Cantidad de reservas por mes | `GROUP BY` anio y mes con `COUNT(*)` |

### Parte 5. Consultas por periodos

| # | Caso de uso | Tecnica |
|---|---|---|
| 14 | Reservas del mes actual | `DATE_TRUNC('month', fecha) = DATE_TRUNC('month', CURRENT_DATE)` |
| 15 | Reservas creadas durante el anio actual | `EXTRACT(YEAR FROM fecha_creacion) = EXTRACT(YEAR FROM CURRENT_DATE)` |
| 16 | Reservas de la semana actual | `DATE_TRUNC('week', ...)` devuelve el lunes de la semana ISO |

### Parte 6. Formato de fechas

| # | Caso de uso | Tecnica |
|---|---|---|
| 17 | Inicio en formato `DD/MM/YYYY HH24:MI` | `TO_CHAR` |
| 18 | Reporte con el formato `Cliente - Sala - 15/09/2026 08:00` separado por barras verticales | Concatenacion de columnas con el operador de concatenacion y `TO_CHAR` |

### Parte 7. Zonas horarias

| # | Caso de uso | Tecnica |
|---|---|---|
| 19 | Hora de inicio en Colombia y en Madrid | `TIMESTAMPTZ AT TIME ZONE 'zona'`; PostgreSQL resuelve el horario de verano |
| 20 | Fechas de inicio expresadas en UTC | `AT TIME ZONE 'UTC'` |

### Parte 8. Calculos con fechas

| # | Caso de uso | Tecnica |
|---|---|---|
| 21 | Dias que faltan para cada reserva | `DATE - DATE` devuelve `INTEGER` (negativo si ya paso) |
| 22 | Reservas creadas con al menos 5 dias de anticipacion | Se convierte `fecha_creacion::DATE` para restar en dias enteros |
| 23 | Reservas de ultimo minuto (menos de 24 h) | Resta de `TIMESTAMPTZ` comparada con `INTERVAL '24 hours'`, exigiendo anticipacion positiva |

### Parte 9. AGE

| # | Caso de uso | Tecnica |
|---|---|---|
| 24 | Tiempo entre la creacion y el inicio | `AGE(inicio, creacion)` devuelve un intervalo en anios, meses, dias y horas |

### Parte 10. Consultas combinadas

| # | Caso de uso | Tecnica |
|---|---|---|
| 25 | Confirmadas, de mas de 2 h y posteriores a hoy | Tres condiciones con `AND` |
| 26 | Reservas futuras de la Sala A, de la mas proxima a la mas lejana | Filtro por sala y `ORDER BY inicio ASC` |
| 27 | Reserva futura mas cercana | `ORDER BY inicio ASC LIMIT 1` |
| 28 | Reserva futura mas lejana | `ORDER BY inicio DESC LIMIT 1` |

### Parte 11. Agregaciones

| # | Caso de uso | Tecnica |
|---|---|---|
| 29 | Duracion promedio de las reservas | `AVG` sobre `INTERVAL` |
| 30 | Duracion total de todas las reservas | `SUM` sobre `INTERVAL` |
| 31 | Cantidad de reservas por dia | `GROUP BY fecha_reserva` |
| 32 | Reservas por sala en septiembre de 2026 | Rango semiabierto `>= '2026-09-01' AND < '2026-10-01'` |

### Parte 12. Reto de actualizacion

Cada actualizacion va precedida de un `SELECT` con el mismo `WHERE` para verificar que filas
cambiaran antes de ejecutar el `UPDATE`.

| # | Caso de uso | Tecnica |
|---|---|---|
| 33 | Reservas futuras de la Sala A comienzan una hora mas tarde | `UPDATE ... SET inicio = inicio + INTERVAL '1 hour'` |
| 34 | Reservas pendientes extienden su fin 30 minutos | `UPDATE ... SET fin = fin + INTERVAL '30 minutes'` |
| 35 | Marcar como `FINALIZADA` las reservas cuyo fin ya paso | `UPDATE` filtrando `fin < CURRENT_TIMESTAMP AND estado <> 'FINALIZADA'` |

### Parte 13. Reto integrador

Reservas prioritarias: confirmadas, de mas de 3 horas y que inician en los proximos 15 dias.
La ventana se construye con `CURRENT_TIMESTAMP + INTERVAL '15 days'` y la duracion se calcula
una sola vez en una subconsulta.

### Parte 14. Caso de uso avanzado

Reporte gerencial con fecha formateada (`DD/MM/YYYY`), hora de inicio (`HH24:MI`), duracion,
dias para la reserva y estado, ordenado por la columna `TIMESTAMPTZ` original para que el
orden sea cronologico real y no alfabetico sobre el texto formateado.

## Conceptos clave aplicados

| Concepto | Descripcion |
|---|---|
| `DATE` vs `TIMESTAMPTZ` | Dia calendario frente a instante absoluto con zona horaria |
| `INTERVAL` | Tipo para duraciones; resulta de restar dos timestamps y se puede sumar, restar, promediar y comparar |
| `CURRENT_DATE` / `CURRENT_TIMESTAMP` | Fecha y momento actuales de la sesion; evitan escribir fechas a mano |
| `EXTRACT` | Obtiene un componente (anio, mes, dia, hora) de una fecha |
| `DATE_TRUNC` | Lleva una fecha al inicio de su periodo (mes, semana) para comparar periodos completos |
| `TO_CHAR` | Convierte fecha a texto con una plantilla de formato |
| `AT TIME ZONE` | Convierte un instante a la hora local de otra zona |
| `AGE` | Diferencia entre fechas expresada en anios, meses, dias y horas |
| Rango semiabierto | `>= inicio AND < fin` es la forma mas segura de acotar un mes completo |

## Herramientas

- PostgreSQL 16 en Docker Desktop, `psql`, pgAdmin 4
- PowerShell para la ejecucion de los scripts
