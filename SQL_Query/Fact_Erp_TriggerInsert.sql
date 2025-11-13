SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 03/09/25>
-- Description:	<Description, Inserts from [dbo].[USR_VTRMVH]>
-- =============================================
ALTER TRIGGER [dbo].[Fact_Erp_TriggerInsert]
   ON  [dbo].[USR_VTRMVH]
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    BEGIN TRY
		BEGIN
			INSERT INTO [dbo].[FACT_DETALLE]
					(
						[NUMERO_FACTURA],
						[FECHA_EMISION],
						[MONTO],
						[MONEDA],
						[NOMBRE_CLIENTE],
						[CONDICION_PAGO],
						[VENDEDOR],
						[CANCELADO],
						[ESTADO],
						[COBRADO],
						[SALDO],
						[NC_FACTURA_CANJE],
						[NC_ANULACION],
						[TITULO_GRATUITO],
						[EMPRESA_ID],
						[DIRECCION_ENTREGA],
						[DIRECCION_FACTURACION],
						[ID_APP],
						[OC_CLIENTE],
						[TIPO_CLIENTE],
						[USUARIO_REGISTRO],
						[ZONA],
						[AFECTO_DETRACCION],
						[AFECTO_RETENCION],
						[MONTO_SOLES],
						[USUARIO]
					)
			SELECT i.VTRMVH_NRODOC, i.VTRMVH_FECALT, i.VTRMVH_IMPORT, i.VTRMVH_DESCOF, i.VTRMVH_NOMCLI, i.VTRMVH_DESCND,
				i.VTRMVH_DESVND, i.VTRMVH_ESTCAN, i.VTRMVH_ESTDOC, i.VTRMVH_IMPCOB, i.VTRMVH_IMPSAL, ISNULL(i.VTRMVH_NCFCNJ, '-'),
				IIF(ISNULL(i.VTRMVH_NCRFAC, '-') = '', '-', ISNULL(i.VTRMVH_NCRFAC, '-')), i.VTRMVH_TITGRA, CAST(i.VTRMVH_CODEMP as BIGINT), 
				i.VTRMVH_DIRECC, ISNULL(i.VTRMVH_DESSED, '-'), i.VTRMVH_NROAPP, i.VTRMVH_OCCLIE, ISNULL(i.VTRMVH_TIPCLI, '-'), i.VTRMVH_USERID, 
				i.VTRMVH_DESZON, i.VTRMVH_CORDET, i.VTRMVH_CORRET, i.VTRMVH_IMPNAC, 'Creado por Servidor'
			FROM inserted AS i
		END
		BEGIN
			INSERT INTO [dbo].[FACT_BUSQUEDA]
					(
						[NUMERO_FACTURA],
						[FECHA_EMISION],
						[EMPRESA_ID],
						[ID_APP],
						[OC_CLIENTE]
					)
			SELECT i.VTRMVH_NRODOC, i.VTRMVH_FECALT, CAST(i.VTRMVH_CODEMP as BIGINT),  i.VTRMVH_NROAPP, i.VTRMVH_OCCLIE
			FROM inserted AS i
		END
	END TRY
	BEGIN CATCH
		---- Rollback si hay transaccion activa
		DECLARE @XState INT = XACT_STATE();
		IF @XState = -1 OR @XState = 1 
			ROLLBACK TRANSACTION;
		---- Intentar ingresar error en la tabla GR_UPDATE_AUDIT
		BEGIN TRY
			DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @SeveridadError INT = ERROR_SEVERITY();
			DECLARE @EstadoError INT = ERROR_STATE();
			DECLARE @LogMessage NVARCHAR(4000) = CONCAT(
				'Fact_Erp_TriggerInsert -> Error: ', @EstadoError,
				' | Severidad: ', @SeveridadError,
				' | Mensaje: ', @MensajeError
			);
			INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
				VALUES ('Fact_Erp_TriggerInsert', CONCAT('Fact_Erp_TriggerInsert -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), 'ERROR', @MensajeError, GETUTCDATE());
			RAISERROR(@LogMessage, 0, 1) WITH LOG;
		END TRY
		BEGIN CATCH
			-- capturar y mandar al log el error del insert de la tabla GR_UPDATE_AUDIT
			DECLARE @MensajeError2 NVARCHAR(4000) = 'Fact_Erp_TriggerInsert: ' + ERROR_MESSAGE();
			DECLARE @SeveridadError2 INT = ERROR_SEVERITY();
			DECLARE @EstadoError2 INT = ERROR_STATE();
			RAISERROR(@MensajeError2, @SeveridadError2, @EstadoError2) WITH LOG;
		END CATCH
	END CATCH
END
GO
