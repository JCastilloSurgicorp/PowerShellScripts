USE [SURGICORP_ERP]
GO
/****** Object:  Trigger [dbo].[GR_TriggerInsert]    Script Date: 10/07/2025 09:17:40 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 09/04/25>
-- Description:	<Description, Inserts from [dbo].[GUIAS_REMISION]>
-- ============================================================
ALTER TRIGGER [dbo].[GR_TriggerInsert] 
   ON  [dbo].[GUIAS_REMISION]
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN
			INSERT INTO dbo.GR_UPDATE_AUDIT
				(
					ID_CONCAT,
					NUMERO_GUIA,
					EMPRESA_ID,
					NUMERO_ITEM,
					FECHA_HORA,
					ESTADO_OLD,
					ESTADO_NEW
				)
			SELECT i.id, i.NUMERO_GUIA, i.EMPRESA_ID, 0, GETUTCDATE(), 'INSERTED', 
				ISNULL(i.OC_CLIENTE, '-') + ' | ' + ISNULL(i.NRO_PROCESO, '-') + ' | ' + ISNULL(i.PACIENTE, '-') + ' | ' + CAST(ISNULL(i.FECHA_CIRUGIA, '-') AS varchar(20)) 
				+ ' | ' + ISNULL(RIGHT(i.OBSERVACION, 40), '-')
			FROM inserted AS i
		END
	END TRY
	BEGIN CATCH
		DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
		DECLARE @SeveridadError INT = ERROR_SEVERITY();
		DECLARE @EstadoError INT = ERROR_STATE();
		/*IF XACT_STATE() <> 0
			ROLLBACK TRANSACTION;*/
		INSERT INTO [dbo].[GR_UPDATE_AUDIT] (
			[ID_CONCAT],
			[NUMERO_GUIA],
			[EMPRESA_ID],
			[NUMERO_ITEM],
			[ESTADO_OLD],
			[ESTADO_NEW],
			[FECHA_HORA]
		)
		VALUES ('GR_TriggerInsert', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, GETUTCDATE());
		--RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
	END CATCH
END
