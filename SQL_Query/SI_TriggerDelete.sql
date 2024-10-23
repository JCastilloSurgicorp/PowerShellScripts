CREATE TRIGGER dbo.SI_TriggerDelete
   ON  [dbo].[STOCKS_PWRAPP]
   AFTER DELETE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
		DECLARE @prod_id INT = (SELECT [id] FROM [dbo].[SI_Productos] WHERE [PRODUCTO] = (SELECT PRODUCTO FROM DELETED))
		DECLARE @tipoProd_id INT = (SELECT [id] FROM [dbo].[SI_TipoProductos] WHERE [TIPO_PRODUCTO] = (SELECT [TIPO_PRODUCTO] FROM DELETED))
		DECLARE @dep_id INT = (SELECT [id] FROM [dbo].[SI_Depositos] WHERE [DEPOSITO] = (SELECT DEPOSITO FROM DELETED))
		DECLARE @sector_id INT = (SELECT [id] FROM [dbo].[SI_Sector] WHERE [SECTOR] = (SELECT SECTOR FROM DELETED))
		DECLARE @LOTE NVARCHAR = (SELECT LOTE FROM DELETED)
	BEGIN TRY
		DELETE FROM dbo.STOCKS_INVENTARIO
		WHERE dep_id_id = @dep_id AND 
				sector_id_id = @sector_id AND 
				tipoProd_id_id = @tipoProd_id AND
				prod_id_id = @prod_id AND 
				LOTE = @LOTE
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