/* =============================================================================
   RESTAURANTE SAZÓN CRIOLLA · Sistema de Reservas de Mesas
   DDL 02 · Creación de índices
   -----------------------------------------------------------------------------
   Requiere: DDL/01_creacion_tablas.sql
   Las claves primarias ya crean un índice clúster por tabla. Aquí se agregan:
     - Índices ÚNICOS: hacen cumplir reglas de negocio ("no repetir").
     - Índices NO CLÚSTER: aceleran las búsquedas más frecuentes de la API.
   Re-ejecutable: elimina cada índice si ya existe antes de crearlo.
   ============================================================================= */

USE RestauranteDB;
GO

/* ---------- Limpieza ---------- */
DROP INDEX IF EXISTS UX_Zonas_nombre            ON dbo.Zonas;
DROP INDEX IF EXISTS UX_Mesas_numero            ON dbo.Mesas;
DROP INDEX IF EXISTS UX_Usuarios_correo         ON dbo.Usuarios;
DROP INDEX IF EXISTS IX_Mesas_Zona              ON dbo.Mesas;
DROP INDEX IF EXISTS IX_Reservas_Mesa_Fechas    ON dbo.Reservas;
DROP INDEX IF EXISTS IX_Reservas_Usuario_Fechas ON dbo.Reservas;
DROP INDEX IF EXISTS IX_Reservas_Fechas         ON dbo.Reservas;
GO

/* ---------- Índices únicos ---------- */
-- No pueden existir dos zonas con el mismo nombre.
CREATE UNIQUE NONCLUSTERED INDEX UX_Zonas_nombre ON dbo.Zonas (nombre);

-- El número de mesa (101, 201...) identifica a la mesa en el salón.
CREATE UNIQUE NONCLUSTERED INDEX UX_Mesas_numero ON dbo.Mesas (numero);

-- Un correo pertenece a un solo cliente.
CREATE UNIQUE NONCLUSTERED INDEX UX_Usuarios_correo ON dbo.Usuarios (correo);
GO

/* ---------- Índices de búsqueda ---------- */
-- Mesas de una zona (GET /mesas?idZona=) y JOIN Mesas-Zonas.
CREATE NONCLUSTERED INDEX IX_Mesas_Zona
    ON dbo.Mesas (idZona) INCLUDE (numero, capacidad, activa);

-- Cruce de horarios de una mesa: lo usa el procedimiento dbo.RegistrarReserva
-- (WHERE idMesa = @idMesa AND fechaInicio < @fechaFin AND fechaFin > @fechaInicio).
CREATE NONCLUSTERED INDEX IX_Reservas_Mesa_Fechas
    ON dbo.Reservas (idMesa, fechaInicio) INCLUDE (fechaFin);

-- Cruce de horarios de un cliente y listado de sus reservas.
CREATE NONCLUSTERED INDEX IX_Reservas_Usuario_Fechas
    ON dbo.Reservas (idUsuario, fechaInicio) INCLUDE (fechaFin);

-- Búsqueda por rango de fechas (GET /reservas?desde=&hasta= y mesas disponibles).
CREATE NONCLUSTERED INDEX IX_Reservas_Fechas
    ON dbo.Reservas (fechaInicio) INCLUDE (fechaFin, idMesa, idUsuario);
GO

/* ---------- Verificación ---------- */
SELECT OBJECT_NAME(i.object_id) AS tabla,
       i.name                   AS indice,
       i.type_desc              AS tipo,
       i.is_unique              AS unico,
       i.is_primary_key         AS clavePrimaria
FROM sys.indexes i
WHERE i.object_id IN (OBJECT_ID(N'dbo.Zonas'), OBJECT_ID(N'dbo.Mesas'),
                      OBJECT_ID(N'dbo.Usuarios'), OBJECT_ID(N'dbo.Reservas'))
ORDER BY tabla, clavePrimaria DESC, indice;
GO
