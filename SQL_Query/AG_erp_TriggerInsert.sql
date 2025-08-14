-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 13/08/25>
-- Description:	<Description, Inserts from [USR_ANUGUI]>
-- =============================================
ALTER TRIGGER [dbo].[AG_erp_TriggerInsert] 
   ON  [dbo].USR_ANUGUI
   AFTER INSERT
AS 
BEGIN TRY
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @guia NVARCHAR(50) = (SELECT TOP 1 i.ANUGUI_NROGUI FROM inserted as i);
	DECLARE @empresa INT = CAST((SELECT TOP 1 i.ANUGUI_CODEMP FROM inserted as i) as INT);
	DECLARE @tipo NVARCHAR(2) = (SELECT TOP 1 i.ANUGUI_TIPREG FROM inserted as i);
    
	IF EXISTS(SELECT hp.NUMERO_GUIA FROM HOJA_PICKING as hp WHERE hp.NUMERO_GUIA = @guia and hp.EMPRESA_ID = @empresa)
	BEGIN
		IF @tipo = 'S'
		BEGIN
			UPDATE HOJA_PICKING
				SET SALIDA = 0,
				USUARIO = 'Anulado por Servidor'
			WHERE NUMERO_GUIA = @guia and
				EMPRESA_ID = @empresa
		END
		IF @tipo = 'G'
		BEGIN
			UPDATE GUIAS_REMISION
				SET ESTADO = 'ANU',
				OBSERVACION = 'Anulado por Servidor | ' + GUIAS_REMISION.OBSERVACION
			WHERE NUMERO_GUIA = @guia and
				EMPRESA_ID = @empresa
		END
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
			'AG_erp_TriggerInsert -> Error: ', @EstadoError,
			' | Severidad: ', @SeveridadError,
			' | Mensaje: ', @MensajeError
		);
		INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
			VALUES ('AG_erp_TriggerInsert', CONCAT('AG_erp_TriggerInsert -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), 'ERROR', @MensajeError, GETUTCDATE());
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
