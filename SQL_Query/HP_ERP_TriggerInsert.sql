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
-- Create date: <Create Date, 11/08/25>
-- Description:	<Description, Inserts from [dbo].[HOJA_PICKING]>
-- =============================================
CREATE TRIGGER [dbo].[HP_ERP_TriggerInsert]
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
		DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
		DECLARE @SeveridadError INT = ERROR_SEVERITY();
		DECLARE @EstadoError INT = ERROR_STATE();

		INSERT INTO [dbo].[GR_UPDATE_AUDIT] (
			[ID_CONCAT],
			[NUMERO_GUIA],
			[EMPRESA_ID],
			[NUMERO_ITEM],
			[ESTADO_OLD],
			[ESTADO_NEW],
			[FECHA_HORA]
		)
		VALUES ('HP_ERP_TriggerInsert', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, GETUTCDATE());
		--RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
	END CATCH

END
GO