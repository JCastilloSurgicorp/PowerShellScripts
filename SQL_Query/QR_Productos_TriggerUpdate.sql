USE [SURGICORP_ERP]
GO
/****** Object:  Trigger [dbo].[QR_Productos_TriggerUpdate]    Script Date: 10/07/2025 09:30:08 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 08/04/25>
-- Description:	<Description, Updates from [dbo].[QR_PRODUCTOS]>
-- ============================================================
ALTER TRIGGER [dbo].[QR_Productos_TriggerUpdate] 
   ON [dbo].[QR_PRODUCTOS] 
   AFTER UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN
			INSERT INTO [dbo].[QR_UPDATE_AUDIT]
				(
					ID_QR,
					LOTE,
					TIPO_PRODUCTO,
					PRODUCTO,
					EMPRESA_ID,
					CODIGO_QR_OLD,
					CODIGO_QR_NEW,
					FECHA_HORA
				)
			SELECT i.id, i.LOTE, i.TIPO_PRODUCTO, i.PRODUCTO, i.EMPRESA_ID, d.CODIGO_QR, i.CODIGO_QR, CURRENT_TIMESTAMP
			FROM inserted AS i
				INNER JOIN deleted AS d ON i.id = d.id	
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
		VALUES ('QR_Productos_TriggerUpdate', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, GETUTCDATE());
		RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
	END CATCH
END
