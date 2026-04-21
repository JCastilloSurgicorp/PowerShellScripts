SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 15/04/26>
-- Description:	<Description, Inserts from [dbo].[USR_LINNEG]>
-- =============================================
ALTER TRIGGER [dbo].[SI_LINEA_erp_TriggerInsert]
   ON [dbo].[USR_LINNEG] 
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	BEGIN TRY

		INSERT INTO [dbo].[SI_LINEA] (NOMBRE_LINEA, CODIGO, TIPO)
			SELECT i.[LINNEG_DESCRP], i.[LINNEG_CODLIN], i.LINNEG_TIPPRO FROM inserted As i;

		INSERT INTO [dbo].[SI_UPDATE_AUDIT] ([ID_CONCAT], [TABLA], [CAMPO], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA], [USUARIO])
			SELECT 'SI_LINEA_erp_TriggerInsert', 'LINEA', 'INSERTED', '', i.LINNEG_TIPPRO + ' | ' + i.LINNEG_CODLIN + ' | ' + i.LINNEG_DESCRP, 
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
				'SI_LINEA_erp_TriggerInsert -> Error: ', @EstadoError,
				' | Severidad: ', @SeveridadError,
				' | Mensaje: ', @MensajeError
			);
			INSERT INTO [dbo].[SI_UPDATE_AUDIT] ([ID_CONCAT], [TABLA], [CAMPO], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
				VALUES ('SI_LINEA_erp_TriggerInsert', 'LINEA', 'ERROR', CONCAT('SI_LINEA_erp_TriggerInsert -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), @MensajeError, GETUTCDATE());
			RAISERROR(@LogMessage, 0, 1) WITH LOG;
		END TRY
		BEGIN CATCH
			-- capturar y mandar al log el error del insert de la tabla SI_UPDATE_AUDIT
			DECLARE @MensajeError2 NVARCHAR(4000) = 'SI_LINEA_erp_TriggerInsert: ' + ERROR_MESSAGE();
			DECLARE @SeveridadError2 INT = ERROR_SEVERITY();
			DECLARE @EstadoError2 INT = ERROR_STATE();
			RAISERROR(@MensajeError2, @SeveridadError2, @EstadoError2) WITH LOG;
		END CATCH
	END CATCH
END
GO
