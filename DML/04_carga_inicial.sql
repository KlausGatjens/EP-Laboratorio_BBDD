USE RestauranteDB;
GO
INSERT INTO dbo.Clientes (nombres, apellidos, correo, telefono) VALUES
(N'Ana', N'Torres', N'ana@correo.pe', '987654321'),
(N'Luis', N'Ramos', N'luis@correo.pe', '986543210'),
(N'María', N'Pérez', N'maria@correo.pe', '985432109');

INSERT INTO dbo.Mesas (numero, capacidad, activa) VALUES (1, 2, 1), (2, 4, 1), (3, 6, 1);

-- Las fechas se calculan para que el ejemplo siga siendo futuro.
DECLARE @inicio DATETIME2(0) = DATEADD(DAY, 7, SYSUTCDATETIME());
DECLARE @fin DATETIME2(0) = DATEADD(HOUR, 2, @inicio);
EXEC dbo.RegistrarReserva @idMesa = 2, @idCliente = 1,
    @fechaInicio = @inicio, @fechaFin = @fin, @numeroPersonas = 4;
GO
