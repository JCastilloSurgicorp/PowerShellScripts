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
		-- Inserta en SI_Desposito si no está en la lista.
		INSERT INTO SI_DEPOSITO (CODIGO_DEPOSITO, DESCRIPCION)
		SELECT DISTINCT TRIM(i.STRMVK_DEPOSI), i.STRMVK_DESDEP
		FROM inserted AS i
			LEFT JOIN SI_DEPOSITO AS d ON d.CODIGO_DEPOSITO = TRIM(i.STRMVK_DEPOSI)
		WHERE d.id IS NULL AND TRIM(i.STRMVK_DEPOSI) IS NOT NULL;

		-- Inserta en SI_SECTOR si no está en la lista.
		INSERT INTO SI_SECTOR (NOMBRE_SECTOR, DESCRIPCION)
		SELECT DISTINCT TRIM(i.STRMVK_SECTOR), i.STRMVK_DESSEC
		FROM inserted AS i
			LEFT JOIN SI_SECTOR AS s ON s.NOMBRE_SECTOR = TRIM(i.STRMVK_SECTOR)
		WHERE s.id IS NULL AND TRIM(i.STRMVK_SECTOR) IS NOT NULL;

		-- Inserta en SI_TIPOALMACEN si no está en la lista.
		INSERT INTO SI_TIPOALMACEN (NOMBRE_ALMACEN, DESCRIPCION)
		SELECT DISTINCT IIF(i.STRMVK_TIPALM = '', '-', i.STRMVK_TIPALM), i.STRMVK_DESALM
		FROM inserted AS i
			LEFT JOIN SI_TIPOALMACEN AS tp ON tp.NOMBRE_ALMACEN = IIF(i.STRMVK_TIPALM = '', '-', i.STRMVK_TIPALM)
		WHERE tp.id IS NULL;

		-- Actualiza la tabla de stock_inventario si existe el registro
		UPDATE st
			SET STOCK = STOCK + i.TotalCantidad,
				USUARIO = 'Modificado por Servidor'
		FROM STOCK_INVENTARIO AS st
			INNER JOIN (
				SELECT 
					TRIM(STRMVK_ARTCOD) AS ARTCOD, 
					SUM(STRMVK_CANTID) AS TotalCantidad
				FROM inserted
				GROUP BY TRIM(STRMVK_ARTCOD)
			) AS i ON st.PRODUCTO_ID = (SELECT p.id FROM SI_PRODUCTO AS p WHERE p.CODIGO_PRODUCTO = i.ARTCOD);

		-- Inserta en la tabla de stock_inventario si no existe el registro
		INSERT INTO STOCK_INVENTARIO (PRODUCTO_ID, STOCK)
		SELECT p.id, i.TotalCantidad
		FROM (
			SELECT 
				TRIM(STRMVK_ARTCOD) AS ARTCOD, 
				SUM(STRMVK_CANTID) AS TotalCantidad
			FROM inserted
			GROUP BY TRIM(STRMVK_ARTCOD)
		) AS i
		INNER JOIN SI_PRODUCTO AS p ON p.CODIGO_PRODUCTO = i.ARTCOD
		LEFT JOIN STOCK_INVENTARIO AS st ON st.PRODUCTO_ID = p.id
		WHERE st.id IS NULL;

		-- Inserta en la tabla si_descripcion si no existe el registro
		UPDATE dc
		SET dc.CANTIDAD = dc.CANTIDAD + i.TotalCantidad
		FROM SI_DESCRIPCION AS dc
		INNER JOIN (
			-- Agrupa las inserciones por todas las claves relevantes
			SELECT 
				TRIM(STRMVK_ARTCOD) AS ARTCOD, 
				STRMVK_NSERIE AS NSERIE,
				STRMVK_DEPOSI AS DEPOSI,
				TRIM(STRMVK_SECTOR) AS SECTOR,
				IIF(STRMVK_TIPALM = '', '-', STRMVK_TIPALM) AS TIP_ALM,
				SUM(STRMVK_CANTID) AS TotalCantidad
			FROM inserted
			GROUP BY TRIM(STRMVK_ARTCOD), STRMVK_NSERIE, STRMVK_DEPOSI, TRIM(STRMVK_SECTOR), IIF(STRMVK_TIPALM = '', '-', STRMVK_TIPALM)
		) AS i ON dc.CODIGO_PRODUCTO = i.ARTCOD
		-- Uniones auxiliares para obtener IDs de catálogo
		LEFT JOIN SI_DEPOSITO AS d ON d.CODIGO_DEPOSITO = i.DEPOSI
		LEFT JOIN SI_SECTOR AS s ON s.NOMBRE_SECTOR = i.SECTOR
		LEFT JOIN SI_TIPOALMACEN AS tp ON tp.NOMBRE_ALMACEN = i.TIP_ALM
		WHERE dc.DEPOSITO_ID = d.id 
			AND dc.SECTOR_ID = s.id 
			AND dc.TIPOALMACEN_ID = tp.id
			AND dc.LOTE = i.NSERIE;


		-- Insertar nuevos registros en SI_DESCRIPCION
		INSERT INTO SI_DESCRIPCION (CODIGO_PRODUCTO, CANTIDAD, DESCRIPCION_ID, LOTE, TIPOALMACEN_ID, DEPOSITO_ID, SECTOR_ID, TIPO_ALMACENAJE)
		SELECT 
			i.ARTCOD, 
			i.TotalCantidad, 
			st.id, 
			i.NSERIE, 
			tp.id, 
			d.id, 
			s.id, 
			i.STRMVK_TIPAMJ -- Nota: este campo no estaba en el GROUP BY, si cambia por fila, puede dar problemas
		FROM (
			-- Agrupa las inserciones por todas las claves relevantes
			SELECT 
				TRIM(STRMVK_ARTCOD) AS ARTCOD, 
				STRMVK_NSERIE AS NSERIE,
				STRMVK_DEPOSI AS DEPOSI,
				TRIM(STRMVK_SECTOR) AS SECTOR,
				IIF(STRMVK_TIPALM = '', '-', STRMVK_TIPALM) AS TIP_ALM,
				SUM(STRMVK_CANTID) AS TotalCantidad,
				MAX(STRMVK_TIPAMJ) AS STRMVK_TIPAMJ -- Usamos MAX si el valor es consistente por grupo
			FROM inserted
			GROUP BY TRIM(STRMVK_ARTCOD), STRMVK_NSERIE, STRMVK_DEPOSI, TRIM(STRMVK_SECTOR), IIF(STRMVK_TIPALM = '', '-', STRMVK_TIPALM)
		) AS i
		-- Uniones auxiliares para obtener IDs y verificar inexistencia
		LEFT JOIN SI_PRODUCTO AS p ON p.CODIGO_PRODUCTO = i.ARTCOD
		LEFT JOIN SI_DEPOSITO AS d ON d.CODIGO_DEPOSITO = i.DEPOSI
		LEFT JOIN SI_SECTOR AS s ON s.NOMBRE_SECTOR = i.SECTOR
		LEFT JOIN SI_TIPOALMACEN AS tp ON tp.NOMBRE_ALMACEN = i.TIP_ALM
		LEFT JOIN STOCK_INVENTARIO AS st ON st.PRODUCTO_ID = p.id
		LEFT JOIN SI_DESCRIPCION AS dc ON dc.CODIGO_PRODUCTO = i.ARTCOD
			AND dc.LOTE = i.NSERIE
			AND dc.TIPOALMACEN_ID = tp.id
			AND dc.DEPOSITO_ID = d.id
			AND dc.SECTOR_ID = s.id
		WHERE dc.id IS NULL;

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
				'SI_STOCK_erp_TriggerInsert -> Error: ', @EstadoError,
				' | Severidad: ', @SeveridadError,
				' | Mensaje: ', @MensajeError
			);
			INSERT INTO [dbo].[GR_UPDATE_AUDIT] ([ID_CONCAT], [NUMERO_GUIA], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
				VALUES ('SI_STOCK_erp_TriggerInsert', CONCAT('SI_STOCK_erp_TriggerInsert -> Error: ', @EstadoError,' | Severidad: ', @SeveridadError), 'ERROR', @MensajeError, GETUTCDATE());
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
