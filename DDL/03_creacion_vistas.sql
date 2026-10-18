/* =============================================================================
   RESTAURANTE SAZÓN CRIOLLA · Sistema de Reservas de Mesas
   DDL 03 · Creación de vistas
   -----------------------------------------------------------------------------
   Requiere: DDL/01_creacion_tablas.sql
   Las vistas unen las tablas normalizadas para las lecturas de la API, sin
   duplicar datos en las tablas (se respeta la 3FN).
   ============================================================================= */

USE RestauranteDB;
GO

/* ---------- Mesas con el nombre de su zona ---------- */
CREATE OR ALTER VIEW dbo.vw_MesasDetalle
AS
SELECT m.idMesa,
       m.numero,
       m.capacidad,
       m.activa,
       m.idZona,
       z.nombre AS zona,
       m.fechaCreacion
FROM dbo.Mesas m
INNER JOIN dbo.Zonas z ON z.idZona = m.idZona;
GO

/* ---------- Reservas con mesa, zona y cliente ---------- */
CREATE OR ALTER VIEW dbo.vw_ReservasDetalle
AS
SELECT r.idReserva,
       r.idMesa,
       m.numero                              AS numeroMesa,
       z.nombre                              AS zona,
       r.idUsuario,
       CONCAT(u.nombres, N' ', u.apellidos)  AS cliente,
       u.correo                              AS correoCliente,
       r.fechaInicio,
       r.fechaFin,
       r.numeroPersonas,
       r.observaciones,
       r.fechaCreacion
FROM dbo.Reservas r
INNER JOIN dbo.Mesas    m ON m.idMesa    = r.idMesa
INNER JOIN dbo.Zonas    z ON z.idZona    = m.idZona
INNER JOIN dbo.Usuarios u ON u.idUsuario = r.idUsuario;
GO
