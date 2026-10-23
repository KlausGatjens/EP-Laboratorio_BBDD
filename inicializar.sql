-- Ejecutar desde la carpeta EP-Laboratorio_BBDD.
-- En SSMS: activar Consulta > Modo SQLCMD; usar rutas absolutas si es necesario.
-- ATENCIÓN: reinicia las tres tablas y reemplaza sus datos.
:On Error exit
:r .\DDL\01_creacion_tablas.sql
:r .\DDL\02_creacion_indices.sql
:r .\DDL\03_procedimientos_almacenados.sql
:r .\DML\04_carga_inicial.sql
