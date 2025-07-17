-- ================================================
-- Template generated from Template Explorer using:
-- Create Trigger (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- See additional Create Trigger templates for more
-- examples of different Trigger statements.
--
-- This block of comments will not be included in
-- the definition of the function.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 16/07/25>
-- Description:	<Description, Delete from [dbo].[HOJA_PICKING]>
-- =============================================
CREATE TRIGGER HP_ERP_TriggerDelete
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
			VALUES ('HP_ERP_TriggerDelete', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, GETUTCDATE());
		END TRY
		BEGIN CATCH
			DECLARE @MensajeError2 NVARCHAR(4000) = ERROR_MESSAGE();
			RAISERROR('Falló tabla de auditoría: %s', 0, 1, @MensajeError2) WITH LOG;
		END CATCH
		IF XACT_STATE() <> 0
			ROLLBACK TRANSACTION;
	END CATCH
END
GO
