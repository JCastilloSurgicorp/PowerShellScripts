USE [SURGICORP_ERP]
GO
/****** Object:  Trigger [dbo].[QR_STMLOH_TriggerInsert]    Script Date: 10/07/2025 09:31:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 08/04/25>
-- Description:	<Description, Inserts from [dbo].[USR_STMLOH]>
-- ============================================================
ALTER TRIGGER [dbo].[QR_STMLOH_TriggerInsert]
   ON [dbo].[USR_STMLOH]
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN
			INSERT INTO [dbo].[QR_PRODUCTOS]
				(
					LOTE,
					TIPO_PRODUCTO,
					PRODUCTO,
					EMPRESA_ID,
					CODIGO_QR
				)
			SELECT i.STMLOH_NSERIE, i.STMLOH_TIPPRO, i.STMLOH_ARTCOD, i.STMLOH_CODEMP, isnull(i.STMLOH_CODBAR, '')
			FROM inserted AS i
			WHERE i.STMLOH_CODEMP = '01' or i.STMLOH_CODEMP = '04'
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
		VALUES ('QR_STMLOH_TriggerInsert', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, GETUTCDATE());
		RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
	END CATCH
END
