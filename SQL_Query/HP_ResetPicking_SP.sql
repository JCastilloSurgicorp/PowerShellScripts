ALTER PROCEDURE HP_AbandonedSession_SP
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRY
		UPDATE [dbo].[HOJA_PICKING]
		SET STATUS_PICKING = 'Picking Pendiente',
			APP_SESSION_ACTIVE = 0,
			ALMACEN = NULL,
			FECHA_ALMACEN = NULL,
			FIRMA_ALMACEN = 'Por Confirmar',
			USUARIO = 'Cambiado por Servidor'
		WHERE STATUS_PICKING = 'Picking En Proceso'
		  AND APP_SESSION_ACTIVE = 1
		  AND LAST_HEARTBEAT_RECEIVED < DATEADD(MINUTE, -6, GETDATE())
	END TRY
	BEGIN CATCH
		DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
		DECLARE @SeveridadError INT = ERROR_SEVERITY();
		DECLARE @EstadoError INT = ERROR_STATE();

		INSERT INTO [dbo].[GR_UPDATE_AUDIT] (
			[ID_CONCAT],
			[NUMERO_GUIA],
			[EMPRESA_ID],
			[NUMERO_ITEM],
			[ESTADO_OLD],
			[ESTADO_NEW],
			[FECHA_HORA]
		)
		VALUES ('HP_AbandonedSession_SP', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, CURRENT_TIMESTAMP);

		RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
		ROLLBACK TRANSACTION
	END CATCH
END