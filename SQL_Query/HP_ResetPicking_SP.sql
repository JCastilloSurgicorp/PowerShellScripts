CREATE PROCEDURE HP_AbandonedSession_SP
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRY
		UPDATE [dbo].[HOJA_PICKING]
		SET status_picking = 'Picking Pendiente',
			app_session_active = 0,
			almacen = NULL,
			fecha_almacen = NULL,
			firma_almacen = 'Por Confirmar'
		WHERE status_picking = 'Picking En Proceso'
		  AND app_session_active = 1
		  AND last_heartbeat_received < DATEADD(MINUTE, -3, GETDATE())
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