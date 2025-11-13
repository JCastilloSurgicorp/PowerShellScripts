-- ================================================
-- Template generated from Template Explorer using:
-- Create Trigger (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- See additional Create Trigger templates for more
-- examples of different Trigger statements.
--
-- This block of comments will not be included in
-- the definition of the function.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 10/11/25>
-- Description:	<Description, Inserts from [dbo].[USR_STMPDH]>
-- =============================================
CREATE TRIGGER [dbo].[SI_PROD_erp_TriggerInsert]
   ON  [dbo].[USR_STMPDH]
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    BEGIN TRY
		IF NOT EXISTS (SELECT DISTINCT TRIM(i.STMPDH_ARTCOD), STMPDH_DESCRP, p.id FROM [USR_STMPDH] as i
				LEFT JOIN SI_PRODUCTO as p ON p.CODIGO_PRODUCTO = TRIM(i.STMPDH_ARTCOD) WHERE id is NULL)
		BEGIN
			INSERT INTO SI_PRODUCTO (CODIGO_PRODUCTO, DESCRIPCION)
			SELECT t.art, t.descr FROM (SELECT DISTINCT TRIM(i.STMPDH_ARTCOD) as art, STMPDH_DESCRP as descr, p.id FROM [USR_STMPDH] as i
				LEFT JOIN SI_PRODUCTO as p ON p.CODIGO_PRODUCTO = TRIM(i.STMPDH_ARTCOD)
			WHERE id is NULL) as t
		END
		BEGIN
			INSERT INTO SI_PRODUCTO_tp_id (si_producto_id, si_tipoproducto_id)
			SELECT p.id as p_id, t.id as t_id, TRIM(i.STMPDH_ARTCOD), STMPDH_TIPPRO FROM [USR_STMPDH] as i
				LEFT JOIN SI_PRODUCTO as p ON p.CODIGO_PRODUCTO = TRIM(i.STMPDH_ARTCOD)
				LEFT JOIN SI_PRODUCTO_tp_id as t ON t.si_producto_id = p.id
				WHERE t.id is NULL
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
				'SI_PROD_erp_TriggerInsert -> Error: ', @EstadoError,
				' | Severidad: ', @SeveridadError,
				' | Mensaje: ', @MensajeError
			);
			INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
				VALUES ('SI_PROD_erp_TriggerInsert', CONCAT('SI_PROD_erp_TriggerInsert -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), 'ERROR', @MensajeError, GETUTCDATE());
			RAISERROR(@LogMessage, 0, 1) WITH LOG;
		END TRY
		BEGIN CATCH
			-- capturar y mandar al log el error del insert de la tabla GR_UPDATE_AUDIT
			DECLARE @MensajeError2 NVARCHAR(4000) = 'SI_PROD_erp_TriggerInsert: ' + ERROR_MESSAGE();
			DECLARE @SeveridadError2 INT = ERROR_SEVERITY();
			DECLARE @EstadoError2 INT = ERROR_STATE();
			RAISERROR(@MensajeError2, @SeveridadError2, @EstadoError2) WITH LOG;
		END CATCH
	END CATCH
END
GO
