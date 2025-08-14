-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 16/07/25>
-- Description:	<Description, Delete from [dbo].[HOJA_PICKING]>
-- =============================================
ALTER TRIGGER HP_ERP_TriggerDelete
   ON [dbo].[HOJA_PICKING]
   AFTER DELETE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET XACT_ABORT OFF;
	BEGIN TRY
		DECLARE @estado_old NVARCHAR(4000) = (SELECT CAST(ISNULL(d.GR_ID, '') AS varchar(20)) + ' | ' + ISNULL(d.STATUS_PICKING, '') + ' | ' + ISNULL(d.ALMACEN, '') 
				+ ' | ' + ISNULL(d.FIRMA_ALMACEN, '') + ' | ' + CAST(ISNULL(d.FECHA_ALMACEN, '') AS varchar(20)) + ' | ' + ISNULL(d.DISTRIBUCION, '') 
				+ ' | ' + ISNULL(d.FIRMA_DISTRIBUCION, '') + ' | ' + CAST(ISNULL(d.FECHA_DISTRIBUCION, '') AS varchar(20)) FROM deleted AS d)
		BEGIN
			INSERT INTO [dbo].[HP_UPDATE_AUDIT] ([ID_HP], [NUMERO_GUIA], [EMPRESA_ID], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA], [USUARIO])
			SELECT d.id, d.NUMERO_GUIA, d.EMPRESA_ID, @estado_old, 'DELETED', GETUTCDATE(), d.USUARIO
			FROM deleted AS d
		END
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
				'HP_ERP_TriggerDelete -> Error: ', @EstadoError,
				' | Severidad: ', @SeveridadError,
				' | Mensaje: ', @MensajeError
			);
			INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
				VALUES ('HP_ERP_TriggerDelete', CONCAT('HP_ERP_TriggerDelete -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), 'ERROR', @MensajeError, GETUTCDATE());
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
GO
