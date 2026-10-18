/* =============================================================================
   RESTAURANTE SAZÓN CRIOLLA · Sistema de Reservas de Mesas
   DDL 01 · Creación de la base de datos y de las tablas
   -----------------------------------------------------------------------------
   Esquema normalizado en Tercera Forma Normal (3FN):
     dbo.Zonas    : ambientes del restaurante (salón, terraza, VIP, barra).
     dbo.Mesas    : mesas que se pueden reservar; cada una pertenece a una zona.
     dbo.Usuarios : clientes que realizan reservas.
     dbo.Reservas : relación Usuario - Mesa en un intervalo de tiempo.

   Orden de ejecución del repositorio:
     DDL/01_creacion_tablas.sql
     DDL/02_creacion_indices.sql
     DDL/03_creacion_vistas.sql
     DDL/04_procedimientos_almacenados.sql
     DML/05_carga_inicial.sql

   ATENCIÓN: el script es re-ejecutable; elimina y vuelve a crear las tablas,
   por lo que borra los datos existentes.
   ============================================================================= */

IF DB_ID(N'RestauranteDB') IS NULL
    CREATE DATABASE RestauranteDB;
GO

USE RestauranteDB;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

/* ---------- Limpieza (orden inverso a las dependencias) ---------- */
DROP TABLE IF EXISTS dbo.Reservas;
DROP TABLE IF EXISTS dbo.Mesas;
DROP TABLE IF EXISTS dbo.Usuarios;
DROP TABLE IF EXISTS dbo.Zonas;
GO

/* ---------- Zonas: catálogo de ambientes del restaurante ----------
   Se separa de Mesas para cumplir la 3FN: el nombre y la descripción dependen
   de la zona y no de la mesa, así no se repiten en cada mesa. */
CREATE TABLE dbo.Zonas (
    idZona      INT IDENTITY(1, 1) NOT NULL,
    nombre      NVARCHAR(50)       NOT NULL,
    descripcion NVARCHAR(200)      NULL,
    CONSTRAINT PK_Zonas        PRIMARY KEY CLUSTERED (idZona),
    CONSTRAINT CK_Zonas_nombre CHECK (LEN(LTRIM(RTRIM(nombre))) > 0)
);
GO

/* ---------- Mesas: lo que se reserva ---------- */
CREATE TABLE dbo.Mesas (
    idMesa        INT IDENTITY(1, 1) NOT NULL,
    numero        SMALLINT           NOT NULL,  -- número visible en el salón (101, 201, ...)
    capacidad     TINYINT            NOT NULL,  -- máximo de comensales
    idZona        INT                NOT NULL,
    activa        BIT                NOT NULL CONSTRAINT DF_Mesas_activa        DEFAULT (1),  -- 0 = fuera de servicio
    fechaCreacion DATETIME2(0)       NOT NULL CONSTRAINT DF_Mesas_fechaCreacion DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Mesas           PRIMARY KEY CLUSTERED (idMesa),
    CONSTRAINT FK_Mesas_Zonas     FOREIGN KEY (idZona) REFERENCES dbo.Zonas (idZona)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Mesas_numero    CHECK (numero BETWEEN 1 AND 999),
    CONSTRAINT CK_Mesas_capacidad CHECK (capacidad BETWEEN 1 AND 20)
);
GO

/* ---------- Usuarios: clientes que reservan ----------
   1FN: nombres y apellidos se guardan por separado (atributos atómicos). */
CREATE TABLE dbo.Usuarios (
    idUsuario     INT IDENTITY(1, 1) NOT NULL,
    nombres       NVARCHAR(60)       NOT NULL,
    apellidos     NVARCHAR(60)       NOT NULL,
    correo        NVARCHAR(150)      NOT NULL,
    telefono      VARCHAR(15)        NOT NULL,
    fechaRegistro DATETIME2(0)       NOT NULL CONSTRAINT DF_Usuarios_fechaRegistro DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Usuarios           PRIMARY KEY CLUSTERED (idUsuario),
    CONSTRAINT CK_Usuarios_nombres   CHECK (LEN(LTRIM(RTRIM(nombres))) > 0),
    CONSTRAINT CK_Usuarios_apellidos CHECK (LEN(LTRIM(RTRIM(apellidos))) > 0),
    CONSTRAINT CK_Usuarios_correo    CHECK (correo LIKE N'%_@_%._%'),
    CONSTRAINT CK_Usuarios_telefono  CHECK (LEN(telefono) BETWEEN 7 AND 15 AND telefono NOT LIKE '%[^0-9+]%')
);
GO

/* ---------- Reservas: un usuario reserva una mesa en un intervalo ----------
   3FN: solo guarda claves foráneas; el número de mesa, la zona o el nombre del
   cliente se obtienen por JOIN (vista dbo.vw_ReservasDetalle).
   Las fechas se guardan en UTC; Lima es UTC-5 todo el año. */
CREATE TABLE dbo.Reservas (
    idReserva      INT IDENTITY(1, 1) NOT NULL,
    idMesa         INT                NOT NULL,
    idUsuario      INT                NOT NULL,
    fechaInicio    DATETIME2(0)       NOT NULL,
    fechaFin       DATETIME2(0)       NOT NULL,
    numeroPersonas TINYINT            NOT NULL,
    observaciones  NVARCHAR(200)      NULL,  -- cumpleaños, silla para bebé, alergias...
    fechaCreacion  DATETIME2(0)       NOT NULL CONSTRAINT DF_Reservas_fechaCreacion DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT PK_Reservas                PRIMARY KEY CLUSTERED (idReserva),
    -- Integridad referencial: no se puede borrar una mesa o un usuario con reservas.
    CONSTRAINT FK_Reservas_Mesas          FOREIGN KEY (idMesa)    REFERENCES dbo.Mesas (idMesa)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT FK_Reservas_Usuarios       FOREIGN KEY (idUsuario) REFERENCES dbo.Usuarios (idUsuario)
        ON DELETE NO ACTION ON UPDATE NO ACTION,
    CONSTRAINT CK_Reservas_fechas         CHECK (fechaFin > fechaInicio),
    CONSTRAINT CK_Reservas_numeroPersonas CHECK (numeroPersonas BETWEEN 1 AND 20)
);
GO

/* ---------- Verificación ---------- */
SELECT t.name AS tabla, COUNT(c.column_id) AS columnas
FROM sys.tables t
INNER JOIN sys.columns c ON c.object_id = t.object_id
WHERE t.name IN (N'Zonas', N'Mesas', N'Usuarios', N'Reservas')
GROUP BY t.name
ORDER BY t.name;
GO
