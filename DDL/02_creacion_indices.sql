USE RestauranteDB;
GO
CREATE UNIQUE INDEX UX_Clientes_correo ON dbo.Clientes(correo);
CREATE UNIQUE INDEX UX_Mesas_numero ON dbo.Mesas(numero);
CREATE INDEX IX_Reservas_Mesa_Fechas ON dbo.Reservas(idMesa, fechaInicio) INCLUDE(fechaFin);
GO
