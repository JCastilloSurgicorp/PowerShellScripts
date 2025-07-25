USE [SURGICORP_ERP]
GO
/****** Object:  Trigger [dbo].[GR_STRMVI_TriggerInsert]    Script Date: 10/07/2025 09:32:43 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 08/04/25>
-- Description:	<Description, Inserts from [dbo].[USR_STMLOH]>
-- ============================================================
ALTER TRIGGER [dbo].[GR_STRMVI_TriggerInsert] 
   ON  [dbo].[USR_STRMVI]
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN
			INSERT INTO dbo.GR_DESCRIPCION
				(
					ID_CONCAT,
					NUMERO_ITEM,
					NUMERO_SECUENCIA,
					PRODUCTO,
					DESCRIPCION_PRODUCTO,
					DESCRIPCION_PRODUCTO_HP,
					PROVEEDOR,
					SECTOR,
					NUMERO_GUIA,
					CANTIDAD,
					LOTE,
					VENCIMIENTO_LOTE,
					EMPRESA_ID,
					UBICACION_SECTOR,
					KITS_GUIA,
					KITS_ITEM,
					TIPO_PRODUCTO
				)
			SELECT i.STRMVI_CODEMP  + ' | ' + i.STRMVI_MODFOR + ' | ' + i.STRMVI_CODFOR +  ' | ' + i.STRMVI_SECTOR + ' | ' + i.STRMVI_NSERIE + 
				' | ' + i.STRMVI_SUCURS + ' | ' + CAST(i.STRMVI_NROFOR AS varchar(20)) + ' | ' + i.STRMVI_ARTORI + ' | ' + CAST(i.STRMVI_NROSEC AS varchar(20)),
				i.STRMVI_NROITM, i.STRMVI_NROSEC, i.STRMVI_ARTORI, i.STMPDH_DESCRP, i.STMPDH_DESART, i.STRMVI_NOMPPR, i.STRMVI_SECTOR, 
				i.STRMVI_SUCURS + '-' + CAST(i.STRMVI_NROFOR AS varchar(20)), IIF(i.STRMVI_CANTID < 0, i.STRMVI_CANTID * (-1), i.STRMVI_CANTID), 
				i.STRMVI_NSERIE, i.USR_STMLOH_FCHVEN, i.STRMVI_CODEMP, ISNULL(i.USR_UBFSEC_DESCRP, 'Sin Ubicación'), i.KITS_GUIA, i.KITS_ITEM, i.STRMVI_TIPPRO
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
		VALUES ('GR_STRMVI_TriggerInsert', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, GETUTCDATE());
		--RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
	END CATCH
END