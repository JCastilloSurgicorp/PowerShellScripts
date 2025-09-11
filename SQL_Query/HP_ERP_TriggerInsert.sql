-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 11/08/25>
-- Description:	<Description, Inserts from [dbo].[HOJA_PICKING]>
-- =============================================
ALTER TRIGGER [dbo].[HP_ERP_TriggerInsert]
   ON  [dbo].[HOJA_PICKING]
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    BEGIN TRY
		DECLARE @url NVARCHAR(400) = 'https://appsurgicorperu.com/notificar_picking/';
		DECLARE @picking_id BIGINT = (SELECT TOP 1 id FROM inserted)
		DECLARE @cmd VARCHAR(4000)
		SET @cmd = 'curl -X POST ' + @url + ' -H "Content-Type: application/json" -d "{\"picking_id\": ' + CAST(@picking_id AS VARCHAR) + '}"'

		EXEC xp_cmdshell @cmd, no_output
	END TRY
	BEGIN CATCH
		---- Rollback si hay transaccion activa
		--DECLARE @XState INT = XACT_STATE();
		--IF @XState = -1 OR @XState = 1 
		--	ROLLBACK TRANSACTION;
		-- Intentar ingresar error en la tabla GR_UPDATE_AUDIT
		BEGIN TRY
			DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @SeveridadError INT = ERROR_SEVERITY();
			DECLARE @EstadoError INT = ERROR_STATE();
			DECLARE @LogMessage NVARCHAR(4000) = CONCAT(
				'HP_ERP_TriggerInsert -> Error: ', @EstadoError,
				' | Severidad: ', @SeveridadError,
				' | Mensaje: ', @MensajeError
			);
			INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
				VALUES ('HP_ERP_TriggerInsert', CONCAT('HP_ERP_TriggerInsert -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), 'ERROR', @MensajeError, GETUTCDATE());
			RAISERROR(@LogMessage, 0, 1) WITH LOG;
		END TRY
		BEGIN CATCH
			-- capturar y mandar al log el error del insert de la tabla GR_UPDATE_AUDIT
			DECLARE @MensajeError2 NVARCHAR(4000) = 'HP_ERP_TriggerInsert: ' + ERROR_MESSAGE();
			DECLARE @SeveridadError2 INT = ERROR_SEVERITY();
			DECLARE @EstadoError2 INT = ERROR_STATE();
			RAISERROR(@MensajeError2, @SeveridadError2, @EstadoError2) WITH LOG;
		END CATCH
	END CATCH
END
GO