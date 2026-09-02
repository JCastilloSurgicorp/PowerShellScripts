SELECT * FROM [dbo].[RC_PROVINCIA]

-- consulta a sub gasto
SELECT * FROM [dbo].[RC_SUB_GASTO]

-- consulta a tipo gasto
SELECT * FROM [dbo].[RC_TIPO_GASTO]

-- consulta a la cabecera de cajachica
SELECT * FROM [dbo].[REQUERIMIENTO_CAJACHICA]

-- consulta a los detalles de cajachica
SELECT * FROM [dbo].[RC_DETALLE]

-- Consulta a los hospitales e instituciones
SELECT * FROM [dbo].[RC_ENTIDADES]

--INSERT INTO [RC_ENTIDADES] (NOMBRE)
--	Values('institucion2|LIMA');

--DELETE FROM [RC_ENTIDADES] 
--DBCC CHECKIDENT('RC_ENTIDADES', RESEED, 0)
--DROP TABLE RC_PROVINCIA_copy

---- Hacer Copiar de tabla sin importar el formato ----
SELECT * INTO [SA_TIPO_CATEGORIA_copy] FROM [SA_TIPO_CATEGORIA];

--INSERT INTO [RC_SUB_GASTO] ([NOMBRE]) SELECT * FROM [RC_SUB_GASTO_copy]

---- Restaurar la tabla con todo y ID ----
--SET IDENTITY_INSERT [RC_DETALLE] ON;

---- 2. Insertar especificando los campos uno por uno (Ejemplo)
--INSERT INTO [RC_DETALLE] (id, 
--			[LIMA_PROVINCIA]
--           ,[NRO_FACTURA]
--           ,[NRO_RUC]
--           ,[COSTO]
--           ,[DETALLE]
--           ,[FECHA_GASTO]
--           ,[adj_cajachica]
--           ,[DESTINO_ID]
--           ,[ORIGEN_ID]
--           ,[REQUERIMIENTO_ID]
--           ,[SUBGASTO_ID])
--SELECT id, [LIMA_PROVINCIA]
--           ,[NRO_FACTURA]
--           ,[NRO_RUC]
--           ,[COSTO]
--           ,[DETALLE]
--           ,[FECHA_GASTO]
--           ,[adj_cajachica]
--           ,[DESTINO_ID]
--           ,[ORIGEN_ID]
--           ,[REQUERIMIENTO_ID]
--           ,[SUBGASTO_ID]
--FROM [RC_DETALLE_copy];

---- 3. Apagar la opción para volver al comportamiento normal
--SET IDENTITY_INSERT [RC_DETALLE] OFF;
SELECT * FROM [dbo].[USR_VTTVND]