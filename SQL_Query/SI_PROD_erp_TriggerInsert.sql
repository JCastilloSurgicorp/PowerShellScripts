SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author, Jairo Castillo>
-- Create date: <Create Date, 10/11/25>
-- Description:	<Description, Inserts from [dbo].[USR_STMPDH]>
-- =============================================
ALTER TRIGGER [dbo].[SI_PROD_erp_TriggerInsert]
   ON  [dbo].[USR_STMPDH]
   AFTER INSERT
AS 
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    BEGIN TRY
		IF EXISTS (SELECT DISTINCT TRIM(i.STMPDH_NOMPRO) as prov, v.id FROM inserted as i
				LEFT JOIN [SI_PROVEEDOR] as v ON v.NOMBRE_PROVEEDOR = TRIM(i.STMPDH_NOMPRO)
			WHERE v.id is NULL and TRIM(i.STMPDH_NOMPRO) is not NULL)
		BEGIN
			INSERT INTO [SI_PROVEEDOR]
			SELECT t.prov FROM (SELECT DISTINCT TRIM(i.STMPDH_NOMPRO) as prov, v.id FROM inserted as i
				LEFT JOIN [SI_PROVEEDOR] as v ON v.NOMBRE_PROVEEDOR = TRIM(i.STMPDH_NOMPRO)
			WHERE v.id is NULL and TRIM(i.STMPDH_NOMPRO) is not NULL) as t
		END
		IF EXISTS (SELECT DISTINCT TRIM(i.STMPDH_LINEAD) as linea, l.id FROM inserted as i
				LEFT JOIN [SI_LINEA] as l ON l.NOMBRE_LINEA = TRIM(i.STMPDH_LINEAD)
			WHERE l.id is NULL)
		BEGIN
			INSERT INTO [SI_LINEA]
			SELECT t.linea FROM (SELECT DISTINCT TRIM(i.STMPDH_LINEAD) as linea, l.id FROM inserted as i
				LEFT JOIN [SI_LINEA] as l ON l.NOMBRE_LINEA = TRIM(i.STMPDH_LINEAD)
			WHERE l.id is NULL) as t
		END
		IF EXISTS (SELECT DISTINCT TRIM(i.STMPDH_GRUPOD) as grupo, g.id FROM inserted as i
				LEFT JOIN [SI_GRUPO] as g ON g.NOMBRE_GRUPO = TRIM(i.STMPDH_GRUPOD)
			WHERE g.id is NULL)
		BEGIN
			INSERT INTO [SI_GRUPO]
			SELECT t.grupo FROM (SELECT DISTINCT TRIM(i.STMPDH_GRUPOD) as grupo, g.id FROM inserted as i
				LEFT JOIN [SI_GRUPO] as g ON g.NOMBRE_GRUPO = TRIM(i.STMPDH_GRUPOD)
			WHERE g.id is NULL) as t
		END
		IF EXISTS (SELECT DISTINCT TRIM(i.STMPDH_ARTCOD), STMPDH_DESCRP, p.id FROM inserted as i
				LEFT JOIN SI_PRODUCTO as p ON p.CODIGO_PRODUCTO = TRIM(i.STMPDH_ARTCOD) WHERE id is NULL)
		BEGIN
			INSERT INTO SI_PRODUCTO (CODIGO_PRODUCTO, DESCRIPCION, GRUPO_ID, LINEA_ID, PROVEEDOR_ID)
			SELECT t.art, t.descr, t.g_id, t.l_id, t.v_id FROM (SELECT DISTINCT TRIM(i.STMPDH_ARTCOD) as art, STMPDH_DESCRP as descr, p.id, l.id as l_id, l.NOMBRE_LINEA, g.id as g_id, g.NOMBRE_GRUPO, v.id as v_id, v.NOMBRE_PROVEEDOR FROM inserted as i
				LEFT JOIN SI_PRODUCTO as p ON p.CODIGO_PRODUCTO = TRIM(i.STMPDH_ARTCOD)
				LEFT JOIN [SI_LINEA] as l ON l.NOMBRE_LINEA = TRIM(i.STMPDH_LINEAD)
				LEFT JOIN SI_GRUPO as g ON g.NOMBRE_GRUPO = TRIM(i.STMPDH_GRUPOD)
				LEFT JOIN [SI_PROVEEDOR] as v ON v.NOMBRE_PROVEEDOR = TRIM(i.STMPDH_NOMPRO)
			WHERE p.id is NULL) as t
		END
		IF EXISTS (SELECT DISTINCT TRIM(i.STMPDH_TIPPRO) as art, p.id FROM inserted as i
				LEFT JOIN [SI_TIPOPRODUCTO] as p ON p.NOMBRE_TIPO = TRIM(i.STMPDH_TIPPRO)
				WHERE id is NULL)
		BEGIN
			INSERT INTO [SI_TIPOPRODUCTO] 
			SELECT t.art FROM (SELECT DISTINCT TRIM(i.STMPDH_TIPPRO) as art, p.id FROM inserted as i
				LEFT JOIN [SI_TIPOPRODUCTO] as p ON p.NOMBRE_TIPO = TRIM(i.STMPDH_TIPPRO)
			WHERE id is NULL) as t
		END
		IF EXISTS (SELECT DISTINCT p.id as p_id, t.id as t_id, TRIM(i.STMPDH_ARTCOD) as cod, TRIM(i.STMPDH_TIPPRO) as tip_prod, pt.si_producto_id, pt.si_tipoproducto_id, pt.id FROM inserted as i
				LEFT JOIN (SELECT tp.id, si_producto_id, si_tipoproducto_id, p.CODIGO_PRODUCTO, t.NOMBRE_TIPO FROM SI_PRODUCTO_tp_id as tp
					LEFT JOIN SI_PRODUCTO as p ON p.id = tp.si_producto_id
					LEFT JOIN SI_TIPOPRODUCTO as t ON t.id = tp.si_tipoproducto_id
				) as pt ON pt.CODIGO_PRODUCTO = TRIM(i.STMPDH_ARTCOD) and pt.NOMBRE_TIPO = TRIM(i.STMPDH_TIPPRO)
				LEFT JOIN SI_PRODUCTO as p ON p.CODIGO_PRODUCTO = TRIM(i.STMPDH_ARTCOD)
				LEFT JOIN SI_TIPOPRODUCTO as t ON t.NOMBRE_TIPO = TRIM(i.STMPDH_TIPPRO)
			WHERE pt.id IS NULL)
		BEGIN
			INSERT INTO SI_PRODUCTO_tp_id (si_producto_id, si_tipoproducto_id)
			SELECT tip_prod.p_id, tip_prod.t_id FROM (SELECT DISTINCT p.id as p_id, t.id as t_id, TRIM(i.STMPDH_ARTCOD) as cod, TRIM(i.STMPDH_TIPPRO) as tip_prod, pt.si_producto_id, pt.si_tipoproducto_id, pt.id FROM inserted as i
				LEFT JOIN (SELECT tp.id, si_producto_id, si_tipoproducto_id, p.CODIGO_PRODUCTO, t.NOMBRE_TIPO FROM SI_PRODUCTO_tp_id as tp
					LEFT JOIN SI_PRODUCTO as p ON p.id = tp.si_producto_id
					LEFT JOIN SI_TIPOPRODUCTO as t ON t.id = tp.si_tipoproducto_id
				) as pt ON pt.CODIGO_PRODUCTO = TRIM(i.STMPDH_ARTCOD) and pt.NOMBRE_TIPO = TRIM(i.STMPDH_TIPPRO)
				LEFT JOIN SI_PRODUCTO as p ON p.CODIGO_PRODUCTO = TRIM(i.STMPDH_ARTCOD)
				LEFT JOIN SI_TIPOPRODUCTO as t ON t.NOMBRE_TIPO = TRIM(i.STMPDH_TIPPRO)
			WHERE pt.id IS NULL
			) as tip_prod
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
