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
		  AND LAST_HEARTBEAT_RECEIVED < DATEADD(MINUTE, -6, GETUTCDATE())
	END TRY
	BEGIN CATCH
		-- Rollback si hay transaccion activa
		DECLARE @XState INT = XACT_STATE();
		IF @XState = -1 OR @XState = 1 
			ROLLBACK TRANSACTION;
		-- Intentar ingresar error en la tabla GR_UPDATE_AUDIT
		BEGIN TRY
			DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @SeveridadError INT = ERROR_SEVERITY();
			DECLARE @EstadoError INT = ERROR_STATE();
			DECLARE @LogMessage NVARCHAR(4000) = CONCAT(
				'HP_AbandonedSession_SP -> Error: ', @EstadoError,
				' | Severidad: ', @SeveridadError,
				' | Mensaje: ', @MensajeError
			);
			INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
				VALUES ('HP_AbandonedSession_SP', CONCAT('HP_AbandonedSession_SP -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), 'ERROR', @MensajeError, GETUTCDATE());
			RAISERROR(@LogMessage, 0, 1) WITH LOG;
		END TRY
		BEGIN CATCH
			-- capturar y mandar al log el error del insert de la tabla GR_UPDATE_AUDIT
			DECLARE @MensajeError2 NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @SeveridadError2 INT = ERROR_SEVERITY();
			DECLARE @EstadoError2 INT = ERROR_STATE();
			RAISERROR(@MensajeError2, @SeveridadError2, @EstadoError2) WITH LOG;
		END CATCH
	END CATCH
END