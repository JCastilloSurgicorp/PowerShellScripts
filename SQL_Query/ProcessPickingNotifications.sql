ALTER PROCEDURE [dbo].[ProcessPickingNotifications]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
	SET IMPLICIT_TRANSACTIONS OFF;

	-- Insertamos el inicio del procedimiento en la tabla temporal
	INSERT INTO [BrokerDebugLog] (Step, Details) 
		VALUES ('Start', 'Procedimiento iniciado');
	
	-- Valores principales para transaccion
    DECLARE 
        @conversation_handle UNIQUEIDENTIFIER,
		@message_type_name SYSNAME,
        @message_body VARBINARY(MAX),
		@picking_id INT;
	-- Bucle principal para transaccion por cada item en el queue
	BEGIN TRY
		WHILE (1=1)
		BEGIN
			BEGIN TRY
				BEGIN TRANSACTION;
					-- Insertamos el inicio de la transacción en la tabla temporal
					INSERT INTO [BrokerDebugLog] (Step, Details) 
						VALUES ('BeginTransaction', 'Transacción Iniciada');
					-- procesa el último item del queue
					WAITFOR (
						RECEIVE TOP (1)
							@conversation_handle = conversation_handle,
							@message_body = message_body, -- Sin conversión a XML
							@message_type_name = message_type_name
						FROM [PickingNotificationQueue]
					), TIMEOUT 1000;
					-- Si no hay valores en el queue, termina el bucle
					IF @@ROWCOUNT = 0
					BEGIN
						ROLLBACK TRANSACTION;
						-- Insertar en la tabla temporal el final del proceso
						INSERT INTO [BrokerDebugLog] (Step, Details) 
							VALUES ('End', 'No hay mensajes en cola');
						BREAK;
					END
					-- Ingresar el mensaje recibido en la tabla temporal
					INSERT INTO [BrokerDebugLog] (Step, Details)
						VALUES ('MessageReceived', 
							'Mensaje recibido. Tipo: ' + @message_type_name + 
							' | Longitud: ' + CAST(DATALENGTH(@message_body) AS NVARCHAR)
						);
					-- Registrar mensaje crudo en tabla de diagnóstico
					INSERT INTO dbo.DiagnosticMessages (conversation_handle, raw_message, message_type)
						VALUES (@conversation_handle, @message_body, @message_type_name);
					-- Intentar conversión segura a XML
					DECLARE @xml_body XML;
					BEGIN TRY
						SET @xml_body = CAST(@message_body AS XML);
						-- Insertar en tabla temporal si la conversión fue exitosa
						INSERT INTO [BrokerDebugLog] (Step, Details)
							VALUES ('XMLConversion', 'Conversión a XML exitosa');
					END TRY
					BEGIN CATCH
						-- Insertar en la tabla temporal si hubo un error durante la conversión
						INSERT INTO [BrokerDebugLog] (Step, Error)
							VALUES ('XMLConversion', 'Error en conversión XML: ' + ERROR_MESSAGE());
						-- Finalizar conversación con error
						END CONVERSATION @conversation_handle 
							WITH ERROR = 50000 
							DESCRIPTION = 'Invalid XML format';
                        
						COMMIT TRANSACTION;
						CONTINUE;
					END CATCH
					-- Intentar extraer el picking_id
					BEGIN TRY
						SET @picking_id = CAST(CAST(@xml_body.query('/PickingNotifications/PickingID/text()') as NVARCHAR(MAX)) as INT);
						-- Insertar en la tabla temporal si se pudo extraer el picking_id
						INSERT INTO [BrokerDebugLog] (Step, Details)
							VALUES ('XQuerySuccess', 'PickingID extraído: ' + CAST(ISNULL(@picking_id, '') AS NVARCHAR));
					END TRY
					BEGIN CATCH
						-- Insertar en la tabla temporal si no se pudo extraer el picking_id
						INSERT INTO [BrokerDebugLog] (Step, Error)
							VALUES ('XQueryError', 'Error en XQuery: ' + ERROR_MESSAGE());
						-- Terminar la conversacion con error personalizado
						END CONVERSATION @conversation_handle 
							WITH ERROR = 50001 
							DESCRIPTION = 'XQuery extraction failed';
                        
						COMMIT TRANSACTION;
						CONTINUE;
					END CATCH
					-- Verificar si se obtuvo un Picking ID válido
					IF @picking_id IS NULL or @picking_id = 0
					BEGIN
						-- Si el picking_id no es valido ingresar en la tabla temporal
						INSERT INTO [BrokerDebugLog] (Step, Details, Error)
							VALUES ('InvalidID', @picking_id, 'PickingID es NULL o 0');
						-- Terminar la conversación con un error personalizado
						END CONVERSATION @conversation_handle 
							WITH ERROR = 50002 
							DESCRIPTION = 'Invalid PickingID';
                        
						COMMIT TRANSACTION;
						CONTINUE;
					END
					-- Ejecutamos la llamada a tu API usando un procedimiento almacenado
					BEGIN TRY
						EXEC [dbo].[CallDjangoNotificationAPI] @picking_id;
						-- Insertamos en la tabla temporal la llamada a la API si fue exitosa
						INSERT INTO [BrokerDebugLog] (Step, Details)
							VALUES ('APICalled', 'API ejecutada para ID: ' + CAST(@picking_id AS NVARCHAR));
					END TRY
					BEGIN CATCH
						-- Insertamos en la tabla temporal si hubo algún error durante la llamada a la API
						INSERT INTO [BrokerDebugLog] (Step, Error)
							VALUES ('APIError', 'Error en API: ' + ERROR_MESSAGE());
					END CATCH
        
				-- Finalizar conversación
				END CONVERSATION @conversation_handle;
        
				COMMIT TRANSACTION;

				-- Insertar en la tabla temporal la finalización de la conversación
				INSERT INTO [BrokerDebugLog] (Step, Details)
					VALUES ('EndConversation', 'Conversación finalizada exitosamente');
			END TRY
			BEGIN CATCH
				-- Si aún hay transacciones pendientes revierte los cambios
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                -- Inserta en la tabla temporal el tipo de error encontrado
                INSERT INTO [BrokerDebugLog] (Step, Error)
					VALUES ('InnerCatch', 'Error interno: ' + ERROR_MESSAGE());
            END CATCH
		END
	END TRY
	BEGIN CATCH
		-- Inserta en la tabla temporal algun error inesperado
        INSERT INTO [BrokerDebugLog] (Step, Error)
        VALUES ('OuterCatch', 'Error externo: ' + ERROR_MESSAGE());
    END CATCH
END;
GO

-- Verificar la tabla [dbo].[BrokerDebugLog]:
SELECT * FROM [dbo].[BrokerDebugLog]
ORDER BY LogID DESC;
-- Verificar si la tabla temporal sigue activa
SELECT * FROM [dbo].[ProcessDebug]
-- Borrar datos de la tabla DebugLog
--DELETE [ProcessDebug]
--DBCC CHECKIDENT('DiagnosticMessages', RESEED, 0)
--DROP TABLE [ProcessDebug]
--BACKUP LOG SURGICORP_ERP TO DISK = 'NUL' WITH NOFORMAT, NOINIT, SKIP, NOREWIND, NOUNLOAD, STATS = 10;
--ALTER DATABASE [TuBaseDeDatos] SET ENABLE_BROKER;
SELECT * FROM sys.databases
GO
SELECT
    name AS logical_name,
    physical_name,
    size * 8 / 1024 AS size_in_mb,
    max_size,
    CASE max_size
        WHEN 0 THEN 'No Growth'
        WHEN -1 THEN 'Unrestricted'
        ELSE CONVERT(VARCHAR, max_size * 8 / 1024) + ' MB'
    END AS max_size_desc
FROM sys.database_files
WHERE type_desc = 'LOG';
GO

-- Mandar señal directamente desde el procedimiento almacenado
DECLARE @DialogHandle UNIQUEIDENTIFIER;
DECLARE @Message XML;
-- Crear mensaje XML con los IDs necesarios
SELECT @Message = (
	SELECT 192 AS PickingID
	FOR XML PATH('PickingNotifications')
);
-- Iniciar diálogo
BEGIN 
	DIALOG CONVERSATION @DialogHandle
	FROM SERVICE [PickingNotificationService]
	TO SERVICE 'PickingNotificationService'
	ON CONTRACT [PickingContract]
	WITH ENCRYPTION = OFF;
-- Enviar mensaje
SEND ON CONVERSATION @DialogHandle
	MESSAGE TYPE [PickingNotification] (@Message);

--Error interno: The current transaction cannot be committed and cannot support operations that write to the log file. Roll back the transaction.

-- Verificar tabla [dbo].[DiagnosticMessages]
SELECT *, CAST(raw_message as XML) as message_ FROM [dbo].[DiagnosticMessages]
ORDER BY DiagID desc

-- Comprobar que todo funciona
SELECT CAST(message_body AS nvarchar(max)) AS message_, * 
FROM sys.transmission_queue 
WHERE to_service_name = 'PickingNotificationService';

SELECT conversation_handle, state_desc, far_service, *
FROM sys.conversation_endpoints
WHERE far_service = 'PickingNotificationService';

SELECT CAST(message_body AS XML) AS message_body, *
FROM dbo.PickingNotificationQueue WITH (NOLOCK);

--SELECT 
--    name,
--    type_desc,
--    is_activation_enabled
--FROM sys.service_queues;

-- Reactivar el PickingNotificationQueue:
ALTER QUEUE PickingNotificationQueue WITH STATUS = ON;
--ALTER QUEUE [dbo].[PickingNotificationQueue]
--WITH EXECUTE AS OWNER;

--Comprobar mensajes en la cola
SELECT 
    conversation_handle,
    message_sequence_number,
    CAST(message_body AS XML) AS message_body,
    queuing_order,
    message_type_name
FROM dbo.PickingNotificationQueue;

--Verificar estado de activación:
SELECT 
    name AS queue_name,
    is_activation_enabled,
    --procedure_name,
    execute_as_principal_id, *
FROM sys.service_queues 
WHERE name = 'PickingNotificationQueue';

--Verificar sesiones con transacciones abiertas
SELECT session_id, transaction_id, name as '[ProcessPickingNotifications]'
FROM sys.dm_tran_active_transactions AS tat
INNER JOIN sys.dm_exec_sessions AS es ON tat.transaction_id = es.open_transaction_count
WHERE es.open_transaction_count > 0;

-- Verificar permisos del procedimiento
SELECT 
    USER_NAME(principal_id) AS Ejecutor,
    name AS Procedimiento
FROM sys.procedures
WHERE name = 'ProcessPickingNotifications';

-- Procedimiento almacenado que hace el POST para activar las django signals
ALTER PROCEDURE [dbo].[CallDjangoNotificationAPI](@picking_id INT)
WITH EXECUTE AS OWNER
AS
BEGIN
    DECLARE @url NVARCHAR(400) = 'https://appsurgicorperu.com/notificar_picking/';
    DECLARE @cmd VARCHAR(4000)
	SET @cmd = 'curl -X POST ' + @url + ' -H "Content-Type: application/json" -d "{\"picking_id\": ' + CAST(@picking_id AS VARCHAR) + '}"'

    BEGIN TRY
        EXEC xp_cmdshell @cmd, no_output;
    END TRY
    BEGIN CATCH
        -- Solo registrar error, no afectar transacción principal
		INSERT INTO dbo.BrokerDebugLog (Step, Error)
		VALUES('CallDjangoNotificationAPI', 'Error en llamada API: ' + ERROR_MESSAGE());
    END CATCH
END;
GO
-- Comprobar que procedimiento almacenado funciona
BEGIN
    DECLARE @url NVARCHAR(400) = 'https://appsurgicorperu.com/notificar_picking/';
	DECLARE @picking_id INT = 192
    DECLARE @cmd VARCHAR(4000)
	SET @cmd = 'curl -X POST ' + @url + ' -H "Content-Type: application/json" -d "{\"picking_id\": ' + CAST(@picking_id AS VARCHAR) + '}"'

    EXEC xp_cmdshell @cmd, no_output
END;
--Verficar exec notificaciones funciona
USE master;
DECLARE @picking_id INT = 192; -- Usar un ID existente
EXEC dbo.CallDjangoNotificationAPI @picking_id;



-- Finalizar todas las conversaciones activas con limpieza
DECLARE @conversation_handle UNIQUEIDENTIFIER;
DECLARE conversation_cursor CURSOR FOR
SELECT conversation_handle 
FROM sys.conversation_endpoints 
WHERE state_desc = 'CONVERSING';

OPEN conversation_cursor;
FETCH NEXT FROM conversation_cursor INTO @conversation_handle;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Finalizar con limpieza (elimina sin mensaje de fin)
    END CONVERSATION @conversation_handle WITH CLEANUP;
    FETCH NEXT FROM conversation_cursor INTO @conversation_handle;
END

CLOSE conversation_cursor;
DEALLOCATE conversation_cursor;


-- Limpiar mensajes atascados en la cola de transmisión
DECLARE @dialog_handle UNIQUEIDENTIFIER;
DECLARE transmission_cursor CURSOR FOR
SELECT conversation_handle 
FROM sys.transmission_queue;

OPEN transmission_cursor;
FETCH NEXT FROM transmission_cursor INTO @dialog_handle;

WHILE @@FETCH_STATUS = 0
BEGIN
    END CONVERSATION @dialog_handle WITH CLEANUP;
    FETCH NEXT FROM transmission_cursor INTO @dialog_handle;
END

CLOSE transmission_cursor;
DEALLOCATE transmission_cursor;


-- Debería mostrar 0 conversaciones
SELECT COUNT(*) FROM sys.conversation_endpoints;
SELECT COUNT(*) FROM sys.transmission_queue;

-- Verificar estado del broker
Use [SURGICORP_ERP];
GO
SELECT 
    name, 
    is_broker_enabled,
    service_broker_guid 
FROM sys.databases 
WHERE name = DB_NAME();

--Verifica conexiones activas
SELECT 
    session_id, 
    login_name, 
    status, 
    host_name,
    program_name,
    last_request_start_time
FROM sys.dm_exec_sessions
WHERE database_id = DB_ID('SURGICORP_ERP');

-- Habilitar Service Broker
ALTER DATABASE [SURGICORP_ERP] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [SURGICORP_ERP] SET ENABLE_BROKER;
ALTER DATABASE [SURGICORP_ERP] SET MULTI_USER;

-- * Desactivar la cola primero
ALTER QUEUE [dbo].[PickingNotificationQueue] WITH ACTIVATION (STATUS = OFF);
-- Recrear todos los objetos de Service Broker
DROP SERVICE [PickingNotificationService];
DROP QUEUE [dbo].[PickingNotificationQueue];
DROP CONTRACT [PickingContract];
DROP MESSAGE TYPE [PickingNotification];

-- Volver a crear en el orden correcto

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
    MAX_QUEUE_READERS = 5,
    PROCEDURE_NAME = [dbo].[ProcessStockUpdates],
    EXECUTE AS OWNER
);

-- Notificaciones de Hojas Picking 
-- 1. Crear Message Type
CREATE MESSAGE TYPE [PickingNotification]
    AUTHORIZATION dbo
	VALIDATION = None;

-- 2. Crear Contract
CREATE CONTRACT [PickingContract]
    ([PickingNotification] SENT BY ANY);

-- 3. Crear Queue
CREATE QUEUE [dbo].[PickingNotificationQueue]
    WITH STATUS = ON, RETENTION = OFF;

-- 4. Crear Service
CREATE SERVICE [PickingNotificationService]
    ON QUEUE [dbo].[PickingNotificationQueue] ([PickingContract]);

-- Reasociar el procedimiento de activación
ALTER QUEUE [dbo].[PickingNotificationQueue]
WITH ACTIVATION (
    STATUS = ON,
    MAX_QUEUE_READERS = 5,
    PROCEDURE_NAME = [dbo].[ProcessPickingNotifications],
    EXECUTE AS OWNER
);

-- Crear tabla de logs del broker:
CREATE TABLE dbo.BrokerDebugLog (
    LogID INT IDENTITY PRIMARY KEY,
    LogTime DATETIME DEFAULT GETUTCDATE(),
    Step NVARCHAR(100) NOT NULL,
    Details NVARCHAR(MAX) NULL,
	Error NVARCHAR(MAX) NULL
);
-- Crear tabla para mensajes crudos
CREATE TABLE dbo.DiagnosticMessages (
    DiagID BIGINT IDENTITY PRIMARY KEY,
    LogTime DATETIME NOT NULL DEFAULT GETDATE(),
    conversation_handle UNIQUEIDENTIFIER,
    message_type SYSNAME,
    raw_message VARBINARY(MAX)
);


--EXEC sp_configure 'xp_cmdshell';


ALTER PROCEDURE [dbo].[ProcessStockUpdates]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @dialog_handle UNIQUEIDENTIFIER;
    DECLARE @message_body XML;
    DECLARE @message_type_name SYSNAME;
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
		STRMVK_TIPAMJ VARCHAR(60)
	);
    BEGIN TRANSACTION;

    -- Recibir y procesar los mensajes en un bucle
    -- WAITFOR (RECEIVE ...) es crucial para que el activador no consuma CPU
    WHILE (1=1)
    BEGIN
		WAITFOR (
			RECEIVE TOP (1)
				@dialog_handle = conversation_handle,
				@message_body = message_body,
				@message_type_name = message_type_name
			FROM [StockUpdatesQueue]
		), TIMEOUT 1000;

		-- Si no hay valores en el queue, termina el bucle
		IF @@ROWCOUNT = 0
        BEGIN
            BREAK;
        END;

        -- Extraer los datos del mensaje XML y agregarlos a la tabla temporal
        INSERT INTO #SI_BatchInserted (
            STRMVK_DEPOSI, STRMVK_DESDEP, STRMVK_SECTOR, STRMVK_DESSEC,
            STRMVK_TIPALM, STRMVK_DESALM, STRMVK_ARTCOD, STRMVK_CANTID,
            STRMVK_NSERIE, STRMVK_TIPAMJ
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
            T.Item.value('(STRMVK_TIPAMJ/text())[1]', 'VARCHAR(60)')
        FROM @message_body.nodes('/inserted/row') AS T(Item);

        -- Finalizar la conversación después de procesar el mensaje
        END CONVERSATION @dialog_handle;
    END

    -- Inserta en SI_Desposito si no está en la lista.
		INSERT INTO SI_DEPOSITO (CODIGO_DEPOSITO, DESCRIPCION)
		SELECT DISTINCT TRIM(i.STRMVK_DEPOSI), i.STRMVK_DESDEP
		FROM #SI_BatchInserted AS i
			LEFT JOIN SI_DEPOSITO AS d ON d.CODIGO_DEPOSITO = TRIM(i.STRMVK_DEPOSI)
		WHERE d.id IS NULL AND TRIM(i.STRMVK_DEPOSI) IS NOT NULL;

		-- Inserta en SI_SECTOR si no está en la lista.
		INSERT INTO SI_SECTOR (NOMBRE_SECTOR, DESCRIPCION)
		SELECT DISTINCT TRIM(i.STRMVK_SECTOR), i.STRMVK_DESSEC
		FROM #SI_BatchInserted AS i
			LEFT JOIN SI_SECTOR AS s ON s.NOMBRE_SECTOR = TRIM(i.STRMVK_SECTOR)
		WHERE s.id IS NULL AND TRIM(i.STRMVK_SECTOR) IS NOT NULL;

		-- Inserta en SI_TIPOALMACEN si no está en la lista.
		INSERT INTO SI_TIPOALMACEN (NOMBRE_ALMACEN, DESCRIPCION)
		SELECT DISTINCT IIF(i.STRMVK_TIPALM = '', '-', i.STRMVK_TIPALM), i.STRMVK_DESALM
		FROM #SI_BatchInserted AS i
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
				FROM #SI_BatchInserted
				GROUP BY TRIM(STRMVK_ARTCOD)
			) AS i ON st.PRODUCTO_ID = (SELECT p.id FROM SI_PRODUCTO AS p WHERE p.CODIGO_PRODUCTO = i.ARTCOD);

		-- Inserta en la tabla de stock_inventario si no existe el registro
		INSERT INTO STOCK_INVENTARIO (PRODUCTO_ID, STOCK)
		SELECT p.id, i.TotalCantidad
		FROM (
			SELECT 
				TRIM(STRMVK_ARTCOD) AS ARTCOD, 
				SUM(STRMVK_CANTID) AS TotalCantidad
			FROM #SI_BatchInserted
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
			FROM #SI_BatchInserted
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
			i.STRMVK_TIPAMJ
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
			FROM #SI_BatchInserted
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

    COMMIT TRANSACTION;
	DROP TABLE #SI_BatchInserted;
END;