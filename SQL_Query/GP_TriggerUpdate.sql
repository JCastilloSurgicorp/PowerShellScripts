USE [SURGICORP_POWERAPPS]
GO
/****** Object:  Trigger [dbo].[GrPendiente_TriggerUpdate]    Script Date: 3/12/2024 18:51:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER TRIGGER [dbo].[GrPendiente_TriggerUpdate] 
   ON [dbo].[GUIPEN_PWRAPP]
   AFTER UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN
			MERGE [dbo].[PEND_ITEMS] AS pend
				USING inserted AS i
				ON ID_CONCAT = i.CORRELATIVO 
				WHEN MATCHED THEN
					UPDATE 
						SET CANTIDAD_PENDIENTE = i.CANTIDAD
				WHEN NOT MATCHED THEN
					INSERT
						(
							[NUMERO_GUIA],
							[ITEM],
							[PRODUCTO],
							[DESCRIPCION_PRODUCTO],
							[CANTIDAD_PENDIENTE],
							[LOTE],
							[VENCIMIENTO_LOTE],
							[ID_APP],
							[ID_CONCAT]
						)
					VALUES (i.[NUMERO_GUIA], i.[ITEM], i.[PRODUCTO], i.[DESCRIPCION_PRODUCTO], 
						i.[CANTIDAD], i.[LOTE], i.[VENCIMIENTO_LOTE], i.[ID_APP], i.[CORRELATIVO]);

		END
		BEGIN
			MERGE [dbo].[PEND_GUIAS] AS pend
				USING (SELECT DISTINCT (i.[NUMERO_GUIA]), i.[REPRESENTANTE], i.[NOMBRE_CLIENTE], i.[ZONA], 
					i.[TIPO_VENTA], i.[EMPRESA], i.[FECHA_GUIA], i.[ID_APP], CP.CANT_PEND_TOTAL 
				FROM inserted AS i) AS i
					INNER JOIN (SELECT [NUMERO_GUIA], SUM(CANTIDAD) AS CANT_PEND_TOTAL FROM inserted GROUP BY NUMERO_GUIA) AS CP ON CP.NUMERO_GUIA = i.NUMERO_GUIA AND i.[CANTIDAD] > 0
				ON i.[CANTIDAD] > 0
				WHEN MATCHED THEN
					UPDATE
						SET CANT_PEND_TOTAL = CP.CANT_PEND_TOTAL
				WHEN NOT MATCHED THEN
					INSERT
						(
							[NUMERO_GUIA],
							[REPRESENTANTE],
							[NOMBRE_CLIENTE],
							[ZONA],
							[TIPO_VENTA],
							[EMPRESA],
							[FECHA_GUIA],
							[ID_APP],
							[CANT_PEND_TOTAL]
					
						)
					VALUES (SELECT DISTINCT(i.[NUMERO_GUIA]), i.[REPRESENTANTE], i.[NOMBRE_CLIENTE], i.[ZONA], i.[TIPO_VENTA], i.[EMPRESA], i.[FECHA_GUIA], i.[ID_APP], CP.CANT_PEND_TOTAL FROM inserted AS i);
		END
		BEGIN
			INSERT INTO [dbo].[PEND_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ITEM], [ACCION], [CANT_PEND_OLD], [CANT_PEND_NEW], [FECHA_HORA])
			SELECT i.[CORRELATIVO], i.[NUMERO_GUIA], i.[ITEM], 'UPDATED', d.[CANTIDAD], i.[CANTIDAD], CURRENT_TIMESTAMP
			FROM deleted AS d
				INNER JOIN inserted AS i ON i.CORRELATIVO = d.CORRELATIVO
		END
	END TRY
	BEGIN CATCH
		DECLARE @MensajeError NVARCHAR(4000);
		DECLARE @SeveridadError INT;
		DECLARE @EstadoError INT;

		SELECT @MensajeError = ERROR_MESSAGE(), @SeveridadError = ERROR_SEVERITY(), @EstadoError = ERROR_STATE()

		RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
		ROLLBACK TRANSACTION
	END CATCH
END
