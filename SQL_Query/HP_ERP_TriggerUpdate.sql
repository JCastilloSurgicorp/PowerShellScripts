USE [SURGICORP_ERP]
GO
/****** Object:  Trigger [dbo].[HP_ERP_TriggerUpdate]    Script Date: 10/07/2025 11:10:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 08/04/25>
-- Description:	<Description, Updates from [dbo].[HOJA_PICKING]>
-- ============================================================
ALTER TRIGGER [dbo].[HP_ERP_TriggerUpdate]
   ON  [dbo].[HOJA_PICKING]
   AFTER UPDATE
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    BEGIN TRY
		DECLARE @usuario NVARCHAR(60) = (SELECT i.USUARIO FROM inserted AS i) 
		DECLARE @estado_old NVARCHAR(4000) = (SELECT CAST(ISNULL(d.GR_ID, '') AS varchar(20)) + ' | ' + ISNULL(d.STATUS_PICKING, '') + ' | ' + ISNULL(d.ALMACEN, '') 
				+ ' | ' + ISNULL(d.FIRMA_ALMACEN, '') + ' | ' + CAST(ISNULL(d.FECHA_ALMACEN, '') AS varchar(20)) + ' | ' + ISNULL(d.DISTRIBUCION, '') 
				+ ' | ' + ISNULL(d.FIRMA_DISTRIBUCION, '') + ' | ' + CAST(ISNULL(d.FECHA_DISTRIBUCION, '') AS varchar(20)) + ' | ' + ISNULL(d.USUARIO, '') 
				+ ' | ' + CAST(ISNULL(d.CONTINGENCIA, '') AS varchar(20)) FROM deleted AS d)
		DECLARE @estado_new NVARCHAR(4000) = (SELECT CAST(ISNULL(i.GR_ID, '') AS varchar(20)) + ' | ' + ISNULL(i.STATUS_PICKING, '') + ' | ' + ISNULL(i.ALMACEN, '') 
				+ ' | ' + ISNULL(i.FIRMA_ALMACEN, '') + ' | ' + CAST(ISNULL(i.FECHA_ALMACEN, '') AS varchar(20)) + ' | ' + ISNULL(i.DISTRIBUCION, '') 
				+ ' | ' + ISNULL(i.FIRMA_DISTRIBUCION, '') + ' | ' + CAST(ISNULL(i.FECHA_DISTRIBUCION, '') AS varchar(20)) + ' | ' + ISNULL(i.USUARIO, '') 
				+ ' | ' + CAST(ISNULL(i.CONTINGENCIA, '') AS varchar(20)) FROM inserted AS i)
		BEGIN
			IF @estado_old = @estado_new
				BEGIN
					INSERT INTO [dbo].[HP_UPDATE_AUDIT] ([ID_HP], [NUMERO_GUIA], [EMPRESA_ID], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA], [USUARIO])
					SELECT i.id, i.NUMERO_GUIA, i.EMPRESA_ID, 'HEARTBEAT', CAST(ISNULL(i.APP_SESSION_ACTIVE, '') AS varchar(20)) 
					+ ' | ' + CAST(ISNULL(i.HEARTBEAT_TIMESTAMP, '') AS varchar(20)) + ' | ' + CAST(ISNULL(i.LAST_HEARTBEAT_RECEIVED, '') AS varchar(20))
					+ ' | ' + CAST(ISNULL(i.SESSION_ENDED, '') AS varchar(20)), GETUTCDATE(), i.USUARIO
					FROM inserted AS i
				END
			ELSE
				BEGIN
					IF @usuario = 'Creado por Servidor'
						BEGIN
							INSERT INTO [dbo].[HP_UPDATE_AUDIT] ([ID_HP], [NUMERO_GUIA], [EMPRESA_ID], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA], [USUARIO])
							SELECT i.id, i.NUMERO_GUIA, i.EMPRESA_ID, 'INSERTED', @estado_new, GETUTCDATE(), i.USUARIO
							FROM inserted AS i
						END
					ELSE
						BEGIN
							INSERT INTO [dbo].[HP_UPDATE_AUDIT] ([ID_HP], [NUMERO_GUIA], [EMPRESA_ID], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA], [USUARIO], [PICKING_TIME])
							SELECT i.id, i.NUMERO_GUIA, i.EMPRESA_ID, @estado_old, @estado_new, GETUTCDATE(), i.USUARIO,
								CAST(ISNULL(DATEDIFF(SECOND, d.FECHA_ALMACEN, i.FECHA_ALMACEN), '0') / 3600 AS VARCHAR) + ':' + 
									RIGHT('0' + CAST((ISNULL(DATEDIFF(SECOND, d.FECHA_ALMACEN, i.FECHA_ALMACEN), '0') % 3600) / 60 AS VARCHAR), 2) + ':' + 
									RIGHT('0' + CAST(ISNULL(DATEDIFF(SECOND, d.FECHA_ALMACEN, i.FECHA_ALMACEN), '0') % 60 AS VARCHAR), 2)
							FROM deleted AS d
								INNER JOIN inserted AS i ON i.id = d.id	
						END
				END
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
		VALUES ('HP_ERP_TriggerUpdate', '-', @SeveridadError, @EstadoError, 'ERROR', @MensajeError, GETUTCDATE());
		--RAISERROR(@MensajeError,@SeveridadError,@EstadoError)
	END CATCH
END