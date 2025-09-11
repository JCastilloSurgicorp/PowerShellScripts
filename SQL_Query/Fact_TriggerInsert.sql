-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 03/09/25>
-- Description:	<Description, Inserts from [dbo].[FACT_DETALLE]>
-- =============================================
ALTER TRIGGER [dbo].[Fact_TriggerInsert]
   ON  [dbo].[FACT_DETALLE]
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    BEGIN TRY
		INSERT INTO [dbo].[FACT_UPDATE_AUDIT]
				(
					[ID_FACT],
					[NUMERO_FACTURA],
					[EMPRESA_ID],
					[ESTADO_OLD], 
					[ESTADO_NEW],
					[FECHA_HORA],
					[USUARIO]
				)
			SELECT i.[id], i.[NUMERO_FACTURA], i.[EMPRESA_ID], 'INSERTED',
					CAST(ISNULL(i.[FECHA_EMISION], '') as VARCHAR) + ' | ' + CAST(ISNULL(i.[MONTO_SOLES], 0) as VARCHAR(MAX)) + ' | ' + ISNULL(i.[MONEDA], '-')
					+ ' | ' + ISNULL(i.[NOMBRE_CLIENTE], '-') + ' | ' + ISNULL(i.[CONDICION_PAGO], '-') + ' | ' + ISNULL(i.[VENDEDOR], '-')
					+ ' | ' + CAST(ISNULL(i.[COBRADO], 0) as VARCHAR(MAX)) + ' | ' + ISNULL(i.[ESTADO], '-') + ' | ' + ISNULL(i.[NC_FACTURA_CANJE], '-')
					+ ' | ' + ISNULL(i.[NC_ANULACION], '-') + ' | ' + ISNULL(i.[TITULO_GRATUITO], '-') + ' | ' + CAST(ISNULL(i.[ID_APP], '-') as VARCHAR)
					+ ' | ' + ISNULL(i.[OC_CLIENTE], '-') + ' | ' + ISNULL(i.[DIRECCION_ENTREGA], '-') + ' | ' + ISNULL(i.[ZONA], '-')
					+ ' | ' + ISNULL(i.[AFECTO_DETRACCION], '-') + ' | ' + ISNULL(i.[AFECTO_RETENCION], '-') + ' | ' + ISNULL(i.[USUARIO_REGISTRO], '-'), 
					GETUTCDATE(), i.[USUARIO]
			FROM inserted AS i
	END TRY
	BEGIN CATCH
		---- Rollback si hay transaccion activa
		DECLARE @XState INT = XACT_STATE();
		IF @XState = -1 OR @XState = 1 
			ROLLBACK TRANSACTION;
		---- Intentar ingresar error en la tabla GR_UPDATE_AUDIT
		BEGIN TRY
			DECLARE @MensajeError NVARCHAR(MAX) = ERROR_MESSAGE();
			DECLARE @SeveridadError INT = ERROR_SEVERITY();
			DECLARE @EstadoError INT = ERROR_STATE();
			DECLARE @LogMessage NVARCHAR(MAX) = CONCAT(
				'Fact_TriggerInsert -> Error: ', @EstadoError,
				' | Severidad: ', @SeveridadError,
				' | Mensaje: ', @MensajeError
			);
			INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
				VALUES ('Fact_TriggerInsert', CONCAT('Fact_TriggerInsert -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), 'ERROR', @MensajeError, GETUTCDATE());
			RAISERROR(@LogMessage, 0, 1) WITH LOG;
		END TRY
		BEGIN CATCH
			-- capturar y mandar al log el error del insert de la tabla GR_UPDATE_AUDIT
			DECLARE @MensajeError2 NVARCHAR(4000) = 'Fact_TriggerInsert: ' + ERROR_MESSAGE();
			DECLARE @SeveridadError2 INT = ERROR_SEVERITY();
			DECLARE @EstadoError2 INT = ERROR_STATE();
			RAISERROR(@MensajeError2, @SeveridadError2, @EstadoError2) WITH LOG;
		END CATCH
	END CATCH
END
GO