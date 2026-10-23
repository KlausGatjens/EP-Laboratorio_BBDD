# SQL Server — RestauranteDB

Solo contiene tres tablas:

| Tabla | Clave primaria | Datos |
| --- | --- | --- |
| Clientes | idCliente | nombres, apellidos, correo, telefono, fechaRegistro |
| Mesas | idMesa | numero, capacidad, activa, fechaCreacion |
| Reservas | idReserva | idCliente, idMesa, fechaInicio, fechaFin, numeroPersonas, observaciones, fechaCreacion |

`Reservas.idCliente` y `Reservas.idMesa` son claves foráneas. Un cliente y una mesa pueden tener varias reservas.
No se puede eliminar un cliente o una mesa con reservas asociadas.

## Inicializar

Requiere SQL Server y SQL Server Management Studio (SSMS) o sqlcmd.
El inicializador **elimina y vuelve a crear las tablas**, incluyendo los datos de práctica.

Desde PowerShell, dentro de esta carpeta, con autenticación de Windows:

```powershell
sqlcmd -S localhost -E -b -i inicializar.sql
```

Para autenticación SQL se puede usar `-U nombreUsuario` en lugar de `-E`; sqlcmd solicitará la contraseña.
Para una instancia con nombre, cambiar el servidor por `localhost\SQLEXPRESS`.

En SSMS, abrir `inicializar.sql` y activar **Consulta > Modo SQLCMD**.
Las rutas `:r` se resuelven desde el directorio de ejecución: si SSMS no encuentra los archivos,
cambiar las cuatro rutas por sus rutas absolutas. No es necesario cambiar los scripts incluidos.

El inicializador ejecuta en orden:

1. `DDL/01_creacion_tablas.sql`.
2. `DDL/02_creacion_indices.sql`.
3. `DDL/03_procedimientos_almacenados.sql`.
4. `DML/04_carga_inicial.sql`.

Se cargan 3 clientes, 3 mesas y 1 reserva futura. Hay dos procedimientos: `RegistrarReserva` y `ActualizarReserva`. No hay vistas.
La limpieza elimina los objetos conocidos del modelo anterior, si existen.

## Normalización (3FN)

- **1FN:** cada campo contiene un dato, sin listas ni grupos repetidos.
- **2FN:** todas las claves primarias son simples; cada atributo depende de su clave completa.
- **3FN:** los datos del cliente están en Clientes y los de la mesa en Mesas. Reservas guarda sus
  identificadores, sin repetir nombres, correos o capacidades.

## Procedimiento e índices

`RegistrarReserva` registra una reserva. Comprueba fechas futuras y ordenadas, la existencia
del cliente, que la mesa esté activa, su capacidad y que no tenga otra reserva cruzada.
Usa una transacción y bloquea la mesa durante la comprobación para evitar reservas simultáneas incompatibles.
Las fechas se guardan en UTC.

Los índices únicos evitan correos y números de mesa duplicados. El índice de mesa y fecha ayuda a buscar
reservas cruzadas. Las claves primarias también crean sus propios índices.

`ActualizarReserva` recibe `idReserva` y los nuevos datos. Aplica las mismas comprobaciones,
excluye la propia reserva al buscar cruces y devuelve la reserva actualizada.
El backend lo ejecuta desde `PUT /api/v1/reservas/:id`. Para cancelar usa DELETE.

Si la base ya existe, ejecutar solo `DDL/03_procedimientos_almacenados.sql` para agregar o actualizar
el procedimiento sin reiniciar las tablas.
La demostración opcional `PRUEBAS/06_pruebas_procedimientos.sql` registra una reserva,
comprueba el rechazo de un cruce y elimina la reserva de prueba.

[Diagrama de las tres tablas](diagrama/diagrama_bd.svg)
