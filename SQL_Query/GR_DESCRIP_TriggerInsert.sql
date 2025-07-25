USE [SURGICORP_ERP]
GO
/****** Object:  Trigger [dbo].[GR_DESCRIP_TriggerInsert]    Script Date: 10/07/2025 11:13:10 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 09/04/25>
-- Description:	<Description, Inserts from [dbo].[GR_DESCRIPCION]>
-- ============================================================
ALTER TRIGGER [dbo].[GR_DESCRIP_TriggerInsert] 
   ON  [dbo].[GR_DESCRIPCION]
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	--DECLARE @GR_count INT = (SELECT COUNT(*) FROM inserted)
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
			SELECT i.id, i.NUMERO_GUIA, i.EMPRESA_ID, i.NUMERO_ITEM, GETUTCDATE(), 'INSERTED', 
				ISNULL(i.PRODUCTO, '-') + ' | ' + ISNULL(i.TIPO_PRODUCTO, '-') + ' | ' + ISNULL(i.LOTE, '-') + ' | ' + ISNULL(i.SECTOR, '-') 
				+ ' | ' + ISNULL(i.UBICACION_SECTOR, '-') + ' | ' + ISNULL(i.KITS_ITEM, '-')
			FROM inserted AS i
		END
		If exists(SELECT * FROM inserted as i INNER JOIN GUIAS_REMISION as g on i.NUMERO_GUIA = g.NUMERO_GUIA and i.EMPRESA_ID = g.EMPRESA_ID)
		BEGIN
			UPDATE GR_DESCRIPCION
			SET GUIA_ID = g.id
			FROM inserted as i 
				INNER JOIN GUIAS_REMISION as g 
				ON i.NUMERO_GUIA = g.NUMERO_GUIA and 
					i.EMPRESA_ID = g.EMPRESA_ID
			WHERE GR_DESCRIPCION.NUMERO_GUIA = g.NUMERO_GUIA and
				GR_DESCRIPCION.EMPRESA_ID = g.EMPRESA_ID
		END
		If exists(SELECT * FROM inserted as i 
					INNER JOIN QR_PRODUCTOS as q 
					ON i.LOTE = q.LOTE and 
						i.TIPO_PRODUCTO = q.TIPO_PRODUCTO and
						i.PRODUCTO = q.PRODUCTO and
						i.EMPRESA_ID = q.EMPRESA_ID)
		BEGIN
			UPDATE GR_DESCRIPCION
			SET CODIGO_QR = q.id
			FROM inserted as i 
				INNER JOIN QR_PRODUCTOS as q
				ON i.LOTE = q.LOTE and 
					i.TIPO_PRODUCTO = q.TIPO_PRODUCTO and
					i.PRODUCTO = q.PRODUCTO and
					i.EMPRESA_ID = q.EMPRESA_ID
			WHERE GR_DESCRIPCION.LOTE = q.LOTE and 
					GR_DESCRIPCION.TIPO_PRODUCTO = q.TIPO_PRODUCTO and
					GR_DESCRIPCION.PRODUCTO = q.PRODUCTO and
					GR_DESCRIPCION.EMPRESA_ID = q.EMPRESA_ID
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
		VALUES ('GR_DESCRIP_TriggerInsert', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, GETUTCDATE());

		--RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
		--ROLLBACK TRANSACTION
	END CATCH
END
