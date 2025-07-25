USE [SURGICORP_ERP]
GO
/****** Object:  Trigger [dbo].[GR_erp_TriggerUpdate]    Script Date: 11/07/2025 10:13:08 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 27/06/25>
-- Description:	<Description, Updates from [dbo].[USR_FCRMVH]>
-- =============================================
ALTER TRIGGER [dbo].[GR_erp_TriggerUpdate] 
   ON [dbo].[USR_FCRMVH]
   AFTER UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET XACT_ABORT OFF;
	-- Campos que OFISIS actualiza:
	--USR_FCRMVH_VNDDOR 
	--USR_FCRMVH_NROMED
	--USR_FCRMVH_TIPVEN  
	--USR_FCRMVH_COMOTI
	--USR_FCRMVH_TIPMOD
	--USR_FCRMVH_TRAMOD
	--USR_FCRMVH_COCOND
	--FCRMVH_TRACOD
	--USR_FCRMVH_CFORM
	--USR_FCRMVH_VISVEN_G
	--USR_FCRMVH_VISPRO_G
	--USR_FCRMVH_PACDNI
	-- GR_BUSQUEDA - USR_FCRMVH_OCCLIE
	BEGIN TRY
		BEGIN
			UPDATE [dbo].[GUIAS_REMISION]
				SET ESTADO = i.FCRMVH_ESTADO
				FROM inserted AS i
		END
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
		VALUES ('GR_erp_TriggerUpdate', '-', ERROR_SEVERITY(), ERROR_STATE(), 'ERROR', ERROR_MESSAGE(), GETUTCDATE());
		RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
	END CATCH
END
