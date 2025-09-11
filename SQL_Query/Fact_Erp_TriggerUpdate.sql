USE [SURGICORP_ERP]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 04/09/25>
-- Description:	<Description, Updates from [dbo].[USR_VTRMVH]>
-- =============================================
ALTER TRIGGER [dbo].[Fact_erp_TriggerUpdate]
   ON  [dbo].[USR_VTRMVH]
   AFTER UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    BEGIN TRY
		UPDATE [FACT_DETALLE]
			SET [COBRADO] = i.VTRMVH_IMPCOB,
				[SALDO] = i.VTRMVH_IMPSAL,
				[CANCELADO] = i.VTRMVH_ESTCAN,
				[ESTADO] = i.VTRMVH_ESTDOC,
				[NC_ANULACION] = i.VTRMVH_NCRFAC,
				[USUARIO] = 'Modificado por Servidor'
			FROM inserted as i
		WHERE [NUMERO_FACTURA] = i.VTRMVH_NRODOC and
			[EMPRESA_ID] = i.VTRMVH_CODEMP
	END TRY
	BEGIN CATCH
		---- Rollback si hay transaccion activa
		DECLARE @XState INT = XACT_STATE();
		IF @XState = -1 OR @XState = 1 
			ROLLBACK TRANSACTION;
		---- Intentar ingresar error en la tabla GR_UPDATE_AUDIT
		BEGIN TRY
			DECLARE @MensajeError NVARCHAR(MAX) = ERROR_MESSAGE();
			DECLARE @SeveridadError INT = ERROR_SEVERITY();
			DECLARE @EstadoError INT = ERROR_STATE();
			DECLARE @LogMessage NVARCHAR(MAX) = CONCAT(
				'Fact_erp_TriggerUpdate -> Error: ', @EstadoError,
				' | Severidad: ', @SeveridadError,
				' | Mensaje: ', @MensajeError
			);
			INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
				VALUES ('Fact_erp_TriggerUpdate', CONCAT('Fact_erp_TriggerUpdate -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), 'ERROR', @MensajeError, GETUTCDATE());
			RAISERROR(@LogMessage, 0, 1) WITH LOG;
		END TRY
		BEGIN CATCH
			-- capturar y mandar al log el error del insert de la tabla GR_UPDATE_AUDIT
			DECLARE @MensajeError2 NVARCHAR(4000) = 'Fact_erp_TriggerUpdate: ' + ERROR_MESSAGE();
			DECLARE @SeveridadError2 INT = ERROR_SEVERITY();
			DECLARE @EstadoError2 INT = ERROR_STATE();
			RAISERROR(@MensajeError2, @SeveridadError2, @EstadoError2) WITH LOG;
		END CATCH
	END CATCH
END