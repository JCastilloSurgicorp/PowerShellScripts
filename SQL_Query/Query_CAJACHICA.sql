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

INSERT INTO [RC_ENTIDADES] (NOMBRE)
	Values('institucion2|LIMA');

--DELETE FROM [RC_ENTIDADES] 
--DBCC CHECKIDENT('RC_ENTIDADES', RESEED, 0)

