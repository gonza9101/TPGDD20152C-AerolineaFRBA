USE [GD2C2015]
GO

--creacion esquema del grupo
if not exists(select * from sys.schemas where name = 'NORMALIZADOS')
execute('CREATE SCHEMA [NORMALIZADOS] AUTHORIZATION [gd]')

else print('No te creo nada')
GO

/**************************************
				ROL
**************************************/

CREATE TABLE [NORMALIZADOS].Rol(
	[Id] numeric(18,0) PRIMARY KEY IDENTITY(0,1),
	[Nombre] nvarchar(255) UNIQUE NOT NULL,
	[Activo] BIT DEFAULT 1 NOT NULL
)
GO

INSERT INTO [NORMALIZADOS].Rol(Nombre)
	VALUES
	('Administrador'),
	('Guest')
GO

/**************************************
			FUNCIONALIDADES
**************************************/

CREATE TABLE [NORMALIZADOS].Funcionalidad(
	[Id] numeric(18,0) PRIMARY KEY IDENTITY(0,1),
	[Descripcion] nvarchar(255) UNIQUE not null
)
GO

INSERT INTO [NORMALIZADOS].Funcionalidad(Descripcion)
	VALUES
	('ABM DE ROL'),
	('ABM DE CIUDADES'),
	('ABM DE RUTA AEREA'),
	('ABM DE AERONAVES'),
	('GENERAR VIAJE'),
	('REGISTRO LLEGADA A DESTINO'),
	('COMPRA PASAJE/ENCOMIENDA'),
	('CANCELAR PASAJE/ENCOMIENDA'),
	('CONSULTA DE MILLAS'),
	('CANJE DE MILLAS'),
	('LISTADO ESTADISTICO')
GO
	
/**************************************
		FUNCIONALIDAD DE CADA ROL
**************************************/

CREATE TABLE [NORMALIZADOS].RolxFuncionalidad(
	[Rol] numeric(18,0) FOREIGN KEY REFERENCES [NORMALIZADOS].Rol(Id) NOT NULL,
	[Funcionalidad] numeric(18,0) FOREIGN KEY REFERENCES [NORMALIZADOS].Funcionalidad(Id) NOT NULL
	PRIMARY KEY(Rol,Funcionalidad)
)
GO

INSERT INTO [NORMALIZADOS].RolxFuncionalidad(Rol,Funcionalidad)
(
	SELECT R.ID,F.ID
	FROM [NORMALIZADOS].Rol R,[NORMALIZADOS].Funcionalidad F
	WHERE R.Nombre='Administrador'
	OR (R.Nombre='Guest' AND (F.Descripcion='COMPRA PASAJE/ENCOMIENDA' OR F.Descripcion='CONSULTA DE MILLAS'
		OR F.Descripcion='CANJE DE MILLAS')
		)
)
GO

/**************************************
				CLIENTES
**************************************/

CREATE TABLE [NORMALIZADOS].Cliente(
	[Id] numeric(18,0) PRIMARY KEY IDENTITY(0,1),
	[Nombre] nvarchar(255) NOT NULL,
	[Apellido] nvarchar(255) NOT NULL,
	[Dni] numeric(18,0) NOT NULL,
	[Telefono] numeric(18,0),
	[Direccion] nvarchar(255) NOT NULL,
	[Fecha_Nac] datetime NOT NULL,
	[Mail] nvarchar(255)
)
GO

INSERT INTO [NORMALIZADOS].[Cliente](Nombre, Apellido, Dni, Fecha_Nac, Direccion, Telefono, Mail)
(
	SELECT  DISTINCT Cli_Nombre, Cli_Apellido, Cli_Dni,Cli_Fecha_Nac, Cli_Dir,Cli_Telefono,Cli_Mail
	FROM [gd_esquema].[Maestra]
)
GO
 
/**************************************
				USUARIO
**************************************/

CREATE TABLE [NORMALIZADOS].Usuario(
	[Id] numeric(18,0) PRIMARY KEY IDENTITY(0,1),
	[Username] nvarchar(255) UNIQUE,
	[Rol] numeric(18,0) FOREIGN KEY REFERENCES [NORMALIZADOS].Rol(Id) NOT NULL,
	[Habilitado] BIT DEFAULT 1 NOT NULL,
	[Intentos] numeric(1,0) DEFAULT 0 NOT NULL,
	[SHA256] binary(32),
	[Mail] nvarchar(255) NOT NULL
)
GO

DECLARE @hash binary(32)
SET @hash =  CONVERT(binary(32),'0xe6b87050bfcb8143fcb8db0170a4dc9ed00d904ddd3e2a4ad1b1e8dc0fdc9be7',1)
INSERT INTO NORMALIZADOS.Usuario(Username,SHA256,Mail,Rol)
VALUES
	('admin', @hash,'admin@gdd.com',0),
	('Alan', @hash,'alan@gdd.com',0),
	('Gonzalo', @hash,'gonzalo@gdd.com',0),
	('David', @hash,'david@gdd.com',0),
	('Martin', @hash,'martin@gdd.com',0)
GO
/*****************************************
				CIUDAD
******************************************/

CREATE TABLE [NORMALIZADOS].[Ciudad](
	[Id][int] PRIMARY KEY IDENTITY(0,1),
	[Nombre] [nvarchar](255) UNIQUE NOT NULL
)
GO
	
-- Ingreso todas las ciudades que figuran como origen o destino.
-- El unique se va a encargar de no ingresar ciudades repetidas.	
INSERT INTO [NORMALIZADOS].[Ciudad](Nombre)

 SELECT Ruta_Ciudad_Destino FROM gd_esquema.Maestra
 UNION 
 SELECT Ruta_Ciudad_Origen FROM gd_esquema.Maestra
GO

/*****************************************
				SERVICIO
******************************************/
CREATE TABLE [NORMALIZADOS].[Servicio](
	[Id][int] PRIMARY KEY IDENTITY(0,1),
	[Descripcion] [nvarchar](255) UNIQUE NOT NULL,
	[Porcentaje_Adicional] [numeric](3,2) NOT NULL,
	CHECK(Porcentaje_Adicional BETWEEN 0 AND 1) -- Debe ser un valor entre 0 y 100%
) 
GO

INSERT INTO NORMALIZADOS.Servicio(Descripcion, Porcentaje_Adicional)
(	
	SELECT Tipo_Servicio, MAX(Pasaje_Precio/Ruta_Precio_BasePasaje -1)
	FROM [gd_esquema].[Maestra]
	WHERE Ruta_Precio_BasePasaje > 0
	GROUP BY Tipo_Servicio
)
GO

/*****************************************
			   RUTAS AEREAS 
******************************************/

CREATE TABLE [NORMALIZADOS].[#RutasTemporal]
(
	[Id] [numeric](18,0) IDENTITY(0,1) PRIMARY KEY,
	[Ruta_Codigo] [int],
	[Ciudad_Origen]  varchar(250),
	[Ciudad_Destino] varchar(250),
	[Precio_BasePasaje] [numeric](18, 2) NOT NULL,
	[Precio_BaseKG] [numeric](18, 2) NOT NULL,
	[Tipo_Servicio] [nvarchar](255),
	CHECK(Precio_BaseKG >= 0),
	CHECK(Precio_BasePasaje >= 0),
)
GO
INSERT INTO [NORMALIZADOS].#RutasTemporal(Ruta_Codigo,Ciudad_Origen,Ciudad_Destino,Precio_BasePasaje,Precio_BaseKG,Tipo_Servicio)
	SELECT Distinct M.Ruta_Codigo, M.Ruta_Ciudad_Origen, M.Ruta_Ciudad_Destino, M.Ruta_Precio_BasePasaje, M.Ruta_Precio_BaseKG, M.Tipo_Servicio
	FROM gd_esquema.Maestra M
GO
CREATE TABLE [NORMALIZADOS].[Ruta_Aerea]
(
	[Id] [numeric](18,0) IDENTITY(0,1) PRIMARY KEY,
	[Ruta_Codigo] [numeric](18,0),
	[Ciudad_Origen]  [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Ciudad](Id) NOT NULL,
	[Ciudad_Destino] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Ciudad](Id) NOT NULL,
	[Precio_BasePasaje] [numeric](18, 2) NOT NULL,
	[Precio_BaseKG] [numeric](18, 2) NOT NULL,
	[Tipo_Servicio] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Servicio](Id) NOT NULL,
	[Habilitada] [bit] DEFAULT 1,
	UNIQUE(Ciudad_Origen,Ciudad_destino,Tipo_Servicio),
	CHECK(Precio_BaseKG >= 0),
	CHECK(Precio_BasePasaje >= 0),
)
GO
INSERT INTO [NORMALIZADOS].Ruta_Aerea(Ruta_Codigo,Ciudad_Origen,Ciudad_Destino,Precio_BasePasaje,Precio_BaseKG,Tipo_Servicio)
	select R.ruta_codigo, C1.ID, C2.ID, R.precio_basepasaje, R2.precio_basekg, S.ID from normalizados.#RutasTemporal R
	JOIN NORMALIZADOS.Ciudad C1 ON C1.Nombre = R.ciudad_origen
	JOIN NORMALIZADOS.Ciudad C2 ON C2.Nombre = R.ciudad_Destino
	JOIN NORMALIZADOS.Servicio S ON S.Descripcion = R.Tipo_servicio
	JOIN NORMALIZADOS.#RutasTemporal R2 ON R.ruta_codigo = R2.ruta_codigo AND R.ciudad_origen = R2.ciudad_origen AND R.ciudad_destino = R2.ciudad_destino
	where R.precio_basepasaje > 0 AND R2.precio_basekg > 0
GO

/********************************************
					FABRICANTE
*********************************************/	

CREATE TABLE [NORMALIZADOS].[Fabricante](
	[Id] [int] PRIMARY KEY IDENTITY(0,1),
	[Nombre] [nvarchar](255) UNIQUE NOT NULL
)
GO

INSERT INTO [NORMALIZADOS].[Fabricante]([Nombre])
(
	SELECT DISTINCT [Aeronave_Fabricante]
	FROM[gd_esquema].[Maestra]
)
GO

/********************************************
					MODELO
*********************************************/	

CREATE TABLE [NORMALIZADOS].[Modelo](
	[Id] [int] PRIMARY KEY IDENTITY(0,1),
	[Modelo_Desc] [nvarchar](255) UNIQUE NOT NULL
)
GO

INSERT INTO [NORMALIZADOS].[Modelo]([Modelo_Desc])
(
	SELECT DISTINCT [Aeronave_Modelo]
	FROM[gd_esquema].[Maestra]
)
GO
/********************************************
					ESTADO AERONAVE
*********************************************/	
CREATE TABLE [NORMALIZADOS].[Estado_Aeronave](
	[Id] [int] PRIMARY KEY IDENTITY(1,1),
	[Descripcion] [nvarchar](255) NOT NULL
)
GO
INSERT INTO [NORMALIZADOS].[Estado_Aeronave](Descripcion)
	VALUES('Dado de alta'),
			('Fuera de servicio'),
			('Dado de baja por vida util')
GO
/********************************************
					AERONAVES
*********************************************/	

CREATE TABLE [NORMALIZADOS].[Aeronave](
	[Numero][int] PRIMARY KEY IDENTITY(1,1),
	[Matricula] [nvarchar](255) UNIQUE NOT NULL,
	[Fecha_Alta] [datetime],
	[Modelo] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Modelo] (Id) NOT NULL,
	[Fabricante] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Fabricante] (Id) NOT NULL,
	[Fecha_Baja_Definitiva] [datetime],
	[KG_Disponibles] [numeric](18,0) NOT NULL,
	[Tipo_Servicio] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Servicio] (Id) NOT NULL,
	[Estado] [int] DEFAULT 1 FOREIGN KEY REFERENCES [NORMALIZADOS].[Estado_Aeronave](Id)
	)
GO
INSERT INTO [NORMALIZADOS].[Aeronave](
	[Matricula],
	[Modelo],
	[Fabricante],
	[KG_Disponibles], --Total de Kg que puede llevar la Aeronave 
	[Tipo_Servicio]
	)
(
	SELECT DISTINCT A.Aeronave_Matricula, M.Id,F.Id,A.Aeronave_KG_Disponibles,S.Id
	FROM [gd_esquema].[Maestra] A
	JOIN [NORMALIZADOS].[Servicio] S ON A.Tipo_Servicio = S.Descripcion AND A.Pasaje_Codigo > 0
	JOIN [NORMALIZADOS].[Modelo] M ON M.Modelo_Desc = A.Aeronave_Modelo
	JOIN [NORMALIZADOS].[Fabricante] F ON A.Aeronave_Fabricante = F.Nombre
)
GO

/************************************************
					BAJA TEMPORAL AERONAVE
**************************************************/

CREATE TABLE [NORMALIZADOS].[Baja_Temporal_Aeronave](
	[Id] [int] PRIMARY KEY IDENTITY (0,1),
	[Aeronave] [int] FOREIGN KEY REFERENCES NORMALIZADOS.Aeronave(Numero) NOT NULL,
	[Fecha_Fuera_Servicio] [datetime] NOT NULL,
	[Fecha_Vuelta_Al_Servicio] [datetime] NOT NULL,
	[Motivo] [nvarchar](255) NOT NULL
	)
GO


/************************************************
					VIAJE
**************************************************/

CREATE TABLE [NORMALIZADOS].[#ViajeTemporal](
	[Id] [int] PRIMARY KEY IDENTITY (0,1),
	Fecha_Salida [datetime],
	Fecha_LLegada [datetime],
	Fecha_LLegada_Estimada [datetime],
	Ruta_Codigo [numeric](18,0),
	[Ciudad_Origen] nvarchar(255),
	[Ciudad_Destino] nvarchar(255),
	Aeronave_Matricula nvarchar(255)
	)
GO

INSERT INTO [NORMALIZADOS].[#ViajeTemporal](Fecha_Salida,Fecha_LLegada,Fecha_LLegada_Estimada,Ruta_Codigo,Ciudad_Origen,Ciudad_Destino,Aeronave_Matricula)
	
	SELECT DISTINCT M.FechaSalida,M.FechaLLegada,M.Fecha_LLegada_Estimada,M.Ruta_Codigo,M.Ruta_Ciudad_Origen,M.Ruta_Ciudad_Destino,M.Aeronave_Matricula
	FROM [gd_esquema].[Maestra] M
	
GO

CREATE TABLE [NORMALIZADOS].[Viaje](
	[Id] [int] PRIMARY KEY IDENTITY (0,1),
	[Fecha_Salida] [datetime] NOT NULL,
	[Fecha_Llegada_Estimada] [datetime] NOT NULL,
	[Ruta_Aerea] [numeric](18,0) FOREIGN KEY REFERENCES [NORMALIZADOS].[Ruta_Aerea](Id),
	[Aeronave] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Aeronave] (Numero)
	)
GO

INSERT INTO [NORMALIZADOS].[Viaje](
	[Fecha_Salida],
	[Fecha_Llegada_Estimada],
	[Ruta_Aerea],
	[Aeronave]
	)
(

	SELECT V.Fecha_Salida,V.Fecha_LLegada_Estimada,R.Id,A.Numero
	FROM [NORMALIZADOS].[#ViajeTemporal] V
	JOIN [NORMALIZADOS].[Aeronave] A ON V.Aeronave_Matricula = A.Matricula
	JOIN [NORMALIZADOS].[Ciudad] C1
	ON C1.Nombre=V.Ciudad_Origen
	JOIN [NORMALIZADOS].[Ciudad] C2
	ON C2.Nombre=V.Ciudad_Destino
	JOIN [NORMALIZADOS].[Ruta_Aerea] R ON  V.Ruta_Codigo = R.Ruta_Codigo AND R.Ciudad_Origen = C1.ID AND R.Ciudad_Destino = C2.ID

)
/******************************************************************
					  REGISTRO_DE_LLEGADA_DESTINO
*******************************************************************/
CREATE TABLE [NORMALIZADOS].[Registro_De_Llegada_Destino]
(
	[Viaje] int FOREIGN KEY REFERENCES [NORMALIZADOS].[Viaje](Id),
	[Aeropuerto_Destino] int FOREIGN KEY REFERENCES [NORMALIZADOS].[Ciudad](Id),
	[Fecha_Llegada] datetime NOT NULL
)
GO
INSERT INTO [NORMALIZADOS].[Registro_De_Llegada_Destino](Viaje,Aeropuerto_Destino,Fecha_Llegada)
	SELECT V.Id,C2.Id,VT.Fecha_LLegada
	FROM [NORMALIZADOS].[Viaje] V
	JOIN [NORMALIZADOS].[Ruta_Aerea] RA
		ON V.Ruta_Aerea=RA.Id
	JOIN [NORMALIZADOS].[Ciudad] C1
		ON RA.Ciudad_Destino=C1.Id
	JOIN [NORMALIZADOS].[Ciudad] C2
		ON RA.Ciudad_Origen=C2.Id
	JOIN [NORMALIZADOS].[Aeronave] A
		ON V.Aeronave=A.Numero
	JOIN [NORMALIZADOS].[#ViajeTemporal] VT
		ON VT.Aeronave_Matricula=A.Matricula
		AND VT.Ruta_Codigo=RA.Ruta_Codigo
		AND VT.Ciudad_Destino=C1.Nombre
		AND VT.Ciudad_Origen=C2.Nombre
	WHERE V.Fecha_Salida=VT.Fecha_Salida
GO
/******************************************************************
					  TIPO_BUTACA
*******************************************************************/

CREATE TABLE [NORMALIZADOS].[Tipo_Butaca]
(
	[Id] [int] PRIMARY KEY IDENTITY (0,1),
	[Descripcion] [nvarchar](255) NOT NULL
)
GO

INSERT INTO [NORMALIZADOS].[Tipo_Butaca](Descripcion)
(
	SELECT DISTINCT Butaca_Tipo
	FROM [gd_esquema].[Maestra]
)
GO

/*****************************************************************
							BUTACA
******************************************************************/

CREATE TABLE [NORMALIZADOS].[Butaca]
(
	[Id] [int] PRIMARY KEY IDENTITY (0,1),
	[Numero] [numeric](18,0) NOT NULL,
	[Piso] [numeric](18,0) NOT NULL DEFAULT 1,
	[Tipo_Butaca] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Tipo_Butaca] (Id) NOT NULL DEFAULT 0,
	[Aeronave] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Aeronave] (Numero) NOT NULL,
	[Habilitada] [bit] DEFAULT 1
)
GO
	
INSERT INTO [NORMALIZADOS].[Butaca](
	[Numero],
	[Piso],
	[Tipo_Butaca],
	[Aeronave]
	)
(
	SELECT DISTINCT A.Butaca_Nro,A.Butaca_Piso,TB.Id,N.Numero
	FROM [gd_esquema].[Maestra] A
	JOIN [NORMALIZADOS].[Tipo_Butaca] TB ON TB.Descripcion = A.Butaca_Tipo
	JOIN [NORMALIZADOS].[Aeronave] N ON A.Aeronave_Matricula = N.Matricula
	WHERE Pasaje_Codigo > 0
	
)
GO

/*****************************************************************
							TIPO_PAGO
******************************************************************/
CREATE TABLE [NORMALIZADOS].[Tipo_Pago](
	[Id] [int] PRIMARY KEY IDENTITY(0,1) NOT NULL,
	[Descripcion] [nvarchar](255) NOT NULL
)
GO
INSERT INTO [NORMALIZADOS].[Tipo_Pago](Descripcion)
	VALUES('Tarjeta de credito'),
	('Efectivo')

GO
/*****************************************************************
							Tipo_Tarjeta
******************************************************************/
CREATE TABLE [NORMALIZADOS].[Tipo_Tarjeta](
	[Id] [int] PRIMARY KEY IDENTITY(0,1) NOT NULL,
	[Nombre] [nvarchar](255) NOT NULL,
	[Numero_Cuotas] [int] NOT NULL
)
GO

INSERT INTO [NORMALIZADOS].[Tipo_Tarjeta](Nombre,Numero_Cuotas)
	VALUES('Rio',12),
		('Nacion',6),
		('Frances',3)
GO
/*****************************************************************
							Tarjeta_Credito
******************************************************************/
CREATE TABLE [NORMALIZADOS].[Tarjeta_Credito](
	[Nro] [bigint] PRIMARY KEY,
	[Codigo] INT NOT NULL,
	[Fecha_Vencimiento] INT NOT NULL,
	[Tipo_Tarjeta] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Tipo_Tarjeta](Id)
)
GO
/*****************************************************************
							COMPRA
******************************************************************/

CREATE TABLE [NORMALIZADOS].[Compra](
	[Id] [int] PRIMARY KEY IDENTITY (0,1),
	[PNR] [nvarchar](255),
	[Fecha] [datetime] NOT NULL,
	[Comprador] [numeric](18,0) FOREIGN KEY REFERENCES [NORMALIZADOS].[Cliente] (Id) NOT NULL,
	[Medio_Pago] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Tipo_Pago](Id) NOT NULL,
	[Tarjeta_Credito] [bigint] FOREIGN KEY REFERENCES [NORMALIZADOS].[Tarjeta_Credito](Nro) NULL,
	[Pasaje_Codigo] [numeric](18,0),
	[Paquete_Codigo] [numeric](18,0),
	[Viaje] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Viaje] (Id) NOT NULL
	)
GO
CREATE NONCLUSTERED INDEX ix_compra_paquetecodigo ON [Normalizados].[Compra]([Paquete_Codigo])
GO
CREATE NONCLUSTERED INDEX ix_compra_pasajecodigo ON [Normalizados].[Compra]([Pasaje_Codigo])
/***********************************************
					PASAJE
***********************************************/

CREATE TABLE [NORMALIZADOS].[Pasaje](
	[Id] [int] PRIMARY KEY IDENTITY(0,1),
	[Codigo] [numeric](18,0),
	[Precio]  [numeric](18,2) NOT NULL,
	[Pasajero] [numeric](18,0) FOREIGN KEY REFERENCES [NORMALIZADOS].[Cliente] (Id) NOT NULL,
	[Compra] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Compra] (Id) NOT NULL,
	[Butaca] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Butaca] (Id) NOT NULL
	)
GO

INSERT INTO [NORMALIZADOS].[Compra](
	[Fecha],
	[Comprador],
	[Medio_Pago],
	[Pasaje_Codigo],
	[Viaje]
	)
(
	SELECT DISTINCT M.Pasaje_FechaCompra, CLI.Id, 1, M.Pasaje_Codigo,V.Id -- Pago en efectivo porque no aclara otra cosa..
	FROM gd_esquema.Maestra M
	JOIN [NORMALIZADOS].[Cliente] CLI
	ON CLI.Apellido = M.Cli_Apellido AND CLI.Dni = M.Cli_Dni AND CLI.Nombre = M.Cli_Nombre
	JOIN [NORMALIZADOS].[Aeronave] A
	ON A.Matricula = M.Aeronave_Matricula
	JOIN NORMALIZADOS.Servicio S
	ON S.Descripcion=M.Tipo_Servicio
	JOIN NORMALIZADOS.Ciudad C1
	ON C1.Nombre=M.Ruta_Ciudad_Origen
	JOIN NORMALIZADOS.Ciudad C2
	ON C2.Nombre=M.Ruta_Ciudad_Destino
	JOIN NORMALIZADOS.Ruta_Aerea R
	ON R.Ruta_Codigo=M.Ruta_Codigo
	AND R.Ciudad_Origen=C1.Id
	AND R.Ciudad_Destino=C2.Id
	AND R.Tipo_Servicio=S.Id
	JOIN [NORMALIZADOS].[Viaje] V
	ON V.Aeronave = A.Numero AND V.Fecha_Salida = M.FechaSalida AND V.Ruta_Aerea =R.Id
	WHERE M.Pasaje_Codigo != 0

)
GO

INSERT INTO [NORMALIZADOS].[Pasaje](
	[Codigo],
	[Precio],
	[Pasajero],
	[Compra],
	[Butaca]
	)
(
SELECT M.Pasaje_Codigo, M.Pasaje_Precio, CLI.Id, C.Id, B.Id
FROM gd_esquema.Maestra M
JOIN [NORMALIZADOS].[Cliente] CLI
ON CLI.Apellido = M.Cli_Apellido AND CLI.Dni = M.Cli_Dni AND CLI.Nombre = M.Cli_Nombre
JOIN [NORMALIZADOS].[Compra] C
ON C.Pasaje_Codigo = M.Pasaje_Codigo
JOIN [NORMALIZADOS].[Aeronave] A
ON A.Matricula = M.Aeronave_Matricula
JOIN [NORMALIZADOS].[Butaca] B
ON B.Numero = M.Butaca_Nro AND B.Aeronave = A.Numero
WHERE M.Pasaje_Codigo != 0
)
GO
/***********************************************
					ENCOMIENDA
***********************************************/

CREATE TABLE [NORMALIZADOS].[Encomienda](
	[Id] [int] PRIMARY KEY IDENTITY(0,1),
	[Codigo] [numeric](18,0),
	[Precio]  [numeric](18,2) NOT NULL,
	[Kg] [numeric](18,0) NOT NULL,
	[Cliente] [numeric](18,0) FOREIGN KEY REFERENCES [NORMALIZADOS].[Cliente] (Id) NOT NULL,
	[Compra] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Compra] (Id) NOT NULL,
)
GO

INSERT INTO [NORMALIZADOS].[Compra](
	[Fecha],
	[Comprador],
	[Medio_Pago],
	[Paquete_Codigo],
	[Viaje]
	)
(
SELECT M.Paquete_FechaCompra, CLI.Id, 1, M.Paquete_Codigo,V.Id -- Pago en efectivo porque no aclara otra cosa..
	FROM gd_esquema.Maestra M
	JOIN [NORMALIZADOS].[Cliente] CLI
	ON CLI.Apellido = M.Cli_Apellido AND CLI.Dni = M.Cli_Dni AND CLI.Nombre = M.Cli_Nombre
	JOIN [NORMALIZADOS].[Aeronave] A
	ON A.Matricula = M.Aeronave_Matricula
	JOIN NORMALIZADOS.Servicio S
	ON S.Descripcion=M.Tipo_Servicio
	JOIN NORMALIZADOS.Ciudad C1
	ON C1.Nombre=M.Ruta_Ciudad_Origen
	JOIN NORMALIZADOS.Ciudad C2
	ON C2.Nombre=M.Ruta_Ciudad_Destino
	JOIN NORMALIZADOS.Ruta_Aerea R
	ON R.Ruta_Codigo=M.Ruta_Codigo
	AND R.Ciudad_Origen=C1.Id
	AND R.Ciudad_Destino=C2.Id
	AND R.Tipo_Servicio=S.Id
	JOIN [NORMALIZADOS].[Viaje] V
	ON V.Aeronave = A.Numero AND V.Fecha_Salida = M.FechaSalida AND V.Ruta_Aerea =R.Id
	WHERE M.Paquete_Codigo != 0
)
GO

INSERT INTO [NORMALIZADOS].[Encomienda](
	[Codigo],
	[Precio],
	[Cliente],
	[Compra],
	[Kg]
	)
(
SELECT M.Paquete_Codigo, M.Paquete_Precio, CLI.Id, C.Id, M.Paquete_KG
FROM gd_esquema.Maestra M
JOIN [NORMALIZADOS].[Cliente] CLI
ON CLI.Apellido = M.Cli_Apellido AND CLI.Dni = M.Cli_Dni AND CLI.Nombre = M.Cli_Nombre
JOIN [NORMALIZADOS].[Compra] C
ON C.Paquete_Codigo = M.Paquete_Codigo
JOIN [NORMALIZADOS].[Aeronave] A
ON A.Matricula = M.Aeronave_Matricula
WHERE M.Paquete_Codigo != 0
)
GO

DROP INDEX [NORMALIZADOS].[Compra].ix_compra_pasajecodigo
GO

DROP INDEX [NORMALIZADOS].[Compra].ix_compra_paquetecodigo
GO

ALTER TABLE [NORMALIZADOS].[Compra]
DROP COLUMN Pasaje_Codigo
GO

ALTER TABLE [NORMALIZADOS].[Compra]
DROP COLUMN Paquete_Codigo
GO
DROP TABLE [NORMALIZADOS].[#RutasTemporal]
GO
DROP TABLE [NORMALIZADOS].[#ViajeTemporal]

UPDATE [NORMALIZADOS].[Compra]
SET PNR = CONVERT(nvarchar(255),Fecha,112)+CAST(Id AS nvarchar(255))
/*****************************************************************
							DETALLE_CANCELACION
******************************************************************/

CREATE TABLE [NORMALIZADOS].[Detalle_Cancelacion](
	[Id] [int] PRIMARY KEY IDENTITY (0,1),
	[Fecha] [datetime] NOT NULL,
	[Motivo] [nvarchar](255)
	)
GO

/***********************************************
				PASAJES CANCELADOS
***********************************************/
CREATE TABLE [NORMALIZADOS].[Pasajes_Cancelados](
	[Id] [int] PRIMARY KEY IDENTITY(0,1) NOT NULL,
	[Pasaje] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].Pasaje(Id) NOT NULL,
	[Cancelacion] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].Detalle_Cancelacion(Id) NOT NULL
)
GO
/***********************************************
			ENCOMIENDAS CANCELADAS
***********************************************/
CREATE TABLE [NORMALIZADOS].[Encomiendas_Canceladas](
	[Id] [int] PRIMARY KEY IDENTITY(0,1) NOT NULL,
	[Encomienda] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].Encomienda(Id) NOT NULL,
	[Cancelacion] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].Detalle_Cancelacion(Id) NOT NULL
)
GO

	
/******************************************************************
					  RECOMPENSAS
*******************************************************************/

CREATE TABLE [NORMALIZADOS].[Recompensa](
		[Id][int] PRIMARY KEY IDENTITY(0,1),
		[Descripcion][nvarchar](255) UNIQUE NOT NULL,
		[Puntos][int],
		[Stock] [int],
		CHECK (Stock>-1)
)
GO

INSERT INTO NORMALIZADOS.Recompensa(Descripcion, Puntos,Stock)
	VALUES 
		('Control remoto Selfie',70,1500),
		('Billetera',450,500),
		('Brujula',1000,10),
		('Audifonos',500,100),
		('Notebook Sony Vaio i5 4GB RAM',10000,1),
		('Planchita para el pelo', 700,430),
		('Plancha',800,50),
		('Juego de sillones',20000,2)
GO

/******************************************************************
					  CANJES
*******************************************************************/

CREATE TABLE [NORMALIZADOS].[Canje](
		[Id][int] PRIMARY KEY IDENTITY(0,1),
		[Cliente][numeric](18,0) FOREIGN KEY REFERENCES [NORMALIZADOS].[Cliente](Id) NOT NULL,
		[Recompensa] [int] FOREIGN KEY REFERENCES [NORMALIZADOS].[Recompensa](Id) NOT NULL,
		[Cantidad][int] NOT NULL,
		[Fecha][Datetime] NOT NULL, 
		CHECK(Cantidad>0)
)
GO


/******************************************************************
			STORED PROCEDURES, TRIGGERS Y FUNCTIONS
*******************************************************************/

------------------------------------------------------------------
--             STORED PROCEDURE PARA LOGIN 
------------------------------------------------------------------
-- Incrementa o resetea la cantidad de intentos fallidos
--        y deshabilita la cuenta si supero los 3.
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[LOGIN](@Username nvarchar(255),@SHA256 binary(32)) 
AS
	DECLARE @U_name nvarchar(255)
	DECLARE @Id int
	DECLARE @U_SHA256  binary(32)
	DECLARE @U_habilitado bit
	DECLARE @Cant_intentos int
	--Busqueda de usuario
	SELECT @Id=Id,@U_name=Username,@U_SHA256=SHA256,@U_habilitado=Habilitado,@Cant_intentos=Intentos
	FROM [NORMALIZADOS].Usuario
	WHERE Username=@Username
	
	IF @U_name IS NULL BEGIN
		raiserror('No existe ningun usuario con ese username.', 11, 1)
		RETURN -1 
	END
	-- 
	IF @U_habilitado=0 BEGIN
		raiserror('El usuario se encuentra desahabilitado',16,1)
		RETURN -2
	END
	--Caso de contrasenia incorrecta
	IF @U_SHA256<>@SHA256 BEGIN
		SET @Cant_intentos=@Cant_intentos+1
		IF  @Cant_intentos=3 BEGIN	--Si el usuario llega al max de intentos
			SET @U_habilitado=0		--queda deshabilitado
			SET @Cant_intentos=0 
		END
		UPDATE [NORMALIZADOS].Usuario
		SET Intentos=@Cant_intentos,Habilitado=@U_habilitado
		WHERE Username=@Username
		raiserror('Contrasenia incorrecta',16,1)
		RETURN -3 
	END
	
	IF @U_SHA256=@SHA256 BEGIN
		UPDATE [NORMALIZADOS].Usuario
		SET Intentos=0
		WHERE Username=@Username
		RETURN @Id
	END
	
GO

------------------------------------------------------------------
--            FUNCIONES PARA PUNTOS
------------------------------------------------------------------

CREATE FUNCTION NORMALIZADOS.Puntos_Generados(@Precio numeric(18,2))
RETURNS int
AS BEGIN
	RETURN FLOOR(@Precio/10) -- Cada diez pesos 1 punto.
	END
GO

------------------------------------------------------------------
--              FUNCION devuelve la cantidad total de butacas
--						para una aeronave
------------------------------------------------------------------

CREATE FUNCTION NORMALIZADOS.GetTotalButacas_SEL_ByMatricula(@matricula nvarchar(255))
RETURNS int
AS 
	BEGIN

		DECLARE @cantidad_butacas int

			SELECT @cantidad_butacas = COUNT(*) 
			FROM NORMALIZADOS.Butaca B
			JOIN NORMALIZADOS.Aeronave A ON A.Numero = B.Aeronave
			WHERE A.Matricula = @matricula

		RETURN @cantidad_butacas
	END
GO

------------------------------------------------------------------
--                       ESTADISTICAS                           --
------------------------------------------------------------------
CREATE FUNCTION NORMALIZADOS.TOP5_Destinos_Con_Mas_Pasajes(@Anio int, @Semestre int)
RETURNS @Top5 TABLE (Ciudad nvarchar(255), [Pasajes vendidos] int)
AS
BEGIN
	DECLARE @Desde int
	DECLARE @Hasta int
	IF (@Semestre = 1)
		BEGIN
			SET @Desde = 1
			SET @Hasta = 6
		END
	ELSE
		BEGIN 
			SET @Desde = 7
			SET @Hasta = 12
		END	
	
	INSERT INTO @Top5 
		SELECT TOP 5 C.Nombre AS Ciudad, 
			COUNT(*) AS Pasajes FROM NORMALIZADOS.Ciudad C 
			JOIN NORMALIZADOS.Ruta_Aerea R ON R.Ciudad_Destino = C.Id 
			JOIN NORMALIZADOS.Viaje V ON V.Ruta_Aerea = R.Id 
			JOIN NORMALIZADOS.Compra Com ON Com.Viaje = V.Id 
			JOIN NORMALIZADOS.Pasaje P ON P.Compra = Com.Id
			WHERE P.Id NOT IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados)			
			AND MONTH(Com.Fecha) BETWEEN @Desde AND @Hasta AND YEAR(Com.Fecha) = @Anio
			GROUP BY C.Nombre 
			ORDER BY Pasajes DESC			 
	RETURN
END
GO

CREATE FUNCTION NORMALIZADOS.TOP5_Destinos_Pasajes_Cancelados(@Anio int, @Semestre int)
RETURNS @Top5 TABLE (Ciudad nvarchar(255), [Cantidad de pasajes cancelados] int)
AS
BEGIN
	DECLARE @Desde int
	DECLARE @Hasta int
	IF (@Semestre = 1)
		BEGIN
			SET @Desde = 1
			SET @Hasta = 6
		END
	ELSE
		BEGIN 
			SET @Desde = 7
			SET @Hasta = 12
		END	
		
	INSERT INTO @Top5
		SELECT TOP 5 C.Nombre AS Ciudad, 
			COUNT(*) AS Pasajes FROM NORMALIZADOS.Ciudad C 
			JOIN NORMALIZADOS.Ruta_Aerea R ON R.Ciudad_Destino = C.Id 
			JOIN NORMALIZADOS.Viaje V ON V.Ruta_Aerea = R.Id 
			JOIN NORMALIZADOS.Compra Com ON Com.Viaje = V.Id 
			JOIN NORMALIZADOS.Pasaje P ON P.Compra = Com.Id
			WHERE P.Id IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados)			
			AND MONTH(Com.Fecha) BETWEEN @Desde AND @Hasta AND YEAR(Com.Fecha) = @Anio
			GROUP BY C.Nombre 
			ORDER BY Pasajes DESC				 
	RETURN
END
GO

CREATE FUNCTION NORMALIZADOS.TOP5_Aeronaves_Dias_Fuera_De_Servicio(@Anio int, @Semestre int)
RETURNS @Top5 TABLE (Matricula nvarchar(255), Numero int, [Dias fuera de servicio] int)
AS
BEGIN
	DECLARE @Desde int
	DECLARE @Hasta int
	IF (@Semestre = 1)
		BEGIN
			SET @Desde = 1
			SET @Hasta = 6
		END
	ELSE
		BEGIN 
			SET @Desde = 7
			SET @Hasta = 12
		END	
		
	INSERT INTO @Top5 
		SELECT TOP 5 A.Matricula, A.Numero, SUM(DATEDIFF(DAY, B.Fecha_Fuera_Servicio, B.Fecha_Vuelta_Al_Servicio)) AS Dias
		FROM NORMALIZADOS.Aeronave A
		JOIN NORMALIZADOS.Baja_Temporal_Aeronave B 
			ON B.Aeronave = A.Numero
		WHERE MONTH(B.Fecha_Fuera_Servicio) BETWEEN @Desde AND @Hasta AND YEAR(B.Fecha_Fuera_Servicio) = @Anio
		GROUP BY A.Matricula, A.Numero
		ORDER BY Dias DESC
	
	RETURN
END
GO

CREATE FUNCTION NORMALIZADOS.TOP5_Destinos_Con_Aeronaves_Mas_Vacias(@Anio int, @Semestre int)
RETURNS @Top5 TABLE (Ciudad nvarchar(255), [Cantidad de butacas libres] int)
AS
BEGIN
	DECLARE @Desde int
	DECLARE @Hasta int
	IF (@Semestre = 1)
		BEGIN
			SET @Desde = 1
			SET @Hasta = 6
		END
	ELSE
		BEGIN 
			SET @Desde = 7
			SET @Hasta = 12
		END	

	INSERT INTO @Top5 
		SELECT TOP 5 C.Nombre, sum(T.Butacas)-sum(T.Ocupadas) AS Porcentaje_Libre
		FROM(
			SELECT NORMALIZADOS.GetTotalButacas_SEL_ByMatricula(A.Matricula) AS Butacas, COUNT(*) AS Ocupadas, V.Ruta_Aerea AS Ruta_Aerea
			FROM NORMALIZADOS.Viaje V 
			JOIN NORMALIZADOS.Aeronave A ON V.Aeronave = A.Numero AND MONTH(V.Fecha_Salida) BETWEEN @Desde AND @Hasta
			JOIN NORMALIZADOS.Compra C ON C.Viaje = V.Id
			JOIN NORMALIZADOS.Pasaje P ON C.Id = P.Compra
			WHERE P.Id NOT IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados) AND YEAR(V.Fecha_Salida) = @Anio
			GROUP BY A.Numero, V.Id, V.Ruta_Aerea, A.Matricula
		)T
		JOIN NORMALIZADOS.Ruta_Aerea R ON T.Ruta_Aerea = R.Id 
		JOIN NORMALIZADOS.Ciudad C ON R.Ciudad_Destino = C.Id
		GROUP BY C.Nombre
		ORDER BY Porcentaje_Libre DESC
	RETURN
END
GO

CREATE FUNCTION NORMALIZADOS.TOP5_Clientes_Puntos_a_la_Fecha(@Anio int, @Semestre int) 
RETURNS @Top5 TABLE (Dni numeric(18,0), Apellido nvarchar(255), Nombre nvarchar(255), Puntos int)
AS
BEGIN
	DECLARE @Desde int
	DECLARE @Hasta int
	IF (@Semestre = 1)
		BEGIN
			SET @Desde = 1
			SET @Hasta = 6
		END
	ELSE
		BEGIN 
			SET @Desde = 7
			SET @Hasta = 12
		END	
		
		
	IF(@Desde = 7)	
		BEGIN
			INSERT INTO @Top5 
			
				SELECT TOP 5 C.Dni, C.Apellido, C.Nombre, ISNULL(SUM(P.Puntos) - 
				isnull((SELECT SUM(R.Puntos * Can.Cantidad) FROM NORMALIZADOS.Canje Can JOIN NORMALIZADOS.Recompensa R ON Can.Recompensa = R.Id WHERE Can.Cliente = C.Id AND YEAR(Can.Fecha) = @Anio),0)
				,0) AS TotalPuntos
				FROM
					(
					SELECT P.Pasajero AS Cliente, ISNULL(NORMALIZADOS.Puntos_Generados(P.Precio), 0) AS Puntos  
							FROM NORMALIZADOS.Pasaje P
							JOIN NORMALIZADOS.Compra C ON C.Id = P.Compra
							JOIN NORMALIZADOS.Viaje V ON C.Viaje = V.Id
							JOIN NORMALIZADOS.Registro_De_Llegada_Destino R ON V.Id = R.Viaje
							WHERE P.Id NOT IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados)
							AND YEAR(R.Fecha_Llegada) = @Anio
												
					UNION ALL

					SELECT E.Cliente AS Cliente, ISNULL(NORMALIZADOS.Puntos_Generados(E.Precio), 0) AS Puntos  
							FROM NORMALIZADOS.Encomienda E
							JOIN NORMALIZADOS.Compra C ON C.Id = E.Compra
							JOIN NORMALIZADOS.Viaje V ON C.Viaje = V.Id
							JOIN NORMALIZADOS.Registro_De_Llegada_Destino R ON V.Id = R.Viaje
							WHERE E.Id NOT IN (SELECT Encomienda FROM NORMALIZADOS.Encomiendas_Canceladas)
							AND YEAR(R.Fecha_Llegada) = @Anio
					) P
				JOIN NORMALIZADOS.Cliente C ON C.Id = P.Cliente
				GROUP BY C.Dni, C.Apellido, C.Nombre, C.Id
				ORDER BY TotalPuntos DESC
		END
	ELSE
		BEGIN
			INSERT INTO @Top5 
			
				SELECT TOP 5 C.Dni, C.Apellido, C.Nombre, ISNULL(SUM(P.Puntos) - 
				ISNULL((SELECT SUM(R.Puntos * Can.Cantidad) FROM NORMALIZADOS.Canje Can JOIN NORMALIZADOS.Recompensa R ON Can.Recompensa = R.Id WHERE Can.Cliente = C.Id AND ((YEAR(Can.Fecha) = @Anio AND MONTH(Can.Fecha) < 7) OR (YEAR(Can.Fecha) = @Anio - 1 AND MONTH(Can.Fecha) > 6))),0)
				,0) AS TotalPuntos
				FROM
					(
					SELECT P.Pasajero AS Cliente, ISNULL(NORMALIZADOS.Puntos_Generados(P.Precio), 0) AS Puntos  
							FROM NORMALIZADOS.Pasaje P
							JOIN NORMALIZADOS.Compra C ON C.Id = P.Compra
							JOIN NORMALIZADOS.Viaje V ON C.Viaje = V.Id
							JOIN NORMALIZADOS.Registro_De_Llegada_Destino R ON V.Id = R.Viaje
							WHERE P.Id NOT IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados)
							AND MONTH(R.Fecha_Llegada) BETWEEN @Desde AND @Hasta AND (YEAR(R.Fecha_Llegada) = @Anio OR YEAR(R.Fecha_Llegada) = @Anio - 1)
												
					UNION ALL

					SELECT E.Cliente AS Cliente, ISNULL(NORMALIZADOS.Puntos_Generados(E.Precio), 0) AS Puntos  
							FROM NORMALIZADOS.Encomienda E
							JOIN NORMALIZADOS.Compra C ON C.Id = E.Compra
							JOIN NORMALIZADOS.Viaje V ON C.Viaje = V.Id
							JOIN NORMALIZADOS.Registro_De_Llegada_Destino R ON V.Id = R.Viaje
							WHERE E.Id NOT IN (SELECT Encomienda FROM NORMALIZADOS.Encomiendas_Canceladas)
							AND ((YEAR(R.Fecha_Llegada) = @Anio AND MONTH(R.Fecha_Llegada) < 7) OR (YEAR(R.Fecha_Llegada) = @Anio - 1 AND MONTH(R.Fecha_Llegada) > 6))
					) P
				JOIN NORMALIZADOS.Cliente C ON C.Id = P.Cliente
				GROUP BY C.Dni, C.Apellido, C.Nombre, C.Id
				ORDER BY TotalPuntos DESC		
		END
		
	RETURN

END
GO		
--------------------------------------------------------------------------------
-- FUNCION QUE BUSCA AERONAVES QUE NO ESTAN FUERA DE SERVICIO O DADOS DE BAJA
--------------------------------------------------------------------------------

CREATE FUNCTION [NORMALIZADOS].[Aeronaves_Funcionan_En](@Fecha datetime)
RETURNS @Aeronaves TABLE(
	[Numero][int], 
	[Matricula] [nvarchar](255),
	[Fecha_Alta] [datetime], 
	[Modelo] [nvarchar](255), 
	[Fabricante] [int],
	[Fecha_Baja_Definitiva] [datetime],
	[KG_Disponibles] [numeric](18,0),
	[Tipo_Servicio] [int],
	[Estado] [int]
	)
	
AS 
BEGIN
DECLARE @Llegada datetime
SET @Llegada = DATEADD(HOUR, 24, @Fecha)

	INSERT INTO @Aeronaves
		SELECT DISTINCT A.Numero,A.Matricula,A.Fecha_Alta,A.Modelo,A.Fabricante,A.Fecha_Baja_Definitiva,A.KG_Disponibles,A.Tipo_Servicio,A.Estado
		FROM [NORMALIZADOS].[Aeronave] A
		LEFT JOIN [NORMALIZADOS].[Baja_Temporal_Aeronave] B 
			ON  B.Aeronave = A.Numero
				AND NOT (@Llegada < B.Fecha_Fuera_Servicio OR @Fecha > B.Fecha_Vuelta_Al_Servicio)
		WHERE B.Id IS NULL AND A.Fecha_Baja_Definitiva IS NULL
		
	RETURN
END
GO
--------------------------------------------------------------------------------
--			FUNCION QUE BUSCA AERONAVES DISPONIBLES PARA UN VIAJE
--------------------------------------------------------------------------------

CREATE FUNCTION [NORMALIZADOS].[Aeronaves_Para_Viaje](@Origen int, @Destino int, @Fecha datetime)
RETURNS @Aeronaves TABLE(
	[Numero] [int],
	[Matricula] [nvarchar](255),
	[Fecha_Alta] [datetime], 
	[Modelo] [nvarchar](255), 
	[Fabricante] [int],
	[Fecha_Baja_Definitiva] [datetime],
	[KG_Disponibles] [numeric](18,0),
	[Tipo_Servicio] [int],
	[Estado] [int]
	)
AS 
BEGIN
	
	INSERT INTO @Aeronaves
	SELECT A.Numero, A.Matricula, A.Fecha_Alta, A.Modelo, A.Fabricante, A.Fecha_Baja_Definitiva, A.KG_Disponibles, A.Tipo_Servicio,A.Estado
	FROM NORMALIZADOS.Aeronaves_Funcionan_En(@Fecha) A
              JOIN NORMALIZADOS.Ruta_Aerea R ON R.Tipo_Servicio = A.Tipo_Servicio 
              AND R.Ciudad_Origen = @Origen AND R.Ciudad_Destino = @Destino
              WHERE NOT EXISTS(
                  
                   SELECT V.Id FROM NORMALIZADOS.Viaje V
                   JOIN NORMALIZADOS.Ruta_Aerea R2 ON V.Ruta_Aerea = R2.Id AND V.Aeronave=A.Numero
                   AND R2.Ciudad_Origen = @Origen AND R2.Ciudad_Destino = @Destino
                   WHERE
                     ( ABS (DATEDIFF(hour, V.Fecha_Salida, @Fecha))<24) --Hay menos de 24 horas entre los dos viajes
                     OR (V.Fecha_Salida < @Fecha AND R2.Ciudad_Destino!=@Origen AND DATEDIFF(hour, V.Fecha_Salida, @Fecha)<48 ) --O el viaje anterior tiene una ciudad de destino distinta al origen y hay menos de 24hs para que se traslade la aeronave (luego de las 24hs del viaje anterior)
                     OR (V.Fecha_Salida > @Fecha AND R2.Ciudad_Origen!=@Destino AND DATEDIFF(hour, @Fecha, V.Fecha_Salida)<48 ) --O el viaje siguiente tiene un origen diferente al destino y hay menos de 24 y hay menos de 24hs para que se traslade la aeronave (luego de las 24hs del viaje nuevo)
			

			)

	RETURN
END

GO
--------------------------------------------------------------------------------
--				SP habilita a todos los usuarios
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SP_Reset_Estado_Users]
AS
	UPDATE [NORMALIZADOS].Usuario 
	SET	Habilitado =1,Intentos =0

GO

--------------------------------------------------------------------------------
--				SP Rol
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SP_Baja_Rol]
(@Rol int)
AS
	UPDATE [NORMALIZADOS].[Rol] 
	SET	Activo =0
	WHERE Id = @Rol

GO

--------------------------------------------------------------------------------
--				SP Aeronaves
--------------------------------------------------------------------------------

CREATE PROCEDURE [NORMALIZADOS].[SP_Alta_Aeronave](@Matricula nvarchar(255), @Modelo nvarchar(255), @Kg_Disponibles numeric(18,0), 
@Fabricante int, @Tipo_Servicio int, @Fecha_Alta datetime, @Id int OUTPUT)
AS BEGIN
	INSERT INTO [NORMALIZADOS].[Aeronave](Matricula, Modelo, KG_Disponibles, Fabricante, Tipo_Servicio, Fecha_Alta)
	VALUES (UPPER(@Matricula), UPPER(@Modelo), @Kg_Disponibles, @Fabricante, @Tipo_Servicio, @Fecha_Alta)
	set @Id = SCOPE_IDENTITY()
END
GO

CREATE PROCEDURE [NORMALIZADOS].[SP_Alta_Butaca](@Aeronave int, @Numero numeric(18,0), @Piso numeric(18,0), 
@Tipo_Butaca int, @Habilitada bit)
AS BEGIN
	INSERT INTO [NORMALIZADOS].[Butaca](Numero, Piso, Tipo_Butaca, Aeronave, Habilitada)
	VALUES (@Numero, @Piso, @Tipo_Butaca, @Aeronave, @Habilitada)
	declare @Id int
	set @Id = SCOPE_IDENTITY()
END
GO

CREATE PROCEDURE [NORMALIZADOS].[SP_Modificar_Aeronave]
@Numero int,
@Matricula nvarchar(7),
@Fabricante int,
@Modelo nvarchar(255),
@Tipo_Servicio int,
@KG_Disponibles numeric(18,0),
@Fecha_Alta datetime
AS
BEGIN
	UPDATE [NORMALIZADOS].[Aeronave]
	SET Matricula = @Matricula,
		Fabricante = @Fabricante,
		Modelo = @Modelo,
		Tipo_Servicio = @Tipo_Servicio,
		KG_Disponibles = @KG_Disponibles,
		Fecha_Alta = @Fecha_Alta
	WHERE Numero = @Numero	
END
GO

CREATE PROCEDURE [NORMALIZADOS].[SP_Butacas_Aeronave]
@Numero_Aeronave int
AS
BEGIN
	SELECT B.*, TB.Descripcion
	FROM [NORMALIZADOS].[Butaca] B
	JOIN [NORMALIZADOS].[Tipo_Butaca] TB
	ON TB.Id = B.Tipo_Butaca
	WHERE Aeronave = @Numero_Aeronave
END
GO

CREATE PROCEDURE [NORMALIZADOS].[SP_Modificar_Butaca]
@Id int,
@Tipo int,
@Habilitada bit,
@Piso int,
@Numero int
AS
BEGIN
	UPDATE [NORMALIZADOS].[Butaca]
	SET Tipo_Butaca = @Tipo, Habilitada = @Habilitada, Piso = @Piso, Numero = @Numero
	WHERE Id = @Id	
END
GO

CREATE PROCEDURE [NORMALIZADOS].[SP_Baja_Butaca]
@Id int
AS
BEGIN
	UPDATE [NORMALIZADOS].[Butaca]
	SET Habilitada = 0
	WHERE Id = @Id	
END
GO

CREATE PROCEDURE [NORMALIZADOS].[SP_Aeronave_Con_Viajes]
	@Aeronave int,
	@Tiene_Viajes int OUTPUT
	AS
		
		IF (EXISTS	(select 1 
		from [NORMALIZADOS].Viaje V
		WHERE V.Aeronave = @Aeronave))
		BEGIN
			SET @Tiene_Viajes = 1;
		END
		ELSE
		BEGIN
			SET @Tiene_Viajes = 0;
		END
GO
--------------------------------------------------------------------------------
--				SP busqueda aeronaves sin viajes programados entre
--					ciertas fechas
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SP_Busqueda_Aeronaves_Sin_Viajes_Programados]
	@Modelo nvarchar(255),
	@Matricula nvarchar(255),
	@Kg_Disponibles numeric(18,0),
	@Fabricante nvarchar(255),
	@Tipo_Servicio nvarchar(255),
	@Fecha_Alta datetime,
	@Fecha_Alta_Fin datetime,
	@FechaDesde datetime,
	@FechaHasta datetime

	AS
	BEGIN
		SELECT DISTINCT A.*, S.Descripcion, F.Nombre, M.Modelo_Desc
		FROM [NORMALIZADOS].Aeronave A
		JOIN [NORMALIZADOS].Servicio S
		ON A.Tipo_Servicio = S.Id
		JOIN [NORMALIZADOS].Fabricante F
		ON A.Fabricante = F.Id
		JOIN [NORMALIZADOS].[Modelo] M
		ON M.Id = A.Modelo
		WHERE (M.Modelo_Desc like @Modelo OR @Modelo is null)
			AND (A.Matricula like @Matricula OR @Matricula like '')
			AND (A.Kg_Disponibles = @Kg_Disponibles OR @Kg_Disponibles = 0)
			AND (F.Nombre like @Fabricante OR @Fabricante is null)
			AND (S.Descripcion like @Tipo_Servicio OR @Tipo_Servicio is null)
			AND (A.Fecha_Alta > @Fecha_Alta OR @Fecha_Alta is null) 
			AND (A.Fecha_Alta < @Fecha_Alta_Fin OR @Fecha_Alta_Fin is null) 
			AND (A.Numero NOT IN(  SELECT Aeronave
									FROM [NORMALIZADOS].[Baja_Temporal_Aeronave]
									WHERE (@FechaDesde BETWEEN Fecha_Fuera_Servicio AND Fecha_Vuelta_Al_Servicio)	
										AND (@FechaHasta  BETWEEN Fecha_Fuera_Servicio AND Fecha_Vuelta_Al_Servicio)
									))
			AND NOT EXISTS(SELECT 1
							FROM [NORMALIZADOS].[Viaje] V
							JOIN [NORMALIZADOS].[Registro_De_Llegada_Destino] R ON V.Id = R.Viaje
							WHERE Aeronave=A.Numero
								AND ((V.Fecha_Salida > @FechaDesde AND R.Fecha_Llegada < @FechaDesde)
								OR (V.Fecha_Salida < @FechaHasta AND R.Fecha_Llegada > @FechaHasta))
							)
	END
GO

CREATE PROCEDURE [NORMALIZADOS].[SP_Busqueda_Aeronave]
	@Modelo nvarchar(255),
	@Matricula nvarchar(255),
	@Kg_Disponibles numeric(18,0),
	@Fabricante nvarchar(255),
	@Tipo_Servicio nvarchar(255),
	@Fecha_Alta datetime,
	@Fecha_Alta_Fin datetime,
	@Fecha_Baja_Def datetime,
	@Fecha_Baja_Def_Fin datetime,
	@Fecha_Baja_Temporal datetime,
	@Fecha_Baja_Temporal_Fin datetime,
	@Fecha_Vuelta_Servicio datetime,
	@Fecha_Vuelta_Servicio_Fin datetime

	AS
	SELECT A.*, S.Descripcion, F.Nombre, M.Modelo_Desc
	FROM [NORMALIZADOS].Aeronave A
	LEFT JOIN [NORMALIZADOS].[Baja_Temporal_Aeronave] BTA
	ON A.Numero = BTA.Aeronave
	LEFT JOIN [NORMALIZADOS].Servicio S
	ON A.Tipo_Servicio = S.Id
	LEFT JOIN [NORMALIZADOS].Fabricante F
	ON A.Fabricante = F.Id
	LEFT JOIN [NORMALIZADOS].[Modelo] M
	ON M.Id = A.Modelo
	WHERE (M.Modelo_Desc like @Modelo OR @Modelo is null)
		AND (A.Matricula like @Matricula OR @Matricula like '')
		AND (A.Kg_Disponibles = @Kg_Disponibles OR @Kg_Disponibles = 0)
		AND (F.Nombre like @Fabricante OR @Fabricante is null)
		AND (S.Descripcion like @Tipo_Servicio OR @Tipo_Servicio is null)
		AND (A.Fecha_Alta > @Fecha_Alta OR @Fecha_Alta is null) 
		AND (A.Fecha_Alta < @Fecha_Alta_Fin OR @Fecha_Alta_Fin is null) 
		AND (A.Fecha_Baja_Definitiva > @Fecha_Baja_Def OR @Fecha_Baja_Def is null) 
		AND (A.Fecha_Baja_Definitiva < @Fecha_Baja_Def_Fin OR @Fecha_Baja_Def_Fin is null)
		AND (BTA.Fecha_Fuera_Servicio > @Fecha_Baja_Temporal OR @Fecha_Baja_Temporal is null) 
		AND (BTA.Fecha_Fuera_Servicio < @Fecha_Baja_Temporal_Fin OR @Fecha_Baja_Temporal_Fin is null) 
		AND (BTA.Fecha_Vuelta_Al_Servicio > @Fecha_Vuelta_Servicio OR @Fecha_Vuelta_Servicio is null)
		AND (BTA.Fecha_Vuelta_Al_Servicio < @Fecha_Vuelta_Servicio_Fin OR @Fecha_Vuelta_Servicio_Fin is null) 
GO

CREATE PROCEDURE [NORMALIZADOS].[SP_Busqueda_Baja_Aeronave]
	@Modelo nvarchar(255),
	@Matricula nvarchar(255),
	@Kg_Disponibles numeric(18,0),
	@Fabricante nvarchar(255),
	@Tipo_Servicio nvarchar(255),
	@Fecha_Alta datetime,
	@Fecha_Alta_Fin datetime

	AS
	SELECT A.*, S.Descripcion, F.Nombre, M.Modelo_Desc
	FROM [NORMALIZADOS].Aeronave A
	LEFT JOIN [NORMALIZADOS].Servicio S
	ON A.Tipo_Servicio = S.Id
	LEFT JOIN [NORMALIZADOS].Fabricante F
	ON A.Fabricante = F.Id
	LEFT JOIN [NORMALIZADOS].[Modelo] M
	ON M.Id = A.Modelo
	WHERE (M.Modelo_Desc like @Modelo OR @Modelo is null)
		AND (A.Matricula like @Matricula OR @Matricula like '')
		AND (A.Kg_Disponibles = @Kg_Disponibles OR @Kg_Disponibles = 0)
		AND (F.Nombre like @Fabricante OR @Fabricante is null)
		AND (S.Descripcion like @Tipo_Servicio OR @Tipo_Servicio is null)
		AND (A.Fecha_Alta > @Fecha_Alta OR @Fecha_Alta is null) 
		AND (A.Fecha_Alta < @Fecha_Alta_Fin OR @Fecha_Alta_Fin is null) 
		AND (A.Fecha_Baja_Definitiva is null)
		AND ( NOT EXISTS (SELECT 1
						  FROM [NORMALIZADOS].[Baja_Temporal_Aeronave] BTA
						  WHERE A.Numero = BTA.Aeronave
						  AND GETDATE() BETWEEN BTA.Fecha_Fuera_Servicio AND BTA.Fecha_Vuelta_Al_Servicio
						  )
			)
 
GO

--------------------------------------------------------------------------------
--				SP cancela pasajes y encomiendas 
--					 de aeronave
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[CancelarPasajesEncomiendasAeronaves](
@nroAeronave int,
@fechaDesde datetime,
@fechaHasta datetime
)
AS
BEGIN
	IF EXISTS(SELECT 1
				FROM [NORMALIZADOS].Pasaje P
				JOIN [NORMALIZADOS].Compra C
					ON P.Compra=C.Id
				JOIN [NORMALIZADOS].Viaje V
					ON V.Id=C.Viaje
				WHERE 
					V.Aeronave=@NroAeronave
					AND P.Id NOT IN (SELECT Pasaje FROM [NORMALIZADOS].[Pasajes_Cancelados])
					AND (V.Fecha_Salida > @fechaDesde OR @fechaDesde IS NULL)
					AND (V.Fecha_Salida < @fechaHasta OR @fechaHasta IS NULL)
				union
				SELECT 1
				FROM [NORMALIZADOS].Encomienda E
				JOIN [NORMALIZADOS].Compra C
					ON E.Id=C.Id
				JOIN [NORMALIZADOS].Viaje V
					ON V.Id=C.Viaje
				WHERE 
					V.Aeronave=@NroAeronave
					AND E.Id NOT IN (SELECT Encomienda FROM [NORMALIZADOS].[Encomiendas_Canceladas])
					AND (V.Fecha_Salida > @fechaDesde OR @fechaDesde IS NULL)
					AND (V.Fecha_Salida < @fechaHasta OR @fechaHasta IS NULL)
					)
	BEGIN
		DECLARE @idCancelacion numeric(18,0)

		INSERT INTO [NORMALIZADOS].[Detalle_Cancelacion](Fecha,Motivo)
			VALUES(GETDATE(),'Baja de aeronave')
	
		SET @idCancelacion=SCOPE_IDENTITY()

		INSERT INTO [NORMALIZADOS].[Pasajes_Cancelados](Pasaje,Cancelacion)
			SELECT P.Id,@idCancelacion
			FROM [NORMALIZADOS].[Pasaje] P
			JOIN [NORMALIZADOS].[Compra] C
				ON P.Compra=C.Id
			JOIN [NORMALIZADOS].[Viaje] V
				ON V.Id=C.Viaje
			WHERE 
					V.Aeronave=@NroAeronave
					AND (V.Fecha_Salida > @fechaDesde OR @fechaDesde IS NULL)
					AND (V.Fecha_Salida < @fechaHasta OR @fechaHasta IS NULL)

		INSERT INTO [NORMALIZADOS].[Encomiendas_Canceladas](Encomienda,Cancelacion)
			SELECT E.Id,@idCancelacion
			FROM [NORMALIZADOS].[Encomienda] E
			JOIN [NORMALIZADOS].[Compra] C
				ON E.Compra=C.Id
			JOIN [NORMALIZADOS].[Viaje] V
				ON V.Id=C.Viaje
			WHERE 
					V.Aeronave=@NroAeronave
					AND (V.Fecha_Salida > @fechaDesde OR @fechaDesde IS NULL)
					AND (V.Fecha_Salida < @fechaHasta OR @fechaHasta IS NULL)
	END
END
GO
--------------------------------------------------------------------------------
--				SP registra una baja temporal de una aeronave
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SP_DarDeBajaTempAeronave](
@nroAeronave int,
@fechaDesde datetime,
@fechaHasta datetime,
@motivo nvarchar(255)
)
AS
BEGIN
	INSERT INTO [NORMALIZADOS].[Baja_Temporal_Aeronave](Aeronave,
														Fecha_Fuera_Servicio,
														Fecha_Vuelta_Al_Servicio,
														Motivo)
		VALUES(@nroAeronave,@fechaDesde,@fechaHasta,@motivo)
END
GO
--------------------------------------------------------------------------------
--				SP da de baja temporal una aeronave
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SP_Baja_Temporal_Aeronave_Cancelar](
@nroAeronave int,
@fechaDesde datetime,
@fechaHasta datetime,
@motivo nvarchar(255))
AS
BEGIN
	BEGIN TRAN BajaTemporal

	UPDATE [NORMALIZADOS].[Aeronave]
	SET Fecha_Baja_Definitiva=GETDATE()
	WHERE Numero=@nroAeronave
		AND Estado=2

	EXEC [NORMALIZADOS].[SP_DarDeBajaTempAeronave] @nroAeronave,@fechaDesde,@fechaHasta,@motivo

	EXEC [NORMALIZADOS].[CancelarPasajesEncomiendasAeronaves] @nroAeronave,@fechaDesde,@fechaHasta

	COMMIT TRAN BajaTemporal
	SELECT @@ROWCOUNT
END
GO
--------------------------------------------------------------------------------
--				SP actualiza estado de baja y registra la fecha de baja
--------------------------------------------------------------------------------
CREATE PROCEDURE NORMALIZADOS.DarDeBajaAeronave @nroAeronave int,@fechaBaja datetime
AS
BEGIN
	UPDATE [NORMALIZADOS].[Aeronave]
	SET Fecha_Baja_Definitiva=@fechaBaja,
			Estado=3
	WHERE Numero=@nroAeronave

	SELECT @@ROWCOUNT
END
GO
--------------------------------------------------------------------------------
--				SP da de baja definitiva una aeronave
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SP_Baja_Def_Aeronave_Cancelar](@nroAeronave int,@fechaBaja datetime)
AS
BEGIN
	BEGIN TRAN BajaDefinitiva
		EXEC NORMALIZADOS.DarDeBajaAeronave @nroAeronave,@fechaBaja
	DECLARE @var datetime
	SET @var=GETDATE()
	EXEC [NORMALIZADOS].[CancelarPasajesEncomiendasAeronaves] @nroAeronave,@var,NULL

	COMMIT TRAN BajaDefinitiva
	SELECT @@ROWCOUNT
END
GO

--------------------------------------------------------------------------------
--				SP da de alta una ciudad
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SP_Alta_Ciudad](@descripcion nvarchar(255))
AS
BEGIN
	INSERT INTO [NORMALIZADOS].Ciudad(Nombre)
		VALUES(@descripcion)

	SELECT @@IDENTITY
END
GO
--------------------------------------------------------------------------------
--				SP verifica si existe ciudad con descripcion
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[ExistCiudad_SEL_ByDescr](@descripcion nvarchar(255))
AS
BEGIN
	SELECT Id 
	FROM [NORMALIZADOS].Ciudad
	WHERE Nombre LIKE '_'+@descripcion
END
GO
--------------------------------------------------------------------------------
--				SP obtiene las ciudades con una descripcion
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetCiudad_SEL_ByDescr](@descripcion nvarchar(255))
AS
BEGIN
	SELECT Id,Nombre
	FROM [NORMALIZADOS].Ciudad
	WHERE Nombre LIKE '%'+@descripcion+'%'
END
GO
--------------------------------------------------------------------------------
--				SP modifica la ciudad
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[ActualizarCiudad_UPD_ById](@Id int,@nombre nvarchar(255))
AS
BEGIN
	UPDATE [NORMALIZADOS].Ciudad
	SET Nombre=@nombre
	WHERE Id=@Id

	SELECT @@IDENTITY
END
GO
--------------------------------------------------------------------------------
--				SP trae todas las ciudades
--------------------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetAllCiudad_SEL]
AS
BEGIN
	SELECT Id,Nombre
	FROM [NORMALIZADOS].Ciudad
END
GO

------------------------------------------------------------------
-- Funcion para obtener los KGs disponibles en un viaje
------------------------------------------------------------------
CREATE FUNCTION NORMALIZADOS.KGs_Disponibles(@viaje int)
RETURNS numeric(18,0)
AS
	BEGIN
		DECLARE @KGtotal numeric(18,0)

		DECLARE @KGusados numeric(18,0)
		DECLARE @KGdisponibles numeric (18,0)
		
		SELECT @KGtotal = A.KG_Disponibles
		FROM NORMALIZADOS.Viaje V
		JOIN NORMALIZADOS.Aeronave A
		ON A.Numero = V.Aeronave
		WHERE V.Id = @viaje

		SELECT @KGusados = ISNULL(SUM(E.Kg),0)
		FROM NORMALIZADOS.Encomienda E
		JOIN NORMALIZADOS.Compra C ON E.Compra = C.Id
		WHERE C.Viaje = @viaje AND E.id NOT IN (SELECT Encomienda FROM NORMALIZADOS.Encomiendas_Canceladas)

		SET @KGdisponibles = @KGtotal - @KGusados

		RETURN @KGdisponibles
	END
GO

--------------------------------------------------------------------------------
--			FUNCION devuelve cantidad de butacas ocupadas
--------------------------------------------------------------------------------
CREATE FUNCTION NORMALIZADOS.GetCantidadButacasOcupadas(@viaje int)
RETURNS int
AS 
	BEGIN
		
		DECLARE @butacas_ocupadas int

		SELECT @butacas_ocupadas = COUNT(*) FROM NORMALIZADOS.Pasaje P
		JOIN NORMALIZADOS.Compra C ON P.Compra = C.Id
		JOIN NORMALIZADOS.Viaje V ON C.Viaje = V.Id
		WHERE V.Id = @viaje
		AND P.Id NOT IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados)

		RETURN @butacas_ocupadas
	END
GO

------------------------------------------------------------------
--         FUNCION devuelve la cantidad de butacas disponibles
--				de una aeronave
------------------------------------------------------------------
CREATE FUNCTION NORMALIZADOS.GetCantidadButacasDisponibles(@viaje int)
RETURNS int
AS 
	BEGIN
		
		DECLARE @butacas_disponibles int
		
		SELECT @butacas_disponibles = (NORMALIZADOS.GetTotalButacas_SEL_ByMatricula(A.Matricula)-
										NORMALIZADOS.GetCantidadButacasOcupadas(@viaje))
		FROM NORMALIZADOS.Viaje V
		JOIN NORMALIZADOS.Aeronave A ON V.Aeronave = A.Numero
		WHERE V.Id = @viaje
		
		RETURN @butacas_disponibles
	END
GO

------------------------------------------------------------------
--         SP verifica si existe una ruta con ciudad de origen, destino y servicio
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[ExistTuplaRuta](
@ciudadOrigen numeric(18,0),
@ciudadDestino numeric(18,0),
@tipoServicio numeric(18,0))
AS
BEGIN
	SELECT 1
	FROM [NORMALIZADOS].[Ruta_Aerea]
	WHERE Tipo_Servicio=@tipoServicio
			AND Ciudad_Origen=@ciudadOrigen
			AND Ciudad_Destino=@ciudadDestino
END
GO
------------------------------------------------------------------
--         SP verifica si existe una ruta con un codigo
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[ExistCodigoRuta](@codigoRuta numeric(18,0))
AS
BEGIN
	SELECT 1
	FROM [NORMALIZADOS].[Ruta_Aerea]
	WHERE Ruta_Codigo=@codigoRuta
END
GO
------------------------------------------------------------------
--         SP verifica si para un codigo de ruta ya existente
--				arma correctamente el tramo con las otras rutas con mismo codigo
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[CheckRutaConMismoCodigo](
@codigoRuta numeric(18,0),
@ciudadOrigen numeric(18,0),
@ciudadDestino numeric(18,0)
)
AS
BEGIN
	SELECT 1
	FROM [NORMALIZADOS].[Ruta_Aerea]
	WHERE @codigoRuta=Ruta_Codigo
		AND	(@ciudadOrigen=Ciudad_Destino
		OR @ciudadDestino=@ciudadOrigen)
END
GO
------------------------------------------------------------------
--         SP guarda una ruta
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SaveRuta](
@codigoRuta numeric(18,0),
@ciudadOrigen numeric(18,0),
@ciudadDestino numeric(18,0),
@precioBasePasaje numeric(18,2),
@precioBaseKg numeric(18,2),
@tipoServicio numeric(18,0)
)
AS
BEGIN
	INSERT INTO [NORMALIZADOS].[Ruta_Aerea](Ruta_Codigo,
											Ciudad_Origen,
											Ciudad_Destino,
											Precio_BasePasaje,
											Precio_BaseKG,
											Tipo_Servicio)
		VALUES(@codigoRuta,
				@ciudadOrigen,
				@ciudadDestino,
				@precioBasePasaje,
				@precioBaseKg,
				@tipoServicio)

	SELECT @@ROWCOUNT
END
GO
------------------------------------------------------------------
--         SP actualiza ruta/s con el mismo codigo
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[ActualizarRuta](
@codigoRuta numeric(18,0),
@ciudadOrigen numeric(18,0),
@ciudadDestino numeric(18,0),
@precioBasePasaje numeric(18,2),
@precioBaseKg numeric(18,2),
@tipoServicio numeric(18,0)
)
AS
BEGIN
	UPDATE [NORMALIZADOS].[Ruta_Aerea]
	SET Ruta_Codigo=@codigoRuta,
		Ciudad_Origen=@ciudadOrigen,
		Ciudad_Destino=@ciudadDestino,
		Precio_BaseKG=@precioBaseKg,
		Precio_BasePasaje=@precioBasePasaje,
		Tipo_Servicio=@tipoServicio
	WHERE Ruta_Codigo=@codigoRuta

	SELECT @@ROWCOUNT
END
GO
------------------------------------------------------------------
--         SP devuelve rutas de acuerdo a los filtros
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetRutaByFilters](
@codigo numeric(18,0),
@ciudadOrigen numeric(18,0),
@ciudadDestino numeric(18,0),
@precioBasePasaje numeric(18,2),
@precioBaseKg numeric(18,2),
@tipoServicio numeric(18,0)
)
AS
BEGIN
	SELECT RA.Id,
			RA.Ciudad_Origen as CiudadOrigenId,
			C1.Nombre as CiudadOrigenNombre,
			RA.Ciudad_Destino as CiudadDestinoId,
			C2.Nombre as CiudadDestinoNombre,
			RA.Ruta_Codigo as Codigo,
			RA.Precio_BaseKG,
			RA.Precio_BasePasaje,
			RA.Tipo_Servicio as ServicioId,
			S.Descripcion as ServicioDescr,
			RA.Habilitada
	FROM Ruta_Aerea RA
	JOIN Ciudad C1
		ON RA.Ciudad_Origen=C1.Id
	JOIN Ciudad C2
		ON RA.Ciudad_Destino=C2.Id
	JOIN Servicio S
		ON RA.Tipo_Servicio=S.Id
	WHERE (CONVERT(varchar(18),Ruta_Codigo) LIKE '%'+(CONVERT(varchar(18),@codigo))+'%' OR @codigo =0)
		AND (Ciudad_Origen=@ciudadOrigen OR @ciudadOrigen is null)
		AND (Ciudad_Destino=@ciudadDestino OR @ciudadDestino is null)
		AND (Tipo_Servicio=@tipoServicio OR @tipoServicio is null)
		AND (Precio_BaseKG=@precioBaseKg OR @precioBaseKg=0)
		AND (Precio_BasePasaje=@precioBasePasaje OR @precioBasePasaje=0)
END
GO
------------------------------------------------------------------
--         SP cancela pasajes y encomiendas asociados a una ruta
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[CancelarPasajesYEncomiendas](@codigoRuta numeric(18,0),@Motivo nvarchar(255))
AS
BEGIN
	IF EXISTS(SELECT 1
				FROM [NORMALIZADOS].Pasaje P
				JOIN [NORMALIZADOS].Compra C
					ON P.Compra=C.Id
				JOIN [NORMALIZADOS].Viaje V
					ON V.Id=C.Viaje
				JOIN [NORMALIZADOS].Ruta_Aerea RA
					ON RA.Id=V.Ruta_Aerea
				WHERE RA.Ruta_Codigo=@codigoRuta
					AND P.Id NOT IN (SELECT Pasaje FROM [NORMALIZADOS].[Pasajes_Cancelados])
					AND V.Fecha_Salida>GETDATE()
				union
				SELECT 1
				FROM [NORMALIZADOS].Encomienda E
				JOIN [NORMALIZADOS].Compra C
					ON E.Id=C.Id
				JOIN [NORMALIZADOS].Viaje V
					ON V.Id=C.Viaje
				JOIN [NORMALIZADOS].Ruta_Aerea RA
					ON RA.Id=V.Ruta_Aerea
				WHERE RA.Ruta_Codigo=@codigoRuta
					AND E.Id NOT IN (SELECT Encomienda FROM [NORMALIZADOS].[Encomiendas_Canceladas])
					AND V.Fecha_Salida>GETDATE())
	BEGIN
		DECLARE @idCancelacion numeric(18,0)

		INSERT INTO [NORMALIZADOS].[Detalle_Cancelacion](Fecha,Motivo)
			VALUES(GETDATE(),@Motivo)
	
		SET @idCancelacion=SCOPE_IDENTITY()

		INSERT INTO [NORMALIZADOS].[Pasajes_Cancelados](Pasaje,Cancelacion)
			SELECT P.Id,@idCancelacion
			FROM [NORMALIZADOS].[Pasaje] P
			JOIN [NORMALIZADOS].[Compra] C
				ON P.Compra=C.Id
			JOIN [NORMALIZADOS].[Viaje] V
				ON V.Id=C.Viaje
			JOIN [NORMALIZADOS].Ruta_Aerea RA
					ON RA.Id=V.Ruta_Aerea
			WHERE RA.Ruta_Codigo=@codigoRuta
					AND V.Fecha_Salida>GETDATE()

		INSERT INTO [NORMALIZADOS].[Encomiendas_Canceladas](Encomienda,Cancelacion)
			SELECT E.Id,@idCancelacion
			FROM [NORMALIZADOS].[Encomienda] E
			JOIN [NORMALIZADOS].[Compra] C
				ON E.Compra=C.Id
			JOIN [NORMALIZADOS].[Viaje] V
				ON V.Id=C.Viaje
			JOIN [NORMALIZADOS].Ruta_Aerea RA
					ON RA.Id=V.Ruta_Aerea
			WHERE RA.Ruta_Codigo=@codigoRuta
					AND V.Fecha_Salida>GETDATE()
	END
END
GO
------------------------------------------------------------------
--         SP elimina rutas con un codigo
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[EliminarRuta](@codigoRuta numeric(18,0))
AS
BEGIN
	BEGIN TRAN transEliminar

	UPDATE [NORMALIZADOS].[Ruta_Aerea]
	SET Habilitada=0
	WHERE Ruta_Codigo=@codigoRuta

	EXEC [NORMALIZADOS].[CancelarPasajesYEncomiendas] @codigoRuta,'Baja de ruta'

	COMMIT TRAN transEliminar
	SELECT @@ROWCOUNT
END
GO------------------------------------------------------------------
--         SP verifica si existe la ruta en algun viaje
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[ExisteRutaEnViaje]
@rutaId numeric(18,0),
@Tiene_Viajes int OUTPUT
AS
BEGIN
	IF (EXISTS	(select 1 
		from [NORMALIZADOS].Viaje V
		WHERE V.Ruta_Aerea = @rutaId))
		BEGIN
			SET @Tiene_Viajes = 1;
		END
		ELSE
		BEGIN
			SET @Tiene_Viajes = 0;
		END
END
GO
------------------------------------------------------------------
--         SP genera viaje
------------------------------------------------------------------

CREATE PROCEDURE [NORMALIZADOS].[GenerarViaje]
(@fechaSalida datetime,
@fechaLlegadaEstimada datetime,
@rutaId numeric(18,0),
@nroAeronave int
)
AS
BEGIN
	INSERT INTO [NORMALIZADOS].[Viaje](Fecha_Salida,
										Fecha_Llegada_Estimada,
										Ruta_Aerea,
										Aeronave)
		VALUES(@fechaSalida,
				@fechaLlegadaEstimada,
				@rutaId,
				@nroAeronave)

	SELECT @@ROWCOUNT
END
GO
------------------------------------------------------------------
--         SP devuelve 1 si la aeronave tiene viajes programados
--				entre las fechas 
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SP_AeronaveTieneViajesProgramadosEntre](
@nroAeronave int,
@fechaDesde datetime,
@fechaHasta datetime
)
AS
BEGIN
	SELECT 1
	FROM [NORMALIZADOS].[Aeronave] A
	JOIN [NORMALIZADOS].[Viaje] V
		ON A.Numero=V.Aeronave
	JOIN [NORMALIZADOS].[Registro_De_Llegada_Destino] R
		ON V.Id = R.Viaje
	WHERE A.Numero=@nroAeronave AND( (@fechaDesde BETWEEN V.Fecha_Salida AND R.Fecha_Llegada)
		OR (@fechaHasta BETWEEN V.Fecha_Salida AND R.Fecha_Llegada))
END
GO
------------------------------------------------------------------
--         SP retorna una aeronave de acuerdo a una matricula
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SP_Get_Aeronave_By_Matricula]
@matricula nvarchar(255)
AS
BEGIN
	SELECT A.*,S.Descripcion, F.Nombre, M.Modelo_Desc
	FROM [NORMALIZADOS].[Aeronave] A
	JOIN [NORMALIZADOS].Servicio S
	ON A.Tipo_Servicio = S.Id
	JOIN [NORMALIZADOS].Fabricante F
	ON A.Fabricante = F.Id
	JOIN [NORMALIZADOS].[Modelo] M
	ON M.Id = A.Modelo
	WHERE Matricula=@matricula
END
GO
------------------------------------------------------------------
--         SP devuelve 1 si la ruta destino para una aeronave 
--			en un viaje coincide con el aeropuerto destino
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SP_Arribo_OK]
@paramNroAeronave int,
@paramCiudadOrigen int,
@paramAeropuertoDestino int
AS
BEGIN
	SELECT 1
	FROM [NORMALIZADOS].[Viaje] V
	JOIN [NORMALIZADOS].[Ruta_Aerea] RA
		ON V.Ruta_Aerea=RA.Id
		AND RA.Ciudad_Destino=@paramAeropuertoDestino
		AND RA.Ciudad_Origen=@paramCiudadOrigen
	WHERE V.Aeronave=@paramNroAeronave
		AND V.Id NOT IN (SELECT Viaje
							FROM [NORMALIZADOS].[Registro_De_Llegada_Destino]
						)
END
GO

------------------------------------------------------------------
--       Funciones y SP para Consulta de millas 
------------------------------------------------------------------
CREATE FUNCTION NORMALIZADOS.Canjes_Puntos_By_Dni(@Dni numeric(18,0),@nombre nvarchar(255),@apellido nvarchar(255))
RETURNS int
AS
	BEGIN
		DECLARE @Total int
		
		SELECT @Total = SUM(C.Cantidad * R.Puntos)
		FROM NORMALIZADOS.Canje C
		JOIN NORMALIZADOS.Recompensa R
		ON C.Recompensa = R.Id
		JOIN NORMALIZADOS.Cliente Cli
		ON Cli.Id = C.Cliente
		WHERE Cli.Dni = @Dni AND Cli.Nombre = @nombre AND Cli.Apellido = @apellido
		AND DATEDIFF(DAY,GETDATE(), C.Fecha) < 365 AND C.Fecha < GETDATE()
		GROUP BY Cli.Dni, Cli.Nombre, Cli.Apellido

		RETURN @Total
	END
GO

CREATE PROCEDURE [NORMALIZADOS].[SP_Get_Millas_By_Dni](@Dni numeric(18,0))
AS
	BEGIN
		IF EXISTS (SELECT 1 FROM NORMALIZADOS.Cliente C WHERE C.Dni = @Dni)
			BEGIN
				SELECT SUM(S.Millas) AS Millas
				FROM (
					SELECT (isnull(SUM(NORMALIZADOS.Puntos_Generados(P.Precio)),0)) AS Millas 
									FROM NORMALIZADOS.Cliente C
									JOIN NORMALIZADOS.Pasaje P ON P.Pasajero = C.Id
									JOIN NORMALIZADOS.Compra Com ON P.Compra = Com.Id
									JOIN NORMALIZADOS.Viaje V ON V.Id = Com.Viaje
									JOIN NORMALIZADOS.Registro_De_Llegada_Destino R ON V.Id = R.Viaje
									WHERE C.Dni = @Dni AND DATEDIFF(DAY,GETDATE(), Com.Fecha) < 365 AND V.Id IN (SELECT Viaje FROM NORMALIZADOS.Registro_De_Llegada_Destino) AND Com.Fecha < GETDATE()
									AND P.Codigo NOT IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados)
									GROUP BY C.Dni, C.Nombre, C.Apellido
					UNION ALL
					SELECT (isnull(SUM(NORMALIZADOS.Puntos_Generados(E.Precio)),0)
									) AS Millas 
									FROM NORMALIZADOS.Cliente C
									JOIN NORMALIZADOS.Encomienda E ON C.Id = E.Cliente
									JOIN NORMALIZADOS.Compra Com ON E.Compra = Com.Id
									JOIN NORMALIZADOS.Viaje V ON V.Id = Com.Viaje
									JOIN NORMALIZADOS.Registro_De_Llegada_Destino R ON V.Id = R.Viaje
									WHERE C.Dni = @Dni AND DATEDIFF(DAY,GETDATE(), Com.Fecha) < 365 AND V.Id IN (SELECT Viaje FROM NORMALIZADOS.Registro_De_Llegada_Destino) AND Com.Fecha < GETDATE()
									AND E.Codigo NOT IN (SELECT Encomienda FROM NORMALIZADOS.Encomiendas_Canceladas)
									GROUP BY C.Dni, C.Nombre, C.Apellido
					UNION ALL
					SELECT (isnull(SUM(-Can.Cantidad * R.Puntos),0)
									) AS Millas 
									FROM NORMALIZADOS.Cliente C
									JOIN NORMALIZADOS.Canje Can ON Can.Cliente = C.Id
									JOIN NORMALIZADOS.Recompensa R ON R.Id = Can.Recompensa
									WHERE C.Dni = @Dni AND DATEDIFF(DAY,GETDATE(), Can.Fecha) < 365 AND Can.Fecha < GETDATE()
									GROUP BY C.Dni, C.Nombre, C.Apellido
				) AS S
			END
		ELSE
			RAISERROR ('No existe un cliente con el Dni especificado', 16, 1)
	END
GO

--Procedure que trae los canjes realizados en el ultimo anio de un cliente dado su DNI.
CREATE PROCEDURE [NORMALIZADOS].[SP_Get_Canjes_By_Dni](@Dni numeric(18,0))
AS
	BEGIN
		SELECT R.Descripcion, C.Cantidad, '-'+CAST(SUM(C.Cantidad * R.Puntos) AS nvarchar(20)) AS Puntos, C.Fecha
		FROM NORMALIZADOS.Canje C
		JOIN NORMALIZADOS.Recompensa R
		ON C.Recompensa = R.Id
		JOIN NORMALIZADOS.Cliente Cli
		ON Cli.Id = C.Cliente
		WHERE Cli.Dni = @Dni AND DATEDIFF(DAY,GETDATE(), C.Fecha) < 365 AND C.Fecha < GETDATE()
		GROUP BY C.Cliente, R.Descripcion, C.Cantidad, C.Fecha
		ORDER BY 4
	END
GO

-- Procedure que trae las millas generadas en el ultimo anio para un cliente dado por su DNI. Donde la aeronave haya arribado
-- y el pasaje o la encomienda no haya sido cancelado/a.
CREATE PROCEDURE [NORMALIZADOS].[SP_Get_Detalle_Puntos_By_Dni](@Dni numeric(18,0))
AS
	BEGIN
	
		SELECT S.Codigo, S.Puntos, S.Fecha_De_Compra, S.Origen, Destino
		FROM(
			SELECT P.Codigo AS Codigo, NORMALIZADOS.Puntos_Generados(P.Precio) AS Puntos, C.Fecha AS Fecha_De_Compra, C1.Nombre AS Origen, C2.Nombre AS Destino
			FROM NORMALIZADOS.Pasaje P
			JOIN NORMALIZADOS.Compra C
			ON P.Compra = C.Id
			JOIN NORMALIZADOS.Viaje V
			ON C.Viaje = V.Id
			JOIN NORMALIZADOS.Ruta_Aerea R
			ON V.Ruta_Aerea = R.Id
			JOIN NORMALIZADOS.Ciudad C1
			ON C1.Id = R.Ciudad_Origen
			JOIN NORMALIZADOS.Ciudad C2
			ON C2.Id = R.Ciudad_Destino
			JOIN NORMALIZADOS.Cliente Cli
			ON Cli.Id = P.Pasajero
			JOIN NORMALIZADOS.Registro_De_Llegada_Destino RD
			ON RD.Viaje = V.Id
			WHERE P.Codigo NOT IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados) AND Cli.Dni = @Dni
			AND DATEDIFF(DAY,GETDATE(),C.Fecha) < 365 AND C.Fecha < GETDATE() AND V.Id IN (SELECT Viaje FROM NORMALIZADOS.Registro_De_Llegada_Destino)
			
			UNION ALL
			
			SELECT E.Codigo AS Codigo, NORMALIZADOS.Puntos_Generados(E.Precio) AS Puntos, C.Fecha AS Fecha_De_Compra, C1.Nombre AS Origen, C2.Nombre AS Destino
			FROM NORMALIZADOS.Encomienda E
			JOIN NORMALIZADOS.Compra C
			ON E.Compra = C.Id
			JOIN NORMALIZADOS.Viaje V
			ON C.Viaje = V.Id
			JOIN NORMALIZADOS.Ruta_Aerea R
			ON V.Ruta_Aerea = R.Id
			JOIN NORMALIZADOS.Ciudad C1
			ON C1.Id = R.Ciudad_Origen
			JOIN NORMALIZADOS.Ciudad C2
			ON C2.Id = R.Ciudad_Destino
			JOIN NORMALIZADOS.Cliente Cli
			ON Cli.Id = E.Cliente
			JOIN NORMALIZADOS.Registro_De_Llegada_Destino RD
			ON RD.Viaje = V.Id
			WHERE E.Codigo NOT IN (SELECT Encomienda FROM NORMALIZADOS.Encomiendas_Canceladas) AND Cli.Dni = @Dni
			AND DATEDIFF(DAY,GETDATE(),C.Fecha) < 365 AND C.Fecha < GETDATE() AND V.Id IN (SELECT Viaje FROM NORMALIZADOS.Registro_De_Llegada_Destino)
		) S
		ORDER BY Fecha_De_Compra
	END
GO

CREATE FUNCTION [NORMALIZADOS].[Get_Millas_By_Dni](@Dni numeric(18,0))
RETURNS int
AS
	BEGIN
		DECLARE @millas int

			IF EXISTS (SELECT 1 FROM NORMALIZADOS.Cliente C WHERE C.Dni = @Dni)
			BEGIN
				SELECT @millas = SUM(S.Millas)
				FROM (
					SELECT (isnull(SUM(NORMALIZADOS.Puntos_Generados(P.Precio)),0)) AS Millas 
									FROM NORMALIZADOS.Cliente C
									JOIN NORMALIZADOS.Pasaje P ON P.Pasajero = C.Id
									JOIN NORMALIZADOS.Compra Com ON P.Compra = Com.Id
									JOIN NORMALIZADOS.Viaje V ON V.Id = Com.Viaje
									JOIN NORMALIZADOS.Registro_De_Llegada_Destino R ON V.Id = R.Viaje
									WHERE C.Dni = @Dni AND DATEDIFF(DAY,GETDATE(), Com.Fecha) < 365 AND V.Id IN (SELECT Viaje FROM NORMALIZADOS.Registro_De_Llegada_Destino) AND Com.Fecha < GETDATE()
									AND P.Codigo NOT IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados)
									GROUP BY C.Dni, C.Nombre, C.Apellido
					UNION ALL
					SELECT (isnull(SUM(NORMALIZADOS.Puntos_Generados(E.Precio)),0)
									) AS Millas 
									FROM NORMALIZADOS.Cliente C
									JOIN NORMALIZADOS.Encomienda E ON C.Id = E.Cliente
									JOIN NORMALIZADOS.Compra Com ON E.Compra = Com.Id
									JOIN NORMALIZADOS.Viaje V ON V.Id = Com.Viaje
									JOIN NORMALIZADOS.Registro_De_Llegada_Destino R ON V.Id = R.Viaje
									WHERE C.Dni = @Dni AND DATEDIFF(DAY,GETDATE(), Com.Fecha) < 365 AND V.Id IN (SELECT Viaje FROM NORMALIZADOS.Registro_De_Llegada_Destino) AND Com.Fecha < GETDATE()
									AND E.Codigo NOT IN (SELECT Encomienda FROM NORMALIZADOS.Encomiendas_Canceladas)
									GROUP BY C.Dni, C.Nombre, C.Apellido
					UNION ALL
					SELECT (isnull(SUM(-Can.Cantidad * R.Puntos),0)
									) AS Millas 
									FROM NORMALIZADOS.Cliente C
									JOIN NORMALIZADOS.Canje Can ON Can.Cliente = C.Id
									JOIN NORMALIZADOS.Recompensa R ON R.Id = Can.Recompensa
									WHERE C.Dni = @Dni AND DATEDIFF(DAY,GETDATE(), Can.Fecha) < 365 AND Can.Fecha < GETDATE()
									GROUP BY C.Dni, C.Nombre, C.Apellido
				) AS S
			END

		RETURN @millas
	END
GO

CREATE PROCEDURE NORMALIZADOS.SP_Canje_Millas(@dni numeric(18,0), @producto int, @cantidad int)
AS
	BEGIN

		DECLARE @cliID numeric(18,0)

		DECLARE @puntosP int

		DECLARE @puntosCambio int

		DECLARE @millasDisponibles int

		DECLARE @stock int

		SELECT @cliID = C.Id
		FROM NORMALIZADOS.Cliente C
		WHERE C.Dni = @dni

		SELECT @puntosP = R.Puntos
		FROM NORMALIZADOS.Recompensa R
		WHERE R.Id = @producto

		SET @puntosCambio = @puntosP * @cantidad

		SELECT @millasDisponibles = NORMALIZADOS.Get_Millas_By_Dni(@dni)

		IF(@millasDisponibles>@puntosCambio)
			BEGIN
				BEGIN TRAN T1
					INSERT INTO NORMALIZADOS.Canje (Cliente, Recompensa, Cantidad, Fecha)
					VALUES (@cliID, @producto, @cantidad, GETDATE());	

					SELECT @stock = Stock FROM NORMALIZADOS.Recompensa WHERE Id = @producto

					UPDATE NORMALIZADOS.Recompensa
					SET Stock = @stock - @cantidad
					WHERE Id = @producto
				COMMIT TRAN T1
			END

		ELSE
			BEGIN
				RAISERROR ('No es posible realizar el canje', 16, 1)
			END
	END
GO


CREATE PROCEDURE NORMALIZADOS.SP_Get_Recompensas
AS
	BEGIN
		SELECT Id, Descripcion, Puntos, Stock
		FROM NORMALIZADOS.Recompensa
	END
GO
------------------------------------------------------------------
--         SP registra llegada a destino de una aeronave
--			en un determinado viaje
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SaveRegistroLlegadaDestino]
@paramMatricula nvarchar(255),
@paramAeropuertoDestino int,
@paramCiudadOrigen int,
@paramFechaLlegada datetime
AS
BEGIN
	INSERT INTO [NORMALIZADOS].[Registro_De_Llegada_Destino](Viaje,Aeropuerto_Destino,Fecha_Llegada)
	SELECT V.Id,@paramAeropuertoDestino,@paramFechaLlegada
	FROM [NORMALIZADOS].[Viaje] V
	JOIN [NORMALIZADOS].[Aeronave] A
		ON V.Aeronave=A.Numero
		AND A.Matricula=@paramMatricula
	JOIN [NORMALIZADOS].[Ruta_Aerea] RA
		ON RA.Id=V.Ruta_Aerea
		AND RA.Ciudad_Origen=@paramCiudadOrigen
	WHERE V.Id NOT IN (SELECT Viaje
						FROM [NORMALIZADOS].[Registro_De_Llegada_Destino]
						)

	SELECT @@ROWCOUNT
END
GO
----------------------------------------------------------------
-- Valida que el pasajero no tenga otro vuelo superpuesto con 
-- el que se va a comprar
-- return 0 si se solapan los viajes
--		  1 en otro caso
----------------------------------------------------------------

CREATE FUNCTION [NORMALIZADOS].[Validar_PasajesEnCompra](@dniPasajero numeric(18,0), @fecha_salida datetime, @fecha_llegada_estimada datetime)
RETURNS BIT
AS
	BEGIN

		DECLARE @retorno BIT

		IF EXISTS(SELECT 1
				FROM NORMALIZADOS.Pasaje P
				JOIN NORMALIZADOS.Cliente CL
					ON P.Pasajero=CL.Id
				JOIN NORMALIZADOS.Compra C
				ON P.Compra = C.Id
				JOIN NORMALIZADOS.Viaje V
				ON V.Id = C.Viaje
				WHERE CL.Dni = @dniPasajero AND (@fecha_salida BETWEEN V.Fecha_Salida AND V.Fecha_Llegada_Estimada OR
				@fecha_llegada_estimada BETWEEN V.Fecha_Salida AND V.Fecha_Llegada_Estimada)
				AND P.Id NOT IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados))
			SET @retorno = 0

		ELSE
			IF EXISTS (SELECT 1
					FROM NORMALIZADOS.Pasaje P
					JOIN NORMALIZADOS.Cliente CL
					ON P.Pasajero=CL.Id
					JOIN NORMALIZADOS.Compra C
					ON P.Compra = C.Id
					JOIN NORMALIZADOS.Viaje V
					ON V.Id = C.Viaje
					WHERE CL.Dni = @dniPasajero AND @fecha_llegada_estimada > V.Fecha_Llegada_Estimada
					AND @fecha_salida < V.Fecha_Salida
					AND P.Id NOT IN (SELECT Pasaje FROM NORMALIZADOS.Pasajes_Cancelados))
			SET @retorno = 0

				ELSE
					SET @retorno = 1

		RETURN @retorno
	END
GO
------------------------------------------------------------------
--         SP devuelve datos de cliente a partir del DNI
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetCliente_SEL_ByDNI]
@paramDNI numeric(18,0)
AS
BEGIN
	SELECT*
	FROM [NORMALIZADOS].[Cliente]
	WHERE Dni=@paramDNI
END
GO
------------------------------------------------------------------
--         SP actualiza datos de un cliente a partir del DNI
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[UpdateCliente]
@paramNombre nvarchar(255),
@paramApellido nvarchar(255),
@paramDni numeric(18,0),
@paramDireccion nvarchar(255),
@paramFechaNac datetime,
@paramMail nvarchar(255),
@paramTelefono numeric(18,0)
AS
BEGIN
	UPDATE [NORMALIZADOS].[Cliente]
	SET Nombre=@paramNombre,
		Apellido=@paramApellido,
		Direccion=@paramDireccion,
		Fecha_Nac=@paramFechaNac,
		Mail=@paramMail,
		Telefono=@paramTelefono
	WHERE Dni=@paramDni

	SELECT @@ROWCOUNT
END
GO
------------------------------------------------------------------
--         SP registra datos de un cliente
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SaveCliente_INS](
@paramNombre nvarchar(255),
@paramApellido nvarchar(255),
@paramDni numeric(18,0),
@paramDireccion nvarchar(255),
@paramFechaNac datetime,
@paramMail nvarchar(255),
@paramTelefono numeric(18,0)
)
AS
BEGIN
	INSERT INTO [NORMALIZADOS].[Cliente](Nombre,
										Apellido,
										Dni,
										Telefono,
										Direccion,
										Fecha_Nac,
										Mail)
							VALUES(@paramNombre,
									@paramApellido,
									@paramDni,
									@paramTelefono,
									@paramDireccion,
									@paramFechaNac,
									@paramMail)
END
GO
------------------------------------------------------------------
--         SP devuelve todos los tipos de pago
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetAllTipoPago_SEL]
AS
BEGIN
	SELECT Id,Descripcion
	FROM [Tipo_Pago]
END
GO
------------------------------------------------------------------
--         SP devuelve viajes disponibles para 
--				una fecha de entrada,fecha de salida,
--				ciudad de origen y ciudad de destino
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetViajes_SEL_ByFechasCiudades]
@paramFechaSalida datetime,
@paramFechaLlegadaEstimada datetime,
@paramCiudadOrigen int,
@paramCiudadDestino int
AS
BEGIN
	IF(YEAR(@paramFechaSalida) = YEAR(GETDATE())
		AND MONTH(@paramFechaSalida) = MONTH(GETDATE())
		AND DAY(@paramFechaSalida)= DAY(GETDATE()))
	BEGIN
		SELECT V.Id,
			V.Fecha_Salida,
			V.Fecha_Llegada_Estimada,
			V.Ruta_Aerea,
			C1.Nombre as CiudadOrigenNombre,
			C2.Nombre as CiudadDestinoNombre,
			V.Aeronave,
			A.Matricula,
			A.Tipo_Servicio,
			S.Descripcion,
			ISNULL([NORMALIZADOS].[GetCantidadButacasDisponibles](V.Id),0) as CantButacasDisponibles,
			ISNULL([NORMALIZADOS].[KGs_Disponibles](V.Id),0) as KGs_Disponibles
		FROM [NORMALIZADOS].[Viaje] V
		JOIN [NORMALIZADOS].[Ruta_Aerea] RA
			ON V.Ruta_Aerea=RA.Id
			AND RA.Habilitada=1
			AND RA.Ciudad_Origen=@paramCiudadOrigen
			AND RA.Ciudad_Destino=@paramCiudadDestino
		JOIN [NORMALIZADOS].[Ciudad] C1
			ON C1.Id=RA.Ciudad_Origen
		JOIN [NORMALIZADOS].[Ciudad] C2
			ON C2.Id=RA.Ciudad_Destino
		JOIN [NORMALIZADOS].[Aeronave] A
			ON V.Aeronave=A.Numero
		JOIN [NORMALIZADOS].[Servicio] S
			ON S.Id=A.Tipo_Servicio
		WHERE YEAR(Fecha_Salida)=YEAR(@paramFechaSalida)
			AND MONTH(Fecha_Salida)=MONTH(@paramFechaSalida)
			AND DAY(Fecha_Salida)=DAY(@paramFechaSalida)
			AND YEAR(Fecha_Llegada_Estimada)=YEAR(@paramFechaLlegadaEstimada)
			AND MONTH(Fecha_Llegada_Estimada)=MONTH(@paramFechaLlegadaEstimada)
			AND DAY(Fecha_Llegada_Estimada)=DAY(@paramFechaLlegadaEstimada)
			AND (DATEPART(HOUR,Fecha_Salida) - DATEPART(HOUR,@paramFechaSalida)) > 2
	END
	ELSE
	BEGIN
		SELECT V.Id,
			V.Fecha_Salida,
			V.Fecha_Llegada_Estimada,
			V.Ruta_Aerea,
			C1.Nombre as CiudadOrigenNombre,
			C2.Nombre as CiudadDestinoNombre,
			V.Aeronave,
			A.Matricula,
			A.Tipo_Servicio,
			S.Descripcion,
			ISNULL([NORMALIZADOS].[GetCantidadButacasDisponibles](V.Id),0) as CantButacasDisponibles,
			ISNULL([NORMALIZADOS].[KGs_Disponibles](V.Id),0) as KGs_Disponibles
		FROM [NORMALIZADOS].[Viaje] V
		JOIN [NORMALIZADOS].[Ruta_Aerea] RA
			ON V.Ruta_Aerea=RA.Id
			AND RA.Habilitada=1
			AND RA.Ciudad_Origen=@paramCiudadOrigen
			AND RA.Ciudad_Destino=@paramCiudadDestino
		JOIN [NORMALIZADOS].[Ciudad] C1
			ON C1.Id=RA.Ciudad_Origen
		JOIN [NORMALIZADOS].[Ciudad] C2
			ON C2.Id=RA.Ciudad_Destino
		JOIN [NORMALIZADOS].[Aeronave] A
			ON V.Aeronave=A.Numero
		JOIN [NORMALIZADOS].[Servicio] S
			ON S.Id=A.Tipo_Servicio
		WHERE YEAR(Fecha_Salida)=YEAR(@paramFechaSalida)
			AND MONTH(Fecha_Salida)=MONTH(@paramFechaSalida)
			AND DAY(Fecha_Salida)=DAY(@paramFechaSalida)
			AND YEAR(Fecha_Llegada_Estimada)=YEAR(@paramFechaLlegadaEstimada)
			AND MONTH(Fecha_Llegada_Estimada)=MONTH(@paramFechaLlegadaEstimada)
			AND DAY(Fecha_Llegada_Estimada)=DAY(@paramFechaLlegadaEstimada)
	END
END
GO

------------------------------------------------------------------
--         SP devuelve todos los tipos de tarjeta
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetAllTipoTarjeta_SEL]
AS
BEGIN
	SELECT*
	FROM [NORMALIZADOS].[Tipo_Tarjeta]
END
GO
------------------------------------------------------------------
--         SP registra una tarjeta de credito
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SaveTarjeta]
@paramNro bigint,
@paramCodigo int,
@paramFechaVencimiento int,
@paramTipoTarjeta int
AS
BEGIN
	IF NOT EXISTS(SELECT 1
					FROM [NORMALIZADOS].[Tarjeta_Credito]
					WHERE Nro=@paramNro
					)
	BEGIN
		INSERT INTO [NORMALIZADOS].[Tarjeta_Credito](Nro,Codigo,Fecha_Vencimiento,Tipo_Tarjeta)
			VALUES(@paramNro,@paramCodigo,@paramFechaVencimiento,@paramTipoTarjeta)
	END
END
GO
------------------------------------------------------------------
--         SP registra una compra y devuelve PNR y Id de Compra
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SaveCompra]
@paramPNR nvarchar(255) OUTPUT,
@paramIdCompra int OUTPUT,
@paramComprador numeric(18,0),
@paramMedioPago int,
@paramTarjeta bigint,
@paramViaje int
AS
BEGIN
	DECLARE @IdCompra int

	INSERT INTO [NORMALIZADOS].[Compra](Fecha,Comprador,Medio_Pago,Tarjeta_Credito,Viaje)
		VALUES(GETDATE(), @paramComprador, @paramMedioPago, @paramTarjeta, @paramViaje)

	SET @paramIdCompra=SCOPE_IDENTITY()

	UPDATE [NORMALIZADOS].[Compra]
	SET PNR=CONVERT(nvarchar(255),Fecha,112)+CAST(Id AS nvarchar(255))
	WHERE Id=@paramIdCompra

	SELECT @paramPNR=PNR
	FROM [NORMALIZADOS].[Compra]
	WHERE Id=@paramIdCompra
END
GO
------------------------------------------------------------------
--         SP registra un pasaje y devuelve su precio
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SaveEncomienda]
@paramPrecio numeric(18,2) OUTPUT,
@paramKg numeric(18,0),
@paramCompra int,
@paramCliente numeric(18,0)
AS
BEGIN
		DECLARE @C_codigo numeric(18,0)
		SET @C_codigo= [NORMALIZADOS].[Codigo_Maximo]()+1

		SELECT @paramPrecio=RA.Precio_BaseKG*S.Porcentaje_Adicional+RA.Precio_BaseKG
		FROM [NORMALIZADOS].[Servicio] S
		JOIN [NORMALIZADOS].[Ruta_Aerea] RA
			ON S.Id=RA.Tipo_Servicio
		JOIN [NORMALIZADOS].[Viaje] V
			ON V.Ruta_Aerea=RA.Id
		JOIN [NORMALIZADOS].[Compra] C
			ON V.Id=C.Viaje
			AND C.Id=@paramCompra

		INSERT INTO [NORMALIZADOS].[Encomienda](Precio,Kg,Cliente,Compra,Codigo)
			VALUES(@paramPrecio,@paramKg,@paramCliente,@paramCompra,@C_codigo)
END
GO
------------------------------------------------------------------
--         SP registra una encomienda y devuelve su precio
------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[SavePasaje]
@paramPrecio numeric(18,2) OUTPUT,
@paramButaca int,
@paramCompra int,
@paramPasajero numeric(18,0)
AS
BEGIN
		DECLARE @C_codigo numeric(18,0)
		SET @C_codigo= [NORMALIZADOS].[Codigo_Maximo]()+1

		SELECT @paramPrecio=RA.Precio_BasePasaje*S.Porcentaje_Adicional+RA.Precio_BasePasaje
		FROM [NORMALIZADOS].[Servicio] S
		JOIN [NORMALIZADOS].[Ruta_Aerea] RA
			ON S.Id=RA.Tipo_Servicio
		JOIN [NORMALIZADOS].[Viaje] V
			ON V.Ruta_Aerea=RA.Id
		JOIN [NORMALIZADOS].[Compra] C
			ON V.Id=C.Viaje
			AND C.Id=@paramCompra

		INSERT INTO [NORMALIZADOS].[Pasaje](Precio,Butaca,Pasajero,Compra,Codigo)
			VALUES(@paramPrecio,@paramButaca,@paramPasajero,@paramCompra,@C_codigo)
END
GO

--------------------------------------------------------------------
--         Devuelve el codigo maximo de pasaje / encomienda
--------------------------------------------------------------------
CREATE FUNCTION NORMALIZADOS.Codigo_Maximo()
RETURNS numeric(18,0)
AS
	BEGIN
		DECLARE @maximo numeric(18,0)

		SELECT @maximo = MAX(T.Codigo)
		FROM
		(SELECT Codigo FROM NORMALIZADOS.Pasaje
		UNION ALL
		SELECT Codigo FROM NORMALIZADOS.Encomienda) T

		RETURN @maximo
	END
GO

--------------------------------------------------------------------
--        Cancelar compra completa por pedido del cliente
--------------------------------------------------------------------
CREATE PROCEDURE NORMALIZADOS.Cancelar_Compra
@pnr nvarchar(255),
@motivo nvarchar(255)
AS
	BEGIN
 		DECLARE @id_compra int
 		DECLARE @idCancelacion int
		DECLARE @pasajes_cancelados int
		DECLARE @encomiendas_canceladas int
		DECLARE @pasaje int
		DECLARE @encomienda int
		DECLARE @retorno int
			
		SET @pasajes_cancelados = 0
		SET @encomiendas_canceladas = 0
		SET @retorno = -1

 		SELECT @id_compra = Id
 		FROM NORMALIZADOS.Compra
 		WHERE PNR LIKE @pnr
 		

 		IF (@id_compra IS NOT NULL)
 			BEGIN
				SET @retorno = 0

 				INSERT INTO NORMALIZADOS.Detalle_Cancelacion (Fecha,Motivo)
 				VALUES (GETDATE(),@motivo)
 
 				SET @idCancelacion = SCOPE_IDENTITY()
 
			
				DECLARE Pasajes CURSOR FOR
				SELECT P.Id from NORMALIZADOS.Pasaje P
				WHERE P.Compra = @id_compra

				OPEN Pasajes
				FETCH NEXT FROM Pasajes INTO @pasaje
				WHILE @@FETCH_STATUS = 0
					BEGIN
						IF NOT EXISTS (SELECT 1 FROM NORMALIZADOS.Pasajes_Cancelados PC 
										WHERE PC.Pasaje = @pasaje)
							BEGIN
								INSERT INTO NORMALIZADOS.Pasajes_Cancelados (Pasaje,Cancelacion)
									VALUES (@pasaje,@idCancelacion)

								SET @pasajes_cancelados = @pasajes_cancelados + 1
							END
						
						FETCH NEXT FROM Pasajes INTO @pasaje
					END
				CLOSE Pasajes
				DEALLOCATE Pasajes
 				
				DECLARE Encomiendas CURSOR FOR
				SELECT E.Id from NORMALIZADOS.Encomienda E
				WHERE E.Compra = @id_compra

				OPEN Encomiendas
				FETCH NEXT FROM Encomiendas INTO @encomienda
				WHILE @@FETCH_STATUS = 0
					BEGIN
						IF NOT EXISTS (SELECT 1 FROM NORMALIZADOS.Encomiendas_Canceladas EC
										WHERE EC.Encomienda = @encomienda)
							BEGIN
								INSERT INTO NORMALIZADOS.Encomiendas_Canceladas (Encomienda, Cancelacion)
									VALUES (@encomienda,@idCancelacion)	
									
								SET @encomiendas_canceladas = @encomiendas_canceladas + 1
							END							
						
						FETCH NEXT FROM Encomiendas INTO @encomienda
					END
				CLOSE Encomiendas
				DEALLOCATE Encomiendas

				SET @retorno = @pasajes_cancelados + @encomiendas_canceladas
 			END

		SELECT @retorno
 	END
 GO
 
--------------------------------------------------------------------
--        Cancelar un pasaje por pedido del cliente
--------------------------------------------------------------------
CREATE PROCEDURE NORMALIZADOS.Cancelar_Pasaje
@codigo numeric(18,8),
@motivo int
AS
	BEGIN
		DECLARE @pasaje int
		DECLARE @retorno int
		
		SELECT @pasaje = P.Id
		FROM NORMALIZADOS.Pasaje P
		WHERE P.Codigo = @codigo

		SET @retorno = -1
		
		IF (@pasaje IS NOT NULL)
			BEGIN
				IF EXISTS (SELECT 1 FROM NORMALIZADOS.Pasaje P
								JOIN NORMALIZADOS.Pasajes_Cancelados PC
								ON P.Id = PC.Pasaje
								WHERE P.Id = @pasaje)

					BEGIN
						SET @retorno = 0
					END
				ELSE
					BEGIN
						INSERT INTO NORMALIZADOS.Pasajes_Cancelados (Pasaje,Cancelacion)
							VALUES (@pasaje,@motivo)
							
						SET @retorno = @@ROWCOUNT
					END			
			END
		SELECT @retorno
	END
GO
--------------------------------------------------------------------
--        Cancelar una encomienda por pedido del cliente
--------------------------------------------------------------------
CREATE PROCEDURE NORMALIZADOS.Cancelar_Encomienda
@codigo numeric(18,8), 
@motivo int
AS
	BEGIN
	
		DECLARE @encomienda int
		DECLARE @retorno int

		SELECT @encomienda = E.Id
		FROM NORMALIZADOS.Encomienda E
		WHERE E.Codigo = @codigo

		SET @retorno = -1

		IF (@encomienda IS NOT NULL)
			BEGIN
				IF EXISTS (SELECT 1 FROM NORMALIZADOS.Encomienda E
								JOIN NORMALIZADOS.Encomiendas_Canceladas EC
								ON E.Id = EC.Encomienda
								WHERE E.Id = @encomienda)

					BEGIN
						SET @retorno = 0
					END
				ELSE
					BEGIN
						INSERT INTO NORMALIZADOS.Encomiendas_Canceladas (Encomienda,Cancelacion)
						VALUES (@encomienda,@motivo)

						SET @retorno = @@ROWCOUNT
					END
			END
		SELECT @retorno
	END
GO
--------------------------------------------------------------------
--        Crear motivo en detalle cancelacion
--------------------------------------------------------------------
CREATE PROCEDURE NORMALIZADOS.Crear_Detalle_Cancelacion (@motivo nvarchar(255), @idCancelacion int output)
AS
	BEGIN
		
		INSERT INTO NORMALIZADOS.Detalle_Cancelacion (Fecha, Motivo)
		VALUES(GETDATE(),@motivo)

		SET @idCancelacion = SCOPE_IDENTITY()
		
		RETURN @idcancelacion
	END
GO	
--------------------------------------------------------------------
--        SP devuelve las butacas disponibles para compra 
--			y que se encuentran	habilitadas
--------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetButacasDisponibles_SEL_ByAeronave]
@paramNroAeronave int,
@paramViaje int
AS
BEGIN
	SELECT B.*, TB.Descripcion
	FROM [NORMALIZADOS].[Butaca] B
	JOIN [NORMALIZADOS].[Tipo_Butaca] TB
	ON TB.Id = B.Tipo_Butaca
	WHERE Aeronave = @paramNroAeronave
		AND B.Habilitada=1
		AND B.Id NOT IN (SELECT Butaca
							FROM [NORMALIZADOS].[Pasaje] P
							JOIN [NORMALIZADOS].[Compra] C
								ON P.Compra=C.Id
								AND c.Viaje=@paramViaje
							)
END
GO
--------------------------------------------------------------------
--        SP devuelve 1 si ya existe el viaje con una misma
--			aeronave,ruta,fecha de salida y estimada
--------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[ExistViaje]
@paramNroAeronave int,
@paramFechaSalida datetime,
@paramFechaLlegadaEstimada datetime
AS
BEGIN

	SELECT 1
	FROM [NORMALIZADOS].[Viaje]
	WHERE YEAR(Fecha_Salida)=YEAR(@paramFechaSalida)
		AND MONTH(Fecha_Salida)=MONTH(@paramFechaSalida)
		AND DAY(Fecha_Salida)=DAY(@paramFechaSalida)
		AND YEAR(Fecha_Llegada_Estimada)=YEAR(@paramFechaLlegadaEstimada)
		AND MONTH(Fecha_Llegada_Estimada)=MONTH(@paramFechaLlegadaEstimada)
		AND DAY(Fecha_Llegada_Estimada)=DAY(@paramFechaLlegadaEstimada)
		AND Aeronave=@paramNroAeronave
END
GO
--------------------------------------------------------------------
--        SP devuelve aeronaves a partir de filtros
--------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetAeronaveByFiltersParaViajes]
	@CiudadOrigen int,
	@CiudadDestino int,
	@FechaSalida datetime,
	@Modelo nvarchar(255),
	@Matricula nvarchar(255),
	@Kg_Disponibles numeric(18,0),
	@Fabricante nvarchar(255),
	@Tipo_Servicio nvarchar(255),
	@Fecha_Alta datetime,
	@Fecha_Alta_Fin datetime

	AS
	SELECT A.*, S.Descripcion, F.Nombre, M.Modelo_Desc
	FROM [NORMALIZADOS].[Aeronaves_Para_Viaje](@CiudadOrigen,@CiudadDestino,@FechaSalida) AFE
	JOIN [NORMALIZADOS].Aeronave A
	ON A.Numero=AFE.Numero
	LEFT JOIN [NORMALIZADOS].Servicio S
	ON A.Tipo_Servicio = S.Id
	LEFT JOIN [NORMALIZADOS].Fabricante F
	ON A.Fabricante = F.Id
	LEFT JOIN [NORMALIZADOS].[Modelo] M
	ON M.Id = A.Modelo
	WHERE (M.Modelo_Desc like @Modelo OR @Modelo is null)
		AND (A.Matricula like @Matricula OR @Matricula like '')
		AND (A.Kg_Disponibles = @Kg_Disponibles OR @Kg_Disponibles = 0)
		AND (F.Nombre like @Fabricante OR @Fabricante is null)
		AND (S.Descripcion like @Tipo_Servicio OR @Tipo_Servicio is null)
		AND (A.Fecha_Alta > @Fecha_Alta OR @Fecha_Alta is null) 
		AND (A.Fecha_Alta < @Fecha_Alta_Fin OR @Fecha_Alta_Fin is null) 
GO
--------------------------------------------------------------------
--        SP devuelve una ruta a partir del id
--------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetRutaById]
@paramId numeric(18,0)
AS
BEGIN
	SELECT RA.Id,
			Ruta_Codigo as codigo,
			Ciudad_Origen as CiudadOrigenId,
			C1.Nombre as CiudadOrigenNombre,
			Ciudad_Destino as CiudadDestinoId,
			C2.Nombre as CiudadDestinoNombre,
			Precio_BasePasaje,
			Precio_BaseKG,
			Tipo_Servicio as ServicioId,
			Habilitada,
			S.Descripcion as ServicioDescr
	FROM [NORMALIZADOS].[Ruta_Aerea] RA
	JOIN [NORMALIZADOS].[Ciudad] C1
		ON RA.Ciudad_Origen=C1.Id
	JOIN [NORMALIZADOS].[Ciudad] C2
		ON RA.Ciudad_Destino=C2.Id
	JOIN [NORMALIZADOS].[Servicio] S
		ON S.Id=RA.Tipo_Servicio
	WHERE RA.Id=@paramId
END
GO
--------------------------------------------------------------------
--        SP devuelve pasajes asociados a una compra con
--			un determinado Pnr
--------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetPasajesByPnr]
@paramPnr nvarchar(255)
AS
BEGIN
	SELECT P.Id,P.Codigo,P.Precio
	FROM [NORMALIZADOS].[Pasaje] P
	JOIN [NORMALIZADOS].[Compra] C
		ON P.Compra=C.Id
		AND C.PNR=@paramPnr
	WHERE P.Id NOT IN (SELECT Pasaje
						FROM [NORMALIZADOS].[Pasajes_Cancelados]
						)
END
GO
--------------------------------------------------------------------
--        SP devuelve una encomienda asociada a una compra con
--			un determinado Pnr
--------------------------------------------------------------------
CREATE PROCEDURE [NORMALIZADOS].[GetEncomiendaByPnr]
@paramPnr nvarchar(255)
AS
BEGIN
	SELECT E.Id,E.Codigo,E.Precio,E.Kg
	FROM [NORMALIZADOS].[Encomienda] E
	JOIN [NORMALIZADOS].[Compra] C
		ON E.Compra=C.Id
		AND C.PNR=@paramPnr
	WHERE E.Id NOT IN (SELECT Encomienda
						FROM [NORMALIZADOS].[Encomiendas_Canceladas]
						)
END
GO

-------------------------------------------------------------------
--       SP reemplaza una aeronava
-------------------------------------------------------------------
CREATE PROCEDURE NORMALIZADOS.SP_Reemplazar_Aeronave @aeronave int, @fecha datetime
AS
	BEGIN
		DECLARE @modelo int
		DECLARE @fabricante int
		DECLARE @tipo_servicio int
		DECLARE @ciudadOrigen int
		DECLARE @posibleReemplazo int
		DECLARE @ultimoDestino int
		DECLARE @tieneViajes bit
		DECLARE @retorno int
		
		SET @retorno = -1

		SELECT TOP 1 @ciudadOrigen = R.Aeropuerto_Destino
		FROM NORMALIZADOS.Registro_De_Llegada_Destino R
		WHERE R.Fecha_Llegada < @fecha
		ORDER BY R.Fecha_Llegada

		SELECT @modelo = A.modelo, @fabricante = A.Fabricante, @tipo_servicio = A.Tipo_Servicio
		FROM NORMALIZADOS.Aeronave A
		WHERE A.Numero = @aeronave

		DECLARE Aeronaves CURSOR FOR
			SELECT A.Numero FROM NORMALIZADOS.Aeronave A 
			WHERE A.Modelo = @modelo AND A.Fabricante = @fabricante AND A.Tipo_Servicio = @tipo_servicio AND A.Estado = 1 AND A.Numero <> @aeronave

		OPEN Aeronaves
		FETCH NEXT FROM Aeronaves INTO @posibleReemplazo
		WHILE @@FETCH_STATUS = 0
			BEGIN

				SET @tieneViajes = 1
				
				SELECT TOP 1 @ultimoDestino = R.Aeropuerto_Destino
				FROM NORMALIZADOS.Registro_De_Llegada_Destino R
				WHERE R.Fecha_Llegada < @fecha
				ORDER BY R.Fecha_Llegada

				IF NOT EXISTS(SELECT 1 FROM NORMALIZADOS.Viaje V
							JOIN NORMALIZADOS.Baja_Temporal_Aeronave B ON V.Aeronave = B.Aeronave
							WHERE (V.Fecha_Salida > @fecha OR @fecha BETWEEN V.Fecha_Salida AND V.Fecha_Llegada_Estimada OR B.Fecha_Vuelta_Al_Servicio >@fecha) 
							AND V.Aeronave = @posibleReemplazo) --Tiene viajes en el futuro o esta volando
					BEGIN
						UPDATE NORMALIZADOS.Viaje 
							SET Aeronave = @posibleReemplazo
							WHERE Fecha_Salida > @fecha AND Aeronave = @aeronave

						SET @retorno = @posibleReemplazo
						BREAK
					END

				FETCH NEXT FROM Aeronaves INTO @posibleReemplazo
			END
			
			CLOSE Aeronaves
			DEALLOCATE Aeronaves	

		SELECT @retorno

	END
GO
