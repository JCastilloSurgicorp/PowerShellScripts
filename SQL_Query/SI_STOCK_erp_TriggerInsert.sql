SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 18/11/25>
-- Description:	<Description, Inserts from [dbo].[USR_STRMVK]>
-- =============================================
ALTER TRIGGER [dbo].[SI_STOCK_erp_TriggerInsert]
   ON  [dbo].[USR_STRMVK] 
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    BEGIN TRY
		DECLARE @handle UNIQUEIDENTIFIER;
        DECLARE @message XML;

        -- Formatear los datos de 'inserted' en un solo mensaje XML
        SELECT @message = (
            SELECT STRMVK_DEPOSI, ISNULL(STRMVK_DESDEP, '') as STRMVK_DESDEP, STRMVK_SECTOR, ISNULL(STRMVK_DESSEC, '') as STRMVK_DESSEC,
                ISNULL(STRMVK_TIPALM, '') as STRMVK_TIPALM, ISNULL(STRMVK_DESALM, '') as STRMVK_DESALM, ISNULL(STRMVK_ARTCOD, '') as STRMVK_ARTCOD, 
				ISNULL(STRMVK_CANTID, 0) as STRMVK_CANTID, STRMVK_NSERIE, ISNULL(STRMVK_TIPAMJ, '') as STRMVK_TIPAMJ, STRMVK_CODEMP, STRMVK_SUCURS
				+ '-' + CAST(STRMVK_NROFOR as varchar(20)) as STRMVK_NROGUI, ISNULL(STRMVK_TIPPRO, '') as STRMVK_TIPPRO, 'INSERTED' as STRMVK_ORIGEN
            FROM inserted
            FOR XML PATH('inserted')
        );

        -- Iniciar una nueva conversación con el servicio
        BEGIN 
			DIALOG CONVERSATION @handle
			FROM SERVICE [StockUpdateService]
			TO SERVICE N'StockUpdateService'
			ON CONTRACT [StockUpdateContract]
			WITH ENCRYPTION = OFF;

		-- Enviar el mensaje XML al servicio
		SEND ON CONVERSATION @handle
			MESSAGE TYPE [StockUpdateMessage] (@message);

		INSERT INTO [dbo].[SI_UPDATE_AUDIT] ([ID_CONCAT], [TABLA], [CAMPO], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA], [USUARIO])
			SELECT 'SI_STOCK_erp_TriggerInsert', 'STOCK_INVENTARIO', 'INSERTED', '', i.STRMVK_DEPOSI + ' | ' + i.STRMVK_SECTOR + ' | ' + ISNULL(i.STRMVK_TIPALM, '-')
				+ ' | ' + ISNULL(i.STRMVK_ARTCOD, '-') + ' | ' + CAST(ISNULL(i.STRMVK_CANTID, 0) as varchar(20)) + ' | ' + i.STRMVK_NSERIE 
				+ ' | ' + ISNULL(i.STRMVK_TIPAMJ, '-') + ' | ' + i.STRMVK_CODEMP + ' | ' + i.STRMVK_SUCURS + '-' + 
				CAST(i.STRMVK_NROFOR as varchar(20)) as STRMVK_NROGUI,
			GETUTCDATE(), 'Creado por Servidor' 
			FROM inserted As i;

	END TRY
	BEGIN CATCH
		---- Rollback si hay transaccion activa
		DECLARE @XState INT = XACT_STATE();
		IF @XState = -1 OR @XState = 1 
			ROLLBACK TRANSACTION;
		---- Intentar ingresar error en la tabla SI_UPDATE_AUDIT
		BEGIN TRY
			DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @SeveridadError INT = ERROR_SEVERITY();
			DECLARE @EstadoError INT = ERROR_STATE();
			DECLARE @LogMessage NVARCHAR(4000) = CONCAT(
				'SI_STOCK_erp_TriggerInsert -> Error: ', @EstadoError,
				' | Severidad: ', @SeveridadError,
				' | Mensaje: ', @MensajeError
			);
			INSERT INTO [dbo].[SI_UPDATE_AUDIT] ([ID_CONCAT], [TABLA], [CAMPO], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
				VALUES ('SI_STOCK_erp_TriggerInsert', 'STOCK_INVENTARIO', 'ERROR', CONCAT('SI_STOCK_erp_TriggerInsert -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), @MensajeError, GETUTCDATE());
			RAISERROR(@LogMessage, 0, 1) WITH LOG;
		END TRY
		BEGIN CATCH
			-- capturar y mandar al log el error del insert de la tabla GR_UPDATE_AUDIT
			DECLARE @MensajeError2 NVARCHAR(4000) = 'SI_STOCK_erp_TriggerInsert: ' + ERROR_MESSAGE();
			DECLARE @SeveridadError2 INT = ERROR_SEVERITY();
			DECLARE @EstadoError2 INT = ERROR_STATE();
			RAISERROR(@MensajeError2, @SeveridadError2, @EstadoError2) WITH LOG;
		END CATCH
	END CATCH
END
GO
