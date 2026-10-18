/* =============================================================================
   RESTAURANTE SAZÓN CRIOLLA · Sistema de Reservas de Mesas
   PRUEBAS 06 · Demostración de las reglas del procedimiento dbo.RegistrarReserva
   -----------------------------------------------------------------------------
   Requiere: DDL/01 a DDL/04 y DML/05.
   Ejecutar completo (F5) y revisar la pestaña "Mensajes" de SSMS.
   Registra una reserva de prueba, intenta romper cada regla del negocio y al
   final cancela la reserva de prueba: la base queda como estaba.
   ============================================================================= */

USE RestauranteDB;
GO

SET NOCOUNT ON;

-- Día de prueba: dentro de 10 días. Las horas de Lima se convierten a UTC sumando 5 horas.
DECLARE @dia DATETIME2(0) = CAST(DATEADD(DAY, 10, CAST(DATEADD(HOUR, -5, SYSUTCDATETIME()) AS DATE)) AS DATETIME2(0));

DECLARE @inicio       DATETIME2(0) = DATEADD(HOUR, 20 + 5, @dia),  -- 20:00 Lima
        @fin          DATETIME2(0) = DATEADD(HOUR, 22 + 5, @dia),  -- 22:00 Lima
        @inicioPasado DATETIME2(0) = DATEADD(DAY, -30, DATEADD(HOUR, 20 + 5, @dia)),
        @finPasado    DATETIME2(0) = DATEADD(DAY, -30, DATEADD(HOUR, 22 + 5, @dia)),
        @inicioTemp   DATETIME2(0) = DATEADD(HOUR,  9 + 5, @dia),  -- 09:00 Lima (aún cerrado)
        @finTemp      DATETIME2(0) = DATEADD(HOUR, 10 + 5, @dia),
        @inicioLargo  DATETIME2(0) = DATEADD(HOUR, 13 + 5, @dia),  -- 13:00 a 18:00 = 5 horas
        @finLargo     DATETIME2(0) = DATEADD(HOUR, 18 + 5, @dia),
        @idPrueba     INT;

PRINT N'1) Reserva válida: mesa 103 (4 personas), usuario 2 -> se registra';
EXEC dbo.RegistrarReserva @idMesa = 3, @idUsuario = 2, @fechaInicio = @inicio, @fechaFin = @fin,
                          @numeroPersonas = 4, @observaciones = N'Reserva de prueba desde SSMS';
SELECT @idPrueba = MAX(idReserva) FROM dbo.Reservas WHERE observaciones = N'Reserva de prueba desde SSMS';
PRINT CONCAT(N'   Registrada con idReserva = ', @idPrueba);

PRINT N'2) Misma mesa y mismo horario, otro cliente -> 50009';
BEGIN TRY
    EXEC dbo.RegistrarReserva @idMesa = 3, @idUsuario = 3, @fechaInicio = @inicio, @fechaFin = @fin, @numeroPersonas = 2;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'3) Mismo cliente en otra mesa a la misma hora -> 50010';
BEGIN TRY
    EXEC dbo.RegistrarReserva @idMesa = 4, @idUsuario = 2, @fechaInicio = @inicio, @fechaFin = @fin, @numeroPersonas = 2;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'4) 5 personas en la mesa 101 (capacidad 2) -> 50008';
BEGIN TRY
    EXEC dbo.RegistrarReserva @idMesa = 1, @idUsuario = 4, @fechaInicio = @inicio, @fechaFin = @fin, @numeroPersonas = 5;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'5) Mesa 402 fuera de servicio -> 50006';
BEGIN TRY
    EXEC dbo.RegistrarReserva @idMesa = 12, @idUsuario = 4, @fechaInicio = @inicio, @fechaFin = @fin, @numeroPersonas = 2;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'6) Mesa inexistente -> 50005';
BEGIN TRY
    EXEC dbo.RegistrarReserva @idMesa = 999, @idUsuario = 4, @fechaInicio = @inicio, @fechaFin = @fin, @numeroPersonas = 2;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'7) Usuario inexistente -> 50007';
BEGIN TRY
    EXEC dbo.RegistrarReserva @idMesa = 4, @idUsuario = 999, @fechaInicio = @inicio, @fechaFin = @fin, @numeroPersonas = 2;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'8) Fecha pasada -> 50002';
BEGIN TRY
    EXEC dbo.RegistrarReserva @idMesa = 4, @idUsuario = 4, @fechaInicio = @inicioPasado, @fechaFin = @finPasado, @numeroPersonas = 2;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'9) 09:00 a 10:00, antes de abrir -> 50004';
BEGIN TRY
    EXEC dbo.RegistrarReserva @idMesa = 4, @idUsuario = 4, @fechaInicio = @inicioTemp, @fechaFin = @finTemp, @numeroPersonas = 2;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'10) Reserva de 5 horas -> 50003';
BEGIN TRY
    EXEC dbo.RegistrarReserva @idMesa = 4, @idUsuario = 4, @fechaInicio = @inicioLargo, @fechaFin = @finLargo, @numeroPersonas = 2;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'11) Fechas invertidas -> 50001';
BEGIN TRY
    EXEC dbo.RegistrarReserva @idMesa = 4, @idUsuario = 4, @fechaInicio = @fin, @fechaFin = @inicio, @numeroPersonas = 2;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'12) Cancelar una reserva que ya pasó (idReserva 1) -> 50012';
BEGIN TRY
    EXEC dbo.CancelarReserva @idReserva = 1;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'13) Cancelar la reserva de prueba -> se elimina';
EXEC dbo.CancelarReserva @idReserva = @idPrueba;
PRINT N'   Cancelada';

PRINT N'14) Cancelarla otra vez -> 50011';
BEGIN TRY
    EXEC dbo.CancelarReserva @idReserva = @idPrueba;
END TRY
BEGIN CATCH
    PRINT CONCAT(N'   Error ', ERROR_NUMBER(), N': ', ERROR_MESSAGE());
END CATCH;

PRINT N'15) Se comprueba que no quedó ninguna reserva de prueba (0 = correcto)';
SELECT COUNT(*) AS reservasDePrueba FROM dbo.Reservas WHERE observaciones = N'Reserva de prueba desde SSMS';
GO
