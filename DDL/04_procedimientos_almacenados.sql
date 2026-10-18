/* =============================================================================
   RESTAURANTE SAZÓN CRIOLLA · Sistema de Reservas de Mesas
   DDL 04 · Procedimientos almacenados
   -----------------------------------------------------------------------------
   Requiere: DDL/01, DDL/02 y DDL/03.

     dbo.RegistrarReserva  : registra una reserva (procedimiento principal).
     dbo.ActualizarReserva : reprograma o cambia una reserva futura.
     dbo.CancelarReserva   : cancela (elimina) una reserva futura.

   Los tres trabajan dentro de una TRANSACCIÓN con SET XACT_ABORT ON y
   TRY/CATCH: ante cualquier error se hace ROLLBACK y no queda nada a medias.

   Reglas del negocio:
     - Horario de atención: 12:00 a 23:00 (hora de Lima).
     - Duración de una reserva: de 30 minutos a 4 horas.
     - No se reserva en el pasado.
     - La mesa debe existir, estar activa y tener capacidad suficiente.
     - Una mesa no puede tener dos reservas que se crucen.
     - Un cliente no puede tener dos reservas que se crucen.
     - Solo se modifican o cancelan reservas que todavía no empiezan.

   Códigos de error (THROW) que la API traduce a códigos HTTP:
     50001 -> 400  Fechas inválidas (vacías o fin <= inicio)
     50002 -> 400  La fecha de la reserva ya pasó
     50003 -> 400  Duración fuera del rango permitido
     50004 -> 400  Fuera del horario de atención
     50005 -> 404  La mesa no existe
     50006 -> 409  La mesa está fuera de servicio
     50007 -> 404  El usuario no existe
     50008 -> 409  La mesa no tiene capacidad para ese número de personas
     50009 -> 409  La mesa ya está reservada en ese horario
     50010 -> 409  El usuario ya tiene otra reserva en ese horario
     50011 -> 404  La reserva no existe
     50012 -> 409  La reserva ya inició o terminó (no se puede cambiar)
   ============================================================================= */

USE RestauranteDB;
GO

/* =============================================================================
   dbo.RegistrarReserva
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.RegistrarReserva
    @idMesa         INT,
    @idUsuario      INT,
    @fechaInicio    DATETIME2(0),          -- UTC
    @fechaFin       DATETIME2(0),          -- UTC
    @numeroPersonas INT,
    @observaciones  NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;  -- cualquier error revierte la transacción completa

    -- Parámetros del negocio
    DECLARE @apertura       TIME(0) = '12:00',
            @cierre         TIME(0) = '23:00',
            @duracionMinima INT     = 30,   -- minutos
            @duracionMaxima INT     = 240,  -- minutos
            @horasLima      INT     = -5;   -- Lima = UTC-5 todo el año (sin horario de verano)

    DECLARE @inicioLima DATETIME2(0) = DATEADD(HOUR, @horasLima, @fechaInicio),
            @finLima    DATETIME2(0) = DATEADD(HOUR, @horasLima, @fechaFin),
            @capacidad  TINYINT,
            @activa     BIT,
            @idReserva  INT,
            @mensaje    NVARCHAR(200);

    BEGIN TRY
        BEGIN TRANSACTION;

        /* 1. Fechas */
        IF @fechaInicio IS NULL OR @fechaFin IS NULL OR @fechaFin <= @fechaInicio
            THROW 50001, N'Las fechas de la reserva no son válidas', 1;

        IF @fechaInicio <= SYSUTCDATETIME()
            THROW 50002, N'No se puede reservar en una fecha u hora pasada', 1;

        IF DATEDIFF(MINUTE, @fechaInicio, @fechaFin) NOT BETWEEN @duracionMinima AND @duracionMaxima
            THROW 50003, N'La reserva debe durar entre 30 minutos y 4 horas', 1;

        IF CAST(@inicioLima AS DATE) <> CAST(@finLima AS DATE)
           OR CAST(@inicioLima AS TIME(0)) < @apertura
           OR CAST(@finLima AS TIME(0)) > @cierre
            THROW 50004, N'La reserva está fuera del horario de atención (12:00 a 23:00, hora de Lima)', 1;

        /* 2. Mesa: debe existir y estar activa.
              UPDLOCK + HOLDLOCK bloquea la fila de la mesa hasta el COMMIT, así dos
              peticiones simultáneas no pueden reservar la misma mesa (condición de carrera). */
        SELECT @capacidad = capacidad,
               @activa    = activa
        FROM dbo.Mesas WITH (UPDLOCK, HOLDLOCK)
        WHERE idMesa = @idMesa;

        IF @capacidad IS NULL
            THROW 50005, N'La mesa no existe', 1;

        IF @activa = 0
            THROW 50006, N'La mesa está fuera de servicio', 1;

        /* 3. Usuario: también se bloquea para que un cliente no registre dos reservas
              cruzadas al mismo tiempo desde dos peticiones. */
        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WITH (UPDLOCK, HOLDLOCK) WHERE idUsuario = @idUsuario)
            THROW 50007, N'El usuario no existe', 1;

        /* 4. Capacidad de la mesa */
        IF @numeroPersonas > @capacidad
        BEGIN
            SET @mensaje = CONCAT(N'La mesa admite como máximo ', @capacidad, N' personas');
            THROW 50008, @mensaje, 1;
        END;

        /* 5. Disponibilidad de la mesa.
              Dos intervalos se cruzan si uno empieza antes de que el otro termine. */
        IF EXISTS (SELECT 1 FROM dbo.Reservas
                   WHERE idMesa      = @idMesa
                     AND fechaInicio < @fechaFin
                     AND fechaFin    > @fechaInicio)
            THROW 50009, N'La mesa ya está reservada en ese horario', 1;

        /* 6. El cliente no puede estar en dos mesas a la vez */
        IF EXISTS (SELECT 1 FROM dbo.Reservas
                   WHERE idUsuario   = @idUsuario
                     AND fechaInicio < @fechaFin
                     AND fechaFin    > @fechaInicio)
            THROW 50010, N'El usuario ya tiene otra reserva en ese horario', 1;

        /* 7. Registro */
        INSERT INTO dbo.Reservas (idMesa, idUsuario, fechaInicio, fechaFin, numeroPersonas, observaciones)
        VALUES (@idMesa, @idUsuario, @fechaInicio, @fechaFin, @numeroPersonas,
                NULLIF(LTRIM(RTRIM(@observaciones)), N''));

        SET @idReserva = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        -- Devuelve la reserva registrada con los datos de la mesa y del cliente.
        SELECT idReserva, idMesa, numeroMesa, zona, idUsuario, cliente, correoCliente,
               fechaInicio, fechaFin, numeroPersonas, observaciones, fechaCreacion
        FROM dbo.vw_ReservasDetalle
        WHERE idReserva = @idReserva;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;  -- relanza el error original para que la API lo traduzca a HTTP
    END CATCH;
END;
GO

/* =============================================================================
   dbo.ActualizarReserva: reemplaza los datos de una reserva que aún no empieza.
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.ActualizarReserva
    @idReserva      INT,
    @idMesa         INT,
    @idUsuario      INT,
    @fechaInicio    DATETIME2(0),          -- UTC
    @fechaFin       DATETIME2(0),          -- UTC
    @numeroPersonas INT,
    @observaciones  NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @apertura       TIME(0) = '12:00',
            @cierre         TIME(0) = '23:00',
            @duracionMinima INT     = 30,
            @duracionMaxima INT     = 240,
            @horasLima      INT     = -5;

    DECLARE @inicioLima   DATETIME2(0) = DATEADD(HOUR, @horasLima, @fechaInicio),
            @finLima      DATETIME2(0) = DATEADD(HOUR, @horasLima, @fechaFin),
            @inicioActual DATETIME2(0),
            @capacidad    TINYINT,
            @activa       BIT,
            @mensaje      NVARCHAR(200);

    BEGIN TRY
        BEGIN TRANSACTION;

        /* 1. La reserva existe y todavía no empieza */
        SELECT @inicioActual = fechaInicio
        FROM dbo.Reservas WITH (UPDLOCK, HOLDLOCK)
        WHERE idReserva = @idReserva;

        IF @inicioActual IS NULL
            THROW 50011, N'La reserva no existe', 1;

        IF @inicioActual <= SYSUTCDATETIME()
            THROW 50012, N'La reserva ya inició o terminó: no se puede modificar', 1;

        /* 2. Fechas nuevas (mismas reglas que al registrar) */
        IF @fechaInicio IS NULL OR @fechaFin IS NULL OR @fechaFin <= @fechaInicio
            THROW 50001, N'Las fechas de la reserva no son válidas', 1;

        IF @fechaInicio <= SYSUTCDATETIME()
            THROW 50002, N'No se puede reservar en una fecha u hora pasada', 1;

        IF DATEDIFF(MINUTE, @fechaInicio, @fechaFin) NOT BETWEEN @duracionMinima AND @duracionMaxima
            THROW 50003, N'La reserva debe durar entre 30 minutos y 4 horas', 1;

        IF CAST(@inicioLima AS DATE) <> CAST(@finLima AS DATE)
           OR CAST(@inicioLima AS TIME(0)) < @apertura
           OR CAST(@finLima AS TIME(0)) > @cierre
            THROW 50004, N'La reserva está fuera del horario de atención (12:00 a 23:00, hora de Lima)', 1;

        /* 3. Mesa y usuario */
        SELECT @capacidad = capacidad,
               @activa    = activa
        FROM dbo.Mesas WITH (UPDLOCK, HOLDLOCK)
        WHERE idMesa = @idMesa;

        IF @capacidad IS NULL
            THROW 50005, N'La mesa no existe', 1;

        IF @activa = 0
            THROW 50006, N'La mesa está fuera de servicio', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WITH (UPDLOCK, HOLDLOCK) WHERE idUsuario = @idUsuario)
            THROW 50007, N'El usuario no existe', 1;

        IF @numeroPersonas > @capacidad
        BEGIN
            SET @mensaje = CONCAT(N'La mesa admite como máximo ', @capacidad, N' personas');
            THROW 50008, @mensaje, 1;
        END;

        /* 4. Cruces de horario (se excluye la propia reserva) */
        IF EXISTS (SELECT 1 FROM dbo.Reservas
                   WHERE idMesa      = @idMesa
                     AND idReserva   <> @idReserva
                     AND fechaInicio < @fechaFin
                     AND fechaFin    > @fechaInicio)
            THROW 50009, N'La mesa ya está reservada en ese horario', 1;

        IF EXISTS (SELECT 1 FROM dbo.Reservas
                   WHERE idUsuario   = @idUsuario
                     AND idReserva   <> @idReserva
                     AND fechaInicio < @fechaFin
                     AND fechaFin    > @fechaInicio)
            THROW 50010, N'El usuario ya tiene otra reserva en ese horario', 1;

        /* 5. Actualización */
        UPDATE dbo.Reservas
        SET idMesa         = @idMesa,
            idUsuario      = @idUsuario,
            fechaInicio    = @fechaInicio,
            fechaFin       = @fechaFin,
            numeroPersonas = @numeroPersonas,
            observaciones  = NULLIF(LTRIM(RTRIM(@observaciones)), N'')
        WHERE idReserva = @idReserva;

        COMMIT TRANSACTION;

        SELECT idReserva, idMesa, numeroMesa, zona, idUsuario, cliente, correoCliente,
               fechaInicio, fechaFin, numeroPersonas, observaciones, fechaCreacion
        FROM dbo.vw_ReservasDetalle
        WHERE idReserva = @idReserva;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* =============================================================================
   dbo.CancelarReserva: elimina una reserva que aún no empieza.
   Las reservas pasadas se conservan como historial (y pueden tener reseñas).
   ============================================================================= */
CREATE OR ALTER PROCEDURE dbo.CancelarReserva
    @idReserva INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @inicio DATETIME2(0);

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @inicio = fechaInicio
        FROM dbo.Reservas WITH (UPDLOCK, HOLDLOCK)
        WHERE idReserva = @idReserva;

        IF @inicio IS NULL
            THROW 50011, N'La reserva no existe', 1;

        IF @inicio <= SYSUTCDATETIME()
            THROW 50012, N'La reserva ya inició o terminó: no se puede cancelar', 1;

        DELETE FROM dbo.Reservas WHERE idReserva = @idReserva;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------- Verificación ---------- */
SELECT name AS procedimiento, create_date AS creado, modify_date AS modificado
FROM sys.procedures
WHERE name IN (N'RegistrarReserva', N'ActualizarReserva', N'CancelarReserva')
ORDER BY name;
GO
