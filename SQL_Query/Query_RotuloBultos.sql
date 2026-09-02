SELECT * FROM [dbo].[RB_BULTOS_CONSIGNATARIOS]
SELECT * FROM [dbo].[RB_CONSIGNATARIOS]
SELECT * FROM [dbo].[RB_DESTINO_ETIQUETA]
SELECT * FROM [dbo].[RB_GUIAS_REMISION]
SELECT * FROM [dbo].[ROTULADO_BULTOS]



-- Consultas a Representantes
SELECT * FROM [dbo].[USR_VTTVND]
SELECT * FROM [dbo].[RB_REPRESENTANTES]

-- Consultas a RB Audits
SELECT * FROM [dbo].[RB_UPDATE_AUDIT]
ORDER BY id desc




-- Consultas a la tabla ID de Pedidos
SELECT * FROM [dbo].[USR_IDPAPP]
ORDER BY IDPAPP_NROAPP desc

-- Consulta a tabla clientes de OFISIS
SELECT * FROM [dbo].[USR_VTMCLH]

-- Consulta a tabla tipo de venta de OFISIS
SELECT * FROM [dbo].[USR_FCTTVH]

-- Consulta a tabla sede hospital/clinica de OFISIS
SELECT * FROM [dbo].[USR_LUGATE]

-- Consulta a tabla lista de precios clientes de OFISIS
SELECT * FROM [dbo].[USR_STTLPR]

-- Consulta a tabla prioridad de venta de OFISIS
SELECT * FROM [dbo].[USR_PRIOVT]

-- Consulta a tabla Vendedor/Representante de OFISIS
SELECT * FROM [dbo].[USR_VTTVND]

-- Consulta a tabla zona de vendedor de OFISIS
SELECT * FROM [dbo].[USR_GRTZON]

-- Consulta a tabla medico de OFISIS
SELECT * FROM [dbo].[USR_MEDICO]

-- Consulta a tabla sede de entrega de OFISIS
SELECT * FROM [dbo].[USR_VTTENT]

-- Consulta a tabla pais sede de entrega de OFISIS
SELECT * FROM [dbo].[USR_GRTPAH]

-- Consulta a tabla codigo postal sede entrega de OFISIS
SELECT * FROM [dbo].[USR_GRTPAC]

-- Consulta a tabla deposito origen de OFISIS
SELECT * FROM [dbo].[USR_STTDEH]

-- Consulta a tabla sector de OFISIS
SELECT * FROM [dbo].[USR_STTDEI]