USE RestauranteDB;
GO

-- Eliminar los procedimientos del modelo anterior si todavía existen.
DROP PROCEDURE IF EXISTS dbo.CancelarReserva;
GO

CREATE OR ALTER PROCEDURE dbo.RegistrarReserva
    @idMesa INT,
    @idCliente INT,
    @fechaInicio DATETIME2(0),
    @fechaFin DATETIME2(0),
    @numeroPersonas INT,
    @observaciones NVARCHAR(200) = NULL
AS
BEGIN

    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @fechaInicio IS NULL OR @fechaFin IS NULL OR @fechaFin <= @fechaInicio
            THROW 50001, N'Las fechas de la reserva no son válidas', 1;
        IF @fechaInicio <= SYSUTCDATETIME()
            THROW 50002, N'La reserva debe comenzar en el futuro', 1;

        DECLARE @capacidad INT, @activa BIT;
        SELECT @capacidad = capacidad, @activa = activa
        FROM dbo.Mesas WITH (UPDLOCK, HOLDLOCK) WHERE idMesa = @idMesa;
        IF @capacidad IS NULL THROW 50005, N'La mesa no existe', 1;
        IF @activa = 0 THROW 50006, N'La mesa está fuera de servicio', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Clientes WITH (UPDLOCK, HOLDLOCK) WHERE idCliente = @idCliente)
            THROW 50007, N'El cliente no existe', 1;
        IF @numeroPersonas IS NULL OR @numeroPersonas < 1 OR @numeroPersonas > @capacidad
            THROW 50008, N'El número de personas debe estar entre 1 y la capacidad de la mesa', 1;
        IF EXISTS (SELECT 1 FROM dbo.Reservas WHERE idMesa = @idMesa
                   AND fechaInicio < @fechaFin AND fechaFin > @fechaInicio)
            THROW 50009, N'La mesa ya está reservada en ese horario', 1;

        INSERT INTO dbo.Reservas (idMesa, idCliente, fechaInicio, fechaFin, numeroPersonas, observaciones)
        VALUES (@idMesa, @idCliente, @fechaInicio, @fechaFin, @numeroPersonas, @observaciones);
        SELECT * FROM dbo.Reservas WHERE idReserva = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

END;
GO

CREATE OR ALTER PROCEDURE dbo.ActualizarReserva
    @idReserva INT,
    @idMesa INT,
    @idCliente INT,
    @fechaInicio DATETIME2(0),
    @fechaFin DATETIME2(0),
    @numeroPersonas INT,
    @observaciones NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @fechaInicio IS NULL OR @fechaFin IS NULL OR @fechaFin <= @fechaInicio
            THROW 50001, N'Las fechas de la reserva no son válidas', 1;
        IF @fechaInicio <= SYSUTCDATETIME()
            THROW 50002, N'La reserva debe comenzar en el futuro', 1;

        DECLARE @capacidad INT, @activa BIT;
        SELECT @capacidad = capacidad, @activa = activa
        FROM dbo.Mesas WITH (UPDLOCK, HOLDLOCK) WHERE idMesa = @idMesa;
        IF @capacidad IS NULL THROW 50005, N'La mesa no existe', 1;
        IF @activa = 0 THROW 50006, N'La mesa está fuera de servicio', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Clientes WITH (UPDLOCK, HOLDLOCK) WHERE idCliente = @idCliente)
            THROW 50007, N'El cliente no existe', 1;
        IF @numeroPersonas IS NULL OR @numeroPersonas < 1 OR @numeroPersonas > @capacidad
            THROW 50008, N'El número de personas debe estar entre 1 y la capacidad de la mesa', 1;
        IF EXISTS (SELECT 1 FROM dbo.Reservas WHERE idMesa = @idMesa
                   AND fechaInicio < @fechaFin AND fechaFin > @fechaInicio AND idReserva <> @idReserva)
            THROW 50009, N'La mesa ya está reservada en ese horario', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Reservas WITH (UPDLOCK, HOLDLOCK) WHERE idReserva = @idReserva)
            THROW 50011, N'La reserva no existe', 1;
        UPDATE dbo.Reservas SET idMesa = @idMesa, idCliente = @idCliente,
            fechaInicio = @fechaInicio, fechaFin = @fechaFin,
            numeroPersonas = @numeroPersonas, observaciones = @observaciones
        WHERE idReserva = @idReserva;
        SELECT * FROM dbo.Reservas WHERE idReserva = @idReserva;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
