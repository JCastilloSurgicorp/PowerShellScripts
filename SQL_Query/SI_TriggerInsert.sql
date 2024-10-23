CREATE TRIGGER dbo.SI_TriggerInsert 
   ON  [dbo].[STOCKS_PWRAPP]
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRY
		INSERT INTO [dbo].[STOCKS_INVENTARIO] ([prod_id_id], [dep_id_id], [sector_id_id], [tipoAlm_id_id], 
			[tipoProd_id_id],[STOCK], [LOTE], [FECHA_VIGENCIA_LOTE], [TIPO_ALMACENAJE], [REGISTRO_SANITARIO], 
			[FECHA_VIGENCIA_REGSAN], [DESCRIPCION_DEPOSITO])
		SELECT P.[id], D.[id], S.[id], TA.[id], TP.[id], ST.[STOCK], ST.[LOTE], ST.[FECHA_VIGENCIA_LOTE], 
			ST.[TIPO_ALMACENAJE], ST.[REGISTRO_SANITARIO], ST.[FECHA_VIGENCIA_REGSAN], ST.[DESCRIPCION_DEPOSITO]
		FROM inserted AS ST 
			INNER JOIN [dbo].[SI_Depositos] AS D ON ST.DEPOSITO = D.[DEPOSITO]
			INNER JOIN [dbo].[SI_Productos] AS P ON ST.PRODUCTO = P.[PRODUCTO]
			INNER JOIN [dbo].[SI_Sector] AS S ON ST.SECTOR = S.[SECTOR]
			INNER JOIN [dbo].[SI_TipoAlmacen] AS TA ON ST.TIPO_ALMACEN = TA.[TIPO_ALMACEN]
			INNER JOIN [dbo].[SI_TipoProductos] AS TP ON ST.TIPO_PRODUCTO = TP.[TIPO_PRODUCTO]
		WHERE STOCK>0 
	END TRY
	BEGIN CATCH
		DECLARE @MensajeError NVARCHAR(4000);
		DECLARE @SeveridadError INT;
		DECLARE @EstadoError INT;

		SELECT @MensajeError = ERROR_MESSAGE(), @SeveridadError = ERROR_SEVERITY(), @EstadoError = ERROR_STATE()

		RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
		ROLLBACK TRANSACTION
	END CATCH

END
GO