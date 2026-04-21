ALTER PROCEDURE [dbo].[ProcessStockUpdates]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
	SET IMPLICIT_TRANSACTIONS OFF;

	-- Insertamos el inicio del procedimiento en la tabla temporal
	INSERT INTO [SI_BrokerDebugLog] (Step, Details) 
		VALUES ('Inicio', 'Procedimiento iniciado en [ProcessStockUpdates]');

	-- Crear tabla de inserts del broker:
	CREATE TABLE #SI_BatchInserted (
		STRMVK_DEPOSI VARCHAR(60),
		STRMVK_DESDEP VARCHAR(120),
		STRMVK_SECTOR VARCHAR(60),
		STRMVK_DESSEC VARCHAR(120),
		STRMVK_TIPALM VARCHAR(60),
		STRMVK_DESALM VARCHAR(120),
		STRMVK_ARTCOD VARCHAR(60),
		STRMVK_CANTID DECIMAL(18, 4),
		STRMVK_NSERIE VARCHAR(120),
		STRMVK_TIPAMJ VARCHAR(60),
		STRMVK_CODEMP VARCHAR(60),
		STRMVK_NROGUI VARCHAR(60),
		STRMVK_TIPPRO VARCHAR(60),
		STRMVK_ORIGEN VARCHAR(60)
	);

    BEGIN TRY
		WHILE (1=1)
		BEGIN
			-- Valores principales para transaccion
			DECLARE 
				@dialog_handle UNIQUEIDENTIFIER,
				@message_body VARBINARY(MAX),
				@message_type_name SYSNAME;
			--BEGIN TRANSACTION;
				-- Insertamos el inicio de la transacción en la tabla temporal
				INSERT INTO [SI_BrokerDebugLog] (Step, Details) 
						VALUES ('TransacciónInicial', 'Transacción Iniciada en [ProcessStockUpdates]');
				WAITFOR (
					RECEIVE TOP (1)
						@dialog_handle = conversation_handle,
						@message_body = message_body,
						@message_type_name = message_type_name
					FROM [StockUpdateQueue]
				), TIMEOUT 10000;
				-- Si no hay valores en el queue, termina el bucle
				IF @@ROWCOUNT = 0
				BEGIN
					--ROLLBACK TRANSACTION;
					-- Insertar en la tabla temporal el final del proceso
					INSERT INTO [SI_BrokerDebugLog] (Step, Details) 
						VALUES ('Final', 'No hay mensajes en cola de [ProcessStockUpdates]');
					BREAK;
				END;
				-- Limpiamos la tabla temporal para este mensaje específico
				TRUNCATE TABLE #SI_BatchInserted;
				-- Intentar conversión segura a XML
				DECLARE @xml_body XML;
				BEGIN TRY
					SET @xml_body = CAST(@message_body AS XML);
					-- Extraer los datos del mensaje XML y agregarlos a la tabla temporal
					INSERT INTO #SI_BatchInserted (
						STRMVK_DEPOSI, STRMVK_DESDEP, STRMVK_SECTOR, STRMVK_DESSEC,
						STRMVK_TIPALM, STRMVK_DESALM, STRMVK_ARTCOD, STRMVK_CANTID,
						STRMVK_NSERIE, STRMVK_TIPAMJ, STRMVK_CODEMP, STRMVK_NROGUI, 
						STRMVK_TIPPRO, STRMVK_ORIGEN
					)
					SELECT
						T.Item.value('(STRMVK_DEPOSI/text())[1]', 'VARCHAR(60)'),
						T.Item.value('(STRMVK_DESDEP/text())[1]', 'VARCHAR(120)'),
						T.Item.value('(STRMVK_SECTOR/text())[1]', 'VARCHAR(60)'),
						T.Item.value('(STRMVK_DESSEC/text())[1]', 'VARCHAR(120)'),
						T.Item.value('(STRMVK_TIPALM/text())[1]', 'VARCHAR(60)'),
						T.Item.value('(STRMVK_DESALM/text())[1]', 'VARCHAR(120)'),
						T.Item.value('(STRMVK_ARTCOD/text())[1]', 'VARCHAR(60)'),
						T.Item.value('(STRMVK_CANTID/text())[1]', 'DECIMAL(18, 4)'),
						T.Item.value('(STRMVK_NSERIE/text())[1]', 'VARCHAR(120)'),
						T.Item.value('(STRMVK_TIPAMJ/text())[1]', 'VARCHAR(60)'),
						T.Item.value('(STRMVK_CODEMP/text())[1]', 'VARCHAR(60)'),
						T.Item.value('(STRMVK_NROGUI/text())[1]', 'VARCHAR(60)'),
						T.Item.value('(STRMVK_TIPPRO/text())[1]', 'VARCHAR(60)'),
						T.Item.value('(STRMVK_ORIGEN/text())[1]', 'VARCHAR(60)')
					FROM @xml_body.nodes('/inserted') AS T(Item);
					-- Insertar en tabla temporal si la conversión fue exitosa
					INSERT INTO [SI_BrokerDebugLog] (Step, Details)
						VALUES ('XMLConversion', 'Conversión a XML exitosa en [ProcessStockUpdates]');
				END TRY
				BEGIN CATCH
					-- Insertar en la tabla temporal si hubo un error durante la conversión
					INSERT INTO [SI_BrokerDebugLog] (Step, Error)
						VALUES ('XMLConversion', 'Error en conversión XML en [ProcessStockUpdates]: ' + ERROR_MESSAGE());
					-- Finalizar conversación con error
					END CONVERSATION @dialog_handle 
						WITH ERROR = 50000 
						DESCRIPTION = 'Error en [ProcessStockUpdates]: Invalid XML format';

					COMMIT TRANSACTION;
					CONTINUE;
				END CATCH
				BEGIN TRY
					-- Inserta en SI_Desposito si no está en la lista.
					INSERT INTO SI_DEPOSITO (CODIGO_DEPOSITO, DESCRIPCION)
					SELECT DISTINCT TRIM(i.STRMVK_DEPOSI), i.STRMVK_DESDEP
					FROM #SI_BatchInserted AS i
						LEFT JOIN SI_DEPOSITO AS d ON d.CODIGO_DEPOSITO = TRIM(i.STRMVK_DEPOSI)
					WHERE d.id IS NULL AND TRIM(i.STRMVK_DEPOSI) IS NOT NULL AND STRMVK_ORIGEN = 'INSERTED';

					-- Inserta en SI_SECTOR si no está en la lista.
					INSERT INTO SI_SECTOR (NOMBRE_SECTOR, DESCRIPCION)
					SELECT DISTINCT TRIM(i.STRMVK_SECTOR), i.STRMVK_DESSEC
					FROM #SI_BatchInserted AS i
						LEFT JOIN SI_SECTOR AS s ON s.NOMBRE_SECTOR = TRIM(i.STRMVK_SECTOR)
					WHERE s.id IS NULL AND TRIM(i.STRMVK_SECTOR) IS NOT NULL AND STRMVK_ORIGEN = 'INSERTED';

					-- Inserta en SI_TIPOALMACEN si no está en la lista.
					INSERT INTO SI_TIPOALMACEN (NOMBRE_ALMACEN, DESCRIPCION)
					SELECT DISTINCT IIF(i.STRMVK_TIPALM = '', '-', i.STRMVK_TIPALM), i.STRMVK_DESALM
					FROM #SI_BatchInserted AS i
						LEFT JOIN SI_TIPOALMACEN AS tp ON tp.NOMBRE_ALMACEN = IIF(i.STRMVK_TIPALM = '', '-', i.STRMVK_TIPALM)
					WHERE tp.id IS NULL AND STRMVK_ORIGEN = 'INSERTED';

					-- Actualiza la tabla de stock_inventario si existe el registro
					IF EXISTS (SELECT 1 FROM #SI_BatchInserted)
					BEGIN
						MERGE STOCK_INVENTARIO AS target
						USING (
							SELECT 
								p.id as p_id, i.STRMVK_ARTCOD as cod, p.TIPO as tipo,
								(e.EMPRESA + ' | ' + i.STRMVK_TIPAMJ + ' | ' + i.STRMVK_TIPALM) as alm,
								SUM(CASE WHEN i.STRMVK_ORIGEN = 'DELETED' THEN i.STRMVK_CANTID * -1 ELSE i.STRMVK_CANTID END) as cant
							FROM #SI_BatchInserted as i
							LEFT JOIN [SI_PRODUCTO] p ON p.CODIGO_PRODUCTO = i.STRMVK_ARTCOD AND p.TIPO = i.STRMVK_TIPPRO
							LEFT JOIN [dbo].[SI_Empresa] e ON e.id = i.STRMVK_CODEMP
							GROUP BY p.id, i.STRMVK_ARTCOD, p.TIPO, (e.EMPRESA + ' | ' + i.STRMVK_TIPAMJ + ' | ' + i.STRMVK_TIPALM)
						) AS source
						ON (target.PRODUCTO_ID = source.p_id and target.ALMACENAJE = source.alm)
						WHEN MATCHED THEN
							UPDATE SET 
								target.STOCK = target.STOCK + source.cant,
								target.USUARIO = 'Modificado por Servidor - ' + CAST(DATEADD(HOUR, -5, GETUTCDATE()) As VARCHAR(20))
						WHEN NOT MATCHED THEN
							INSERT (PRODUCTO_ID, ALMACENAJE, STOCK, USUARIO)
							VALUES (source.p_id, source.alm, source.cant, 'Creado por Servidor - ' + CAST(DATEADD(HOUR, -5, GETUTCDATE()) As VARCHAR(20)));
					END

					-- Insertar nuevos registros en SI_DESCRIPCION
					--

					-- Finalizar la conversación después de procesar el mensaje
					END CONVERSATION @dialog_handle;
					--COMMIT TRANSACTION;
				END TRY
				BEGIN CATCH
					-- Si aún hay transacciones pendientes revierte los cambios
					IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
					-- Insertar en la tabla temporal si no se pudo procesar los datos
					INSERT INTO [SI_BrokerDebugLog] (Step, Error)
						VALUES ('XQueryError', 'Error en XQuery en [ProcessStockUpdates]: ' + ERROR_MESSAGE());
					-- Insertar en la tabla SI_UPDATE_AUDIT si no se pudo procesar los datos
					INSERT INTO [dbo].[SI_UPDATE_AUDIT] ([ID_CONCAT], [TABLA], [CAMPO], [ESTADO_OLD], [ESTADO_NEW], [FECHA_HORA])
						VALUES ('ProcessStockUpdates', 'XQuery', 'ERROR', 'XMLConversion', 'Error en XQuery en [ProcessStockUpdates]: ' + ERROR_MESSAGE(), GETUTCDATE());
					-- Terminar la conversacion con error personalizado
					END CONVERSATION @dialog_handle 
						WITH ERROR = 50001 
						DESCRIPTION = 'XQuery extraction failed';
					COMMIT TRANSACTION;                                                                                                                                                                                                                                                                                                                                                                                                                             
					CONTINUE;
				END CATCH
		END
	END TRY
	BEGIN CATCH
		-- Inserta en la tabla temporal algun error inesperado
        INSERT INTO [SI_BrokerDebugLog] (Step, Error)
        VALUES ('CatchExterno', 'Error externo en ProcessStockUpdates: ' + ERROR_MESSAGE());
    END CATCH
END;

SELECT * FROM [dbo].[SI_BrokerDebugLog]
--WHERE Error is not NULL
ORDER BY LogID DESC;

EXEC dbo.[ProcessStockUpdates]; 

--DELETE FROM [SI_BrokerDebugLog]
--DBCC CHECKIDENT('SI_BrokerDebugLog', RESEED, 0)

--SELECT COUNT(*) FROM [dbo].[StockUpdateQueue]
--SELECT is_broker_enabled FROM sys.databases WHERE name = DB_NAME();
--SELECT TOP 100 * FROM [dbo].[StockUpdateQueue] ORDER BY queuing_order;
--SELECT * FROM StockUpdateQueue WITH (NOLOCK);
SELECT name, service_queue_id, *
FROM sys.services
WHERE name = 'StockUpdateService'; 
SELECT name, *
FROM sys.service_queues
WHERE name = 'StockUpdateQueue';
SELECT conversation_handle, state_desc, far_service, *
FROM sys.conversation_endpoints
WHERE far_service = 'StockUpdateService';

-- * Desactivar la cola primero
--ALTER QUEUE [dbo].[StockUpdateQueue] WITH ACTIVATION (STATUS = OFF);
-- Recrear todos los objetos de Service Broker
--DROP SERVICE [StockUpdateService];
--DROP QUEUE [dbo].[StockUpdateQueue];
--DROP CONTRACT [StockUpdateContract];
--DROP MESSAGE TYPE [StockUpdateMessage];

-- Actualizacion de Stock de Inventario
-- 1. Crear Message Type
CREATE MESSAGE TYPE [StockUpdateMessage]
    AUTHORIZATION dbo
	VALIDATION = None;

-- 2. Crear Contract
CREATE CONTRACT [StockUpdateContract]
    ([StockUpdateMessage] SENT BY ANY);

-- 3. Crear Queue
CREATE QUEUE [dbo].[StockUpdateQueue]
    WITH STATUS = ON, RETENTION = OFF;

-- 4. Crear Service
CREATE SERVICE [StockUpdateService]
    ON QUEUE [dbo].[StockUpdateQueue] ([StockUpdateContract]);

-- Reasociar el procedimiento de activación
ALTER QUEUE [dbo].[StockUpdateQueue]
WITH ACTIVATION (
    STATUS = ON,
    MAX_QUEUE_READERS = 1,
    PROCEDURE_NAME = [dbo].[ProcessStockUpdates],
    EXECUTE AS OWNER
);

-- Crear tabla de logs del broker:
--CREATE TABLE dbo.SI_BrokerDebugLog (
--    LogID INT IDENTITY PRIMARY KEY,
--    LogTime DATETIME DEFAULT GETUTCDATE(),
--    Step NVARCHAR(100) NOT NULL,
--    Details NVARCHAR(MAX) NULL,
--	Error NVARCHAR(MAX) NULL
--);