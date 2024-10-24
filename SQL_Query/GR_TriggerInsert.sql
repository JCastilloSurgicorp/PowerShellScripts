USE [SURGICORP_POWERAPPS]
GO
/****** Object:  Trigger [dbo].[GR_TriggerInsert]    Script Date: 2/08/2024 10:53:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER TRIGGER [dbo].[GR_TriggerInsert] 
   ON  [dbo].[DOCGUI_PWRAPP] 
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN
			INSERT INTO dbo.GUIAS_REMISION
				(
					NUMERO_GUIA,
					ATENCION,
					REPRESENTANTE,
					MOTIVO_TRASLADO,
					NOMBRE_CLIENTE,
					DIRECCION_ENTREGA,
					FECHA_GUIA,
					ESTADO,
					ID_APP,
					OBSERVACION,
					EMPRESA_ID
				)
			SELECT DISTINCT(i.NUMERO_GUIA), i.ATENCION, i.REPRESENTANTE, i.MOTIVO_TRASLADO, i.NOMBRE_CLIENTE,
				i.DIRECCION_ENTREGA, i.FECHA_GUIA, i.ESTADO, i.ID_APP, i.OBSERVACION, i.EMPRESA
			FROM inserted AS i
			WHERE i.OC_CLIENTE='' ORDER BY i.FECHA_GUIA
		END
		BEGIN
			INSERT INTO dbo.GR_DESCRIPCION
				(
					NUMERO_ITEM,
					PRODUCTO_ID,
					SECTOR_ID,
					GUIA_ID,
					CANTIDAD
				)
			SELECT i.NRO_ITEM, P.id, S.id, G.id, i.CANTIDAD
			FROM inserted AS i
			INNER JOIN [dbo].[SI_Productos] AS P ON P.PRODUCTO = i.PRODUCTO
			INNER JOIN [dbo].[SI_Sector] AS S ON S.SECTOR = i.SECTOR
			INNER JOIN [dbo].[GUIAS_REMISION] AS G ON G.NUMERO_GUIA = i.NUMERO_GUIA
			WHERE i.OC_CLIENTE='' ORDER BY i.FECHA_GUIA
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
