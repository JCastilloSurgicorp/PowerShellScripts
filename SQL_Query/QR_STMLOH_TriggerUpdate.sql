USE [SURGICORP_ERP]
GO
/****** Object:  Trigger [dbo].[QR_STMLOH_TriggerUpdate]    Script Date: 10/07/2025 09:32:17 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 09/04/25>
-- Description:	<Description, Updates from [dbo].[USR_STMLOH]>
-- ============================================================
ALTER TRIGGER [dbo].[QR_STMLOH_TriggerUpdate] 
   ON [dbo].[USR_STMLOH]
   AFTER UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN
			UPDATE [dbo].[QR_PRODUCTOS]
				SET CODIGO_QR = i.STMLOH_CODBAR
				FROM inserted AS i
				WHERE LOTE = i.STMLOH_NSERIE and
					TIPO_PRODUCTO = i.STMLOH_TIPPRO and
					PRODUCTO = i.STMLOH_ARTCOD and
					EMPRESA_ID = i.STMLOH_CODEMP
		END
	END TRY
	BEGIN CATCH
		DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
		DECLARE @SeveridadError INT = ERROR_SEVERITY();
		DECLARE @EstadoError INT = ERROR_STATE();
		IF XACT_STATE() <> 0
			ROLLBACK TRANSACTION;
		INSERT INTO [dbo].[GR_UPDATE_AUDIT] (
			[ID_CONCAT],
			[NUMERO_GUIA],
			[EMPRESA_ID],
			[NUMERO_ITEM],
			[ESTADO_OLD],
			[ESTADO_NEW],
			[FECHA_HORA]
		)
		VALUES ('QR_STMLOH_TriggerUpdate', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, GETUTCDATE());
		RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
	END CATCH
END
