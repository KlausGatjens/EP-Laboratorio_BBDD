/* =============================================================================
   RESTAURANTE SAZÓN CRIOLLA · Sistema de Reservas de Mesas
   DML 05 · Carga inicial de información (INSERT)
   -----------------------------------------------------------------------------
   Requiere: DDL/01 a DDL/04.

   - Los identificadores se fijan con IDENTITY_INSERT para que la carga sea
     predecible: la colección `comentarios` de MongoDB (repositorio
     EP-Laboratorio_MongoDB) hace referencia a estas mesas, usuarios y reservas.
   - Las fechas de las reservas se calculan a partir del día en que se ejecuta
     el script: siempre hay reservas pasadas (con reseñas) y futuras.
   - Las reservas iniciales se insertan directamente porque las pasadas no
     pasarían la regla "no reservar en el pasado" del procedimiento
     almacenado. Toda reserva nueva de la API usa dbo.RegistrarReserva.

   Re-ejecutable: borra los datos actuales y vuelve a cargarlos.
   ============================================================================= */

USE RestauranteDB;
GO

SET NOCOUNT ON;

/* ---------- Limpieza (orden inverso a las claves foráneas) ---------- */
DELETE FROM dbo.Reservas;
DELETE FROM dbo.Mesas;
DELETE FROM dbo.Usuarios;
DELETE FROM dbo.Zonas;
GO

/* ---------- Zonas ---------- */
SET IDENTITY_INSERT dbo.Zonas ON;

INSERT INTO dbo.Zonas (idZona, nombre, descripcion) VALUES
    (1, N'Salón principal', N'Primer piso, ambiente familiar junto a la cocina abierta'),
    (2, N'Terraza',         N'Al aire libre con vista al parque, ideal para grupos'),
    (3, N'Zona VIP',        N'Ambiente privado para celebraciones y reuniones de negocios'),
    (4, N'Barra',           N'Mesas altas junto a la barra de piscos y cócteles');

SET IDENTITY_INSERT dbo.Zonas OFF;
GO

/* ---------- Mesas ----------
   El número de mesa indica la zona: 1xx salón, 2xx terraza, 3xx VIP, 4xx barra. */
SET IDENTITY_INSERT dbo.Mesas ON;

INSERT INTO dbo.Mesas (idMesa, numero, capacidad, idZona, activa) VALUES
    ( 1, 101,  2, 1, 1),
    ( 2, 102,  2, 1, 1),
    ( 3, 103,  4, 1, 1),
    ( 4, 104,  4, 1, 1),
    ( 5, 105,  6, 1, 1),
    ( 6, 201,  4, 2, 1),
    ( 7, 202,  6, 2, 1),
    ( 8, 203,  8, 2, 1),
    ( 9, 301, 10, 3, 1),
    (10, 302, 12, 3, 1),
    (11, 401,  2, 4, 1),
    (12, 402,  2, 4, 0);  -- fuera de servicio (mantenimiento)

SET IDENTITY_INSERT dbo.Mesas OFF;
GO

/* ---------- Usuarios (clientes) ---------- */
SET IDENTITY_INSERT dbo.Usuarios ON;

INSERT INTO dbo.Usuarios (idUsuario, nombres, apellidos, correo, telefono) VALUES
    (1, N'Lucía',       N'Ramos Quispe',     N'lucia.ramos@correo.pe',     '987654321'),
    (2, N'Carlos',      N'Mendoza Flores',   N'carlos.mendoza@correo.pe',  '986543210'),
    (3, N'Valeria',     N'Torres Huamán',    N'valeria.torres@correo.pe',  '985432109'),
    (4, N'Diego',       N'Salazar Rojas',    N'diego.salazar@correo.pe',   '984321098'),
    (5, N'Camila',      N'Vargas Chávez',    N'camila.vargas@correo.pe',   '983210987'),
    (6, N'Jorge',       N'Castillo Paredes', N'jorge.castillo@correo.pe',  '982109876'),
    (7, N'Andrea',      N'Gutiérrez León',   N'andrea.gutierrez@correo.pe','981098765'),
    (8, N'Miguel Ángel', N'Herrera Soto',    N'miguel.herrera@correo.pe',  '+51980987654');

SET IDENTITY_INSERT dbo.Usuarios OFF;
GO

/* ---------- Reservas ----------
   dia  : días respecto de hoy (negativo = pasado, positivo = futuro).
   hora : hora de inicio en Lima. Se suman 5 horas para guardarla en UTC. */
DECLARE @hoyLima DATETIME2(0) = CAST(CAST(DATEADD(HOUR, -5, SYSUTCDATETIME()) AS DATE) AS DATETIME2(0));

SET IDENTITY_INSERT dbo.Reservas ON;

INSERT INTO dbo.Reservas (idReserva, idMesa, idUsuario, fechaInicio, fechaFin, numeroPersonas, observaciones)
SELECT v.idReserva,
       v.idMesa,
       v.idUsuario,
       DATEADD(HOUR, v.hora + 5, DATEADD(DAY, v.dia, @hoyLima)),
       DATEADD(MINUTE, v.duracion, DATEADD(HOUR, v.hora + 5, DATEADD(DAY, v.dia, @hoyLima))),
       v.personas,
       v.observaciones
FROM (VALUES
    --  id mesa usuario  dia hora duracion(min) personas observaciones
    ( 1,  3, 1, -10, 13,  90, 4, N'Almuerzo familiar'),
    ( 2,  9, 2,  -7, 20, 150, 8, N'Cena de cumpleaños: traerán torta'),
    ( 3,  6, 3,  -5, 19, 120, 3, NULL),
    ( 4, 11, 4,  -3, 21,  90, 2, N'Mesa cerca de la barra'),
    ( 5,  1, 5,  -2, 13,  60, 2, NULL),
    ( 6,  8, 6,  -1, 20, 120, 6, N'Reunión de exalumnos'),
    ( 7,  3, 7,   1, 20, 120, 4, NULL),
    ( 8, 10, 8,   2, 19, 180, 10, N'Aniversario de la empresa'),
    ( 9,  5, 1,   3, 13,  90, 5, N'Necesitan silla para bebé'),
    (10,  6, 2,   5, 21,  90, 2, N'Pedida de mano: decoración con flores')
) AS v (idReserva, idMesa, idUsuario, dia, hora, duracion, personas, observaciones);

SET IDENTITY_INSERT dbo.Reservas OFF;
GO

/* ---------- Verificación ---------- */
SELECT 'Zonas' AS tabla, COUNT(*) AS registros FROM dbo.Zonas
UNION ALL SELECT 'Mesas',    COUNT(*) FROM dbo.Mesas
UNION ALL SELECT 'Usuarios', COUNT(*) FROM dbo.Usuarios
UNION ALL SELECT 'Reservas', COUNT(*) FROM dbo.Reservas;

SELECT idReserva, numeroMesa, zona, cliente, numeroPersonas,
       DATEADD(HOUR, -5, fechaInicio) AS inicioLima,
       DATEADD(HOUR, -5, fechaFin)    AS finLima,
       observaciones
FROM dbo.vw_ReservasDetalle
ORDER BY fechaInicio;
GO
