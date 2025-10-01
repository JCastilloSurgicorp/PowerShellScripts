-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 13/08/25>
-- Description:	<Description, Inserts from [USR_ANUGUI]>
-- =============================================
ALTER TRIGGER [dbo].[AG_erp_TriggerInsert] 
   ON  [dbo].USR_ANUGUI
   AFTER INSERT
AS 
BEGIN TRY
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
    
	IF EXISTS(SELECT i.ANUGUI_NROGUI FROM inserted as i WHERE i.ANUGUI_TIPREG = 'S')
	BEGIN
		UPDATE HOJA_PICKING
			SET SALIDA = 0,
			USUARIO = 'Anulado por Servidor'
		FROM inserted as i
		WHERE NUMERO_GUIA = i.ANUGUI_NROGUI and
			EMPRESA_ID = i.ANUGUI_CODEMP and
			i.ANUGUI_TIPREG = 'S'

		UPDATE GUIAS_REMISION
			SET SALIDA = 0,
			USUARIO = 'Anulado por Servidor'
		FROM inserted as i
		WHERE NUMERO_GUIA = i.ANUGUI_NROGUI and
			EMPRESA_ID = i.ANUGUI_CODEMP and
			i.ANUGUI_TIPREG = 'S'
		
		UPDATE [GR_REGULARIZACION]
			SET SALIDA = 0,
			USUARIO = 'Anulado por Servidor'
		FROM inserted as i
		WHERE NUMERO_GUIA = i.ANUGUI_NROGUI and
			EMPRESA_ID = i.ANUGUI_CODEMP and
			i.ANUGUI_TIPREG = 'S'
	END
	IF EXISTS(SELECT i.ANUGUI_NROGUI FROM inserted as i WHERE i.ANUGUI_TIPREG = 'G')
	BEGIN
		-- Actualiza el estado de la Guia de Remisión
		UPDATE GUIAS_REMISION
			SET ESTADO = 'ANU',
			USUARIO = 'Anulado por Servidor',
			OBSERVACION = 'Anulado por Servidor: ' + GUIAS_REMISION.OBSERVACION
		FROM inserted as i
		WHERE NUMERO_GUIA = i.ANUGUI_NROGUI and
			EMPRESA_ID = i.ANUGUI_CODEMP and
			i.ANUGUI_TIPREG = 'G';

		-- Actualiza el estado de la Descripcion de la Guia de Remisión
		UPDATE [dbo].[GR_DESCRIPCION]
			SET REG_ID = null,
			USUARIO = 'Reg. Anulada por Servidor'
		FROM inserted as i
		WHERE NUMERO_GUIA = i.ANUGUI_NROGUI and
			EMPRESA_ID = i.ANUGUI_CODEMP and
			i.ANUGUI_TIPREG = 'G';
		-- Inserta en la tabla GR_UPDATE_AUDIT el registro REGULARIZACION a eliminar
		INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [EMPRESA_ID], [NUMERO_ITEM], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA], [USUARIO])
		SELECT d.id, d.NUMERO_GUIA, d.EMPRESA_ID, -2, ISNULL(d.[ATENCION], '') + ' | ' + ISNULL(d.[REPRESENTANTE], '') + ' | ' + ISNULL(d.[TIPO_VENTA], '') 
			+ ' | ' + ISNULL(d.[NOMBRE_CLIENTE], '') + ' | ' + CAST(ISNULL(d.[FECHA_GUIA], '') AS varchar(20)) + ' | ' + ISNULL(d.[ESTADO], '') 
			+ ' | ' + CAST(ISNULL(d.[ID_APP], 0) AS varchar(20)) + ' | ' + ISNULL(d.[OC_CLIENTE], '') + ' | ' + ISNULL(d.[NRO_PROCESO], '') 
			+ ' | ' + ISNULL(d.[UBICACION_SECTOR], '') + ' | Salida:' + CAST(ISNULL(d.SALIDA, '') AS varchar(20)),
			'DELETED', GETUTCDATE(), 'Reg. Eliminada por Servidor'
		FROM [GR_REGULARIZACION] as d
			INNER JOIN inserted as i 
			ON NUMERO_GUIA = i.ANUGUI_NROGUI and
				EMPRESA_ID = i.ANUGUI_CODEMP 
		WHERE NUMERO_GUIA = i.ANUGUI_NROGUI and
			EMPRESA_ID = i.ANUGUI_CODEMP and
			i.ANUGUI_TIPREG = 'G';
		-- Elimina la REGULARIZACION correspondiente
		DELETE FROM [GR_REGULARIZACION]
		FROM inserted as i
		WHERE NUMERO_GUIA = i.ANUGUI_NROGUI and
			EMPRESA_ID = i.ANUGUI_CODEMP and
			i.ANUGUI_TIPREG = 'G'

		-- Inserta en la tabla HP_UPDATE_AUDIT el registro picking a eliminar
		INSERT INTO [dbo].[HP_UPDATE_AUDIT] ([ID_HP], [NUMERO_GUIA], [EMPRESA_ID], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA], [USUARIO])
		SELECT d.id, d.NUMERO_GUIA, d.EMPRESA_ID, CAST(ISNULL(d.GR_ID, '') AS varchar(20)) + ' | ' + ISNULL(d.STATUS_PICKING, '') + ' | ' + ISNULL(d.ALMACEN, '') 
			+ ' | ' + ISNULL(d.FIRMA_ALMACEN, '') + ' | ' + CAST(ISNULL(d.FECHA_ALMACEN, '') AS varchar(20)) + ' | ' + ISNULL(d.DISTRIBUCION, '') 
			+ ' | ' + ISNULL(d.FIRMA_DISTRIBUCION, '') + ' | ' + CAST(ISNULL(d.FECHA_DISTRIBUCION, '') AS varchar(20)) + ' | ' + ISNULL(d.USUARIO, '') 
			+ ' | Contingencia:' + CAST(ISNULL(d.CONTINGENCIA, '') AS varchar(20)) + ' | Salida:' + CAST(ISNULL(d.SALIDA, '') AS varchar(20)),
			'DELETED', GETUTCDATE(), 'Eliminado por Servidor'
		FROM HOJA_PICKING as d
			INNER JOIN inserted as i 
			ON NUMERO_GUIA = i.ANUGUI_NROGUI and
				EMPRESA_ID = i.ANUGUI_CODEMP 
		WHERE NUMERO_GUIA = i.ANUGUI_NROGUI and
			EMPRESA_ID = i.ANUGUI_CODEMP and
			i.ANUGUI_TIPREG = 'G';
		-- Elimina la HOJA PICKING correspondiente
		DELETE FROM HOJA_PICKING
		FROM inserted as i
		WHERE NUMERO_GUIA = i.ANUGUI_NROGUI and
			EMPRESA_ID = i.ANUGUI_CODEMP and
			i.ANUGUI_TIPREG = 'G'
	END
END TRY
BEGIN CATCH
	-- Rollback si hay transaccion activa
	DECLARE @XState INT = XACT_STATE();
	IF @XState = -1 OR @XState = 1 
		ROLLBACK TRANSACTION;
	-- Intentar ingresar error en la tabla GR_UPDATE_AUDIT
	BEGIN TRY
		DECLARE @MensajeError NVARCHAR(4000) = ERROR_MESSAGE();
		DECLARE @SeveridadError INT = ERROR_SEVERITY();
		DECLARE @EstadoError INT = ERROR_STATE();
		DECLARE @LogMessage NVARCHAR(4000) = CONCAT(
			'AG_erp_TriggerInsert -> Error: ', @EstadoError,
			' | Severidad: ', @SeveridadError,
			' | Mensaje: ', @MensajeError
		);
		INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
			VALUES ('AG_erp_TriggerInsert', CONCAT('AG_erp_TriggerInsert -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), 'ERROR', @MensajeError, GETUTCDATE());
		RAISERROR(@LogMessage, 0, 1) WITH LOG;
	END TRY
	BEGIN CATCH
		-- capturar y mandar al log el error del insert de la tabla GR_UPDATE_AUDIT
		DECLARE @MensajeError2 NVARCHAR(4000) = 'AG_erp_TriggerInsert: ' + ERROR_MESSAGE();
		DECLARE @SeveridadError2 INT = ERROR_SEVERITY();
		DECLARE @EstadoError2 INT = ERROR_STATE();
		RAISERROR(@MensajeError2, @SeveridadError2, @EstadoError2) WITH LOG;
	END CATCH
END CATCH
