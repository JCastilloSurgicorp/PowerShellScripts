CREATE TRIGGER dbo.SI_TriggerUpdate
   ON  [dbo].[STOCKS_PWRAPP]
   AFTER UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
		
	BEGIN TRY
		/*MERGE [dbo].[STOCKS_INVENTARIO] AS ST
			USING inserted AS i
				INNER JOIN [dbo].[SI_Depositos] AS D ON i.DEPOSITO = D.[DEPOSITO]
				INNER JOIN [dbo].[SI_Productos] AS P ON i.PRODUCTO = P.[PRODUCTO]
				INNER JOIN [dbo].[SI_Sector] AS S ON i.SECTOR = S.[SECTOR]
				INNER JOIN [dbo].[SI_TipoAlmacen] AS TA ON i.TIPO_ALMACEN = TA.[TIPO_ALMACEN]
				INNER JOIN [dbo].[SI_TipoProductos] AS TP ON i.TIPO_PRODUCTO = TP.[TIPO_PRODUCTO]
			ON ST.dep_id_id = D.[id] AND 
				ST.sector_id_id = S.[id] AND 
				ST.tipoProd_id_id = TP.[id] AND
				ST.prod_id_id = P.[id] AND 
				ST.LOTE = i.LOTE
			WHEN MATCHED THEN
				UPDATE 
					SET ST.prod_id_id = P.[id], 
						ST.tipoProd_id_id = TP.[id], 
						ST.dep_id_id = D.[id],
						ST.sector_id_id = S.[id],
						ST.tipoAlm_id_id = TA.[id],
						ST.STOCK = i.STOCK,
						ST.LOTE = i.LOTE,
						ST.FECHA_VIGENCIA_LOTE = i.FECHA_VIGENCIA_LOTE,
						ST.TIPO_ALMACENAJE = i.TIPO_ALMACENAJE,
						ST.REGISTRO_SANITARIO = i.REGISTRO_SANITARIO,
						ST.FECHA_VIGENCIA_REGSAN = i.FECHA_VIGENCIA_REGSAN,
						ST.DESCRIPCION_DEPOSITO = i.[DESCRIPCION_DEPOSITO]
			WHEN NOT MATCHED THEN
				INSERT ([prod_id_id], [dep_id_id], [sector_id_id], [tipoAlm_id_id], 
					[tipoProd_id_id],[STOCK], [LOTE], [FECHA_VIGENCIA_LOTE], [TIPO_ALMACENAJE], [REGISTRO_SANITARIO], 
					[FECHA_VIGENCIA_REGSAN], [DESCRIPCION_DEPOSITO])
				VALUES (P.[id], D.[id], S.[id], TA.[id], TP.[id], i.[STOCK], i.[LOTE], i.[FECHA_VIGENCIA_LOTE], 
					i.[TIPO_ALMACENAJE], i.[REGISTRO_SANITARIO], i.[FECHA_VIGENCIA_REGSAN], i.[DESCRIPCION_DEPOSITO]);*/
		BEGIN
			UPDATE [dbo].[STOCKS_INVENTARIO]
				SET prod_id_id = P.[id], 
					tipoProd_id_id = TP.[id], 
					dep_id_id = D.[id],
					sector_id_id = S.[id],
					tipoAlm_id_id = TA.[id],
					STOCK = i.STOCK,
					LOTE = i.LOTE,
					FECHA_VIGENCIA_LOTE = i.FECHA_VIGENCIA_LOTE,
					TIPO_ALMACENAJE = i.TIPO_ALMACENAJE,
					REGISTRO_SANITARIO = i.REGISTRO_SANITARIO,
					FECHA_VIGENCIA_REGSAN = i.FECHA_VIGENCIA_REGSAN,
					DESCRIPCION_DEPOSITO = i.[DESCRIPCION_DEPOSITO]
				FROM inserted AS i
					INNER JOIN [dbo].[SI_Depositos] AS D ON i.DEPOSITO = D.[DEPOSITO]
					INNER JOIN [dbo].[SI_Productos] AS P ON i.PRODUCTO = P.[PRODUCTO]
					INNER JOIN [dbo].[SI_Sector] AS S ON i.SECTOR = S.[SECTOR]
					INNER JOIN [dbo].[SI_TipoAlmacen] AS TA ON i.TIPO_ALMACEN = TA.[TIPO_ALMACEN]
					INNER JOIN [dbo].[SI_TipoProductos] AS TP ON i.TIPO_PRODUCTO = TP.[TIPO_PRODUCTO]
				WHERE dep_id_id = D.[id] AND 
					sector_id_id = S.[id] AND 
					tipoProd_id_id = TP.[id] AND
					prod_id_id = P.[id] AND 
					[dbo].[STOCKS_INVENTARIO].LOTE = i.LOTE		
		END
		/*BEGIN
			INSERT INTO [dbo].[SI_UPDATE_AUDIT] ([PRODUCTO], [LOTE], [DESCRIPCION_DEPOSITO], [SECTOR], [STOCK_OLD], [STOCK_NEW], [FECHA_HORA])
			SELECT i.PRODUCTO, i.LOTE, i.DESCRIPCION_PRODUCTO, i.SECTOR, d.STOCK, i.STOCK, CURRENT_TIMESTAMP
			FROM inserted AS i
				INNER JOIN deleted AS d ON d.PRODUCTO = i.PRODUCTO AND 
					d.TIPO_PRODUCTO = i.TIPO_PRODUCTO AND 
					d.LOTE = i.LOTE AND 
					d.DESCRIPCION_DEPOSITO = i.DESCRIPCION_DEPOSITO AND 
					d.SECTOR = i.SECTOR 		
		END*/		
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
