USE [SURGICORP_ERP]
GO
/****** Object:  Trigger [dbo].[GR_TriggerUpdate]    Script Date: 10/07/2025 18:39:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 08/07/25>
-- Description:	<Description, Updates from [dbo].[GUIAS_REMISION]>
-- =============================================
ALTER TRIGGER [dbo].[GR_TriggerUpdate]
   ON  [dbo].[GUIAS_REMISION]
   AFTER UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET XACT_ABORT OFF;
	BEGIN TRY
		DECLARE @estado_old NVARCHAR(4000) = (SELECT TOP 1 ISNULL(d.ESTADO, '-') FROM deleted As d)--WHERE d.id=43444)
		DECLARE @estado_new NVARCHAR(4000) = (SELECT TOP 1 ISNULL(i.ESTADO, '-') FROM inserted AS i)-- WHERE i.id=43443)
		BEGIN
			INSERT INTO [dbo].[GR_UPDATE_AUDIT] (
				[ID_CONCAT],
				[NUMERO_GUIA],
				[EMPRESA_ID],
				[NUMERO_ITEM],
				[FECHA_HORA],
				[ESTADO_OLD],
				[ESTADO_NEW]
				
			)
			SELECT i.id, i.NUMERO_GUIA, i.EMPRESA_ID, 0, GETUTCDATE(), ISNULL(d.ESTADO, '-'), ISNULL(i.ESTADO, '-')
			FROM deleted AS d
				INNER JOIN inserted AS i ON i.id = d.id
			--WHERE i.id=1
		END
	END TRY
	BEGIN CATCH
		DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
		DECLARE @SeveridadError INT = ERROR_SEVERITY();
		DECLARE @EstadoError INT = ERROR_STATE();
		RAISERROR(@MensajeError, @SeveridadError, 1) WITH LOG
		BEGIN TRY
			INSERT INTO [dbo].[GR_UPDATE_AUDIT] (
				[ID_CONCAT],
				[NUMERO_GUIA],
				[EMPRESA_ID],
				[NUMERO_ITEM],
				[ESTADO_OLD],
				[ESTADO_NEW],
				[FECHA_HORA]
			)
			VALUES ('GR_TriggerUpdate', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, GETUTCDATE());
		END TRY
		BEGIN CATCH
			DECLARE @MensajeError2 NVARCHAR(4000) = ERROR_MESSAGE();
			RAISERROR('Falló tabla de auditoría: %s', 0, 1, @MensajeError2) WITH LOG;
		END CATCH
		IF XACT_STATE() <> 0
			ROLLBACK TRANSACTION;
	END CATCH
END
