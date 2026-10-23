IF DB_ID(N'RestauranteDB') IS NULL
    CREATE DATABASE RestauranteDB;
GO

USE RestauranteDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO


DROP VIEW IF EXISTS dbo.vw_MesasDetalle;
DROP VIEW IF EXISTS dbo.vw_ReservasDetalle;
DROP TABLE IF EXISTS dbo.Reservas;
DROP TABLE IF EXISTS dbo.Mesas;
DROP TABLE IF EXISTS dbo.Clientes;
DROP TABLE IF EXISTS dbo.Usuarios; -- Limpieza del modelo anterior.
DROP TABLE IF EXISTS dbo.Zonas;
GO


CREATE TABLE dbo.Mesas (
    idMesa        INT IDENTITY(1, 1) NOT NULL,
    numero        INT           NOT NULL,  -- número visible en el salón (101, 201, ...)
    capacidad     INT            NOT NULL,  -- máximo de comensales
    activa        BIT                NOT NULL CONSTRAINT DF_Mesas_activa        DEFAULT (1),  -- 0 = fuera de servicio
    fechaCreacion DATETIME2(0)       NOT NULL CONSTRAINT DF_Mesas_fechaCreacion DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Mesas           PRIMARY KEY CLUSTERED (idMesa),
    CONSTRAINT CK_Mesas_numero    CHECK (numero > 0),
    CONSTRAINT CK_Mesas_capacidad CHECK (capacidad > 0)
);
GO


CREATE TABLE dbo.Clientes (
    idCliente     INT IDENTITY(1, 1) NOT NULL,
    nombres       NVARCHAR(60)       NOT NULL,
    apellidos     NVARCHAR(60)       NOT NULL,
    correo        NVARCHAR(150)      NOT NULL,
    telefono      VARCHAR(15)        NOT NULL,
    fechaRegistro DATETIME2(0)       NOT NULL CONSTRAINT DF_Clientes_fechaRegistro DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Clientes           PRIMARY KEY CLUSTERED (idCliente),
    CONSTRAINT CK_Clientes_nombres   CHECK (LEN(LTRIM(RTRIM(nombres))) > 0),
    CONSTRAINT CK_Clientes_apellidos CHECK (LEN(LTRIM(RTRIM(apellidos))) > 0),
    CONSTRAINT CK_Clientes_correo    CHECK (correo LIKE N'%_@_%._%'),
    CONSTRAINT CK_Clientes_telefono  CHECK (LEN(telefono) BETWEEN 7 AND 15 AND telefono NOT LIKE '%[^0-9+]%')
);
GO


CREATE TABLE dbo.Reservas (
    idReserva      INT IDENTITY(1, 1) NOT NULL,
    idMesa         INT                NOT NULL,
    idCliente      INT                NOT NULL,
    fechaInicio    DATETIME2(0)       NOT NULL,
    fechaFin       DATETIME2(0)       NOT NULL,
    numeroPersonas INT            NOT NULL,
    observaciones  NVARCHAR(200)      NULL,  -- cumpleaños, silla para bebé, alergias...
    fechaCreacion  DATETIME2(0)       NOT NULL CONSTRAINT DF_Reservas_fechaCreacion DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Reservas                PRIMARY KEY CLUSTERED (idReserva),
    -- Integridad referencial: no se puede borrar una mesa o un cliente con reservas.
    CONSTRAINT FK_Reservas_Mesas          FOREIGN KEY (idMesa)    REFERENCES dbo.Mesas (idMesa)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Reservas_Clientes       FOREIGN KEY (idCliente) REFERENCES dbo.Clientes (idCliente)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Reservas_fechas         CHECK (fechaFin > fechaInicio),
    CONSTRAINT CK_Reservas_numeroPersonas CHECK (numeroPersonas > 0)
);
GO


SELECT t.name AS tabla, COUNT(c.column_id) AS columnas
FROM sys.tables t
INNER JOIN sys.columns c ON c.object_id = t.object_id
WHERE t.name IN (N'Mesas', N'Clientes', N'Reservas')
GROUP BY t.name
ORDER BY t.name;
GO
