ALTER PROCEDURE [dbo].[ProcessPickingNotifications]
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
	
	-- Creamos tabla temporal debuglog
    CREATE TABLE ProcessDebug (
        Step NVARCHAR(50),
        Details NVARCHAR(MAX),
        Error NVARCHAR(MAX),
        Time_Stamp DATETIME DEFAULT GETUTCDATE()
    );
	-- Insertamos el inicio del procedimiento en la tabla temporal
	INSERT INTO ProcessDebug (Step, Details) 
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
					INSERT INTO ProcessDebug (Step, Details) 
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
						INSERT INTO ProcessDebug (Step, Details) 
							VALUES ('End', 'No hay mensajes en cola');
						BREAK;
					END
					-- Ingresar el mensaje recibido en la tabla temporal
					INSERT INTO ProcessDebug (Step, Details)
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
						INSERT INTO ProcessDebug (Step, Details)
							VALUES ('XMLConversion', 'Conversión a XML exitosa');
					END TRY
					BEGIN CATCH
						-- Insertar en la tabla temporal si hubo un error durante la conversión
						INSERT INTO ProcessDebug (Step, Error)
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
						INSERT INTO ProcessDebug (Step, Details)
							VALUES ('XQuerySuccess', 'PickingID extraído: ' + CAST(ISNULL(@picking_id, '') AS NVARCHAR));
					END TRY
					BEGIN CATCH
						-- Insertar en la tabla temporal si no se pudo extraer el picking_id
						INSERT INTO ProcessDebug (Step, Error)
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
						INSERT INTO ProcessDebug (Step, Details, Error)
							VALUES ('InvalidID', @picking_id, 'PickingID es NULL o 0');
						---- Registrar todos los logs en la tabla permanente
						--INSERT INTO dbo.BrokerDebugLog (Step, Details, Error, LogTime)
						--SELECT Step, Details, Error, Time_Stamp 
						--FROM ProcessDebug;
						---- Eliminar la tabla temporal
						--DROP TABLE ProcessDebug;
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
						INSERT INTO ProcessDebug (Step, Details)
							VALUES ('APICalled', 'API ejecutada para ID: ' + CAST(@picking_id AS NVARCHAR));
					END TRY
					BEGIN CATCH
						-- Insertamos en la tabla temporal si hubo algún error durante la llamada a la API
						INSERT INTO ProcessDebug (Step, Error)
							VALUES ('APIError', 'Error en API: ' + ERROR_MESSAGE());
					END CATCH
        
				-- Finalizar conversación
				END CONVERSATION @conversation_handle;
        
				COMMIT TRANSACTION;

				-- Insertar en la tabla temporal la finalización de la conversación
				INSERT INTO ProcessDebug (Step, Details)
					VALUES ('EndConversation', 'Conversación finalizada exitosamente');
			END TRY
			BEGIN CATCH
				-- Si aún hay transacciones pendientes revierte los cambios
                IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
                -- Inserta en la tabla temporal el tipo de error encontrado
                INSERT INTO ProcessDebug (Step, Error)
					VALUES ('InnerCatch', 'Error interno: ' + ERROR_MESSAGE());
            END CATCH
		END
	END TRY
	BEGIN CATCH
		-- Inserta en la tabla temporal algun error inesperado
        INSERT INTO ProcessDebug (Step, Error)
        VALUES ('OuterCatch', 'Error externo: ' + ERROR_MESSAGE());
    END CATCH
	---- Registrar todos los logs en la tabla permanente
	INSERT INTO dbo.BrokerDebugLog (Step, Details, Error, LogTime)
    SELECT Step, Details, Error, Time_Stamp 
    FROM ProcessDebug;
	---- Eliminar la tabla temporal
	DROP TABLE ProcessDebug;
END;
GO

-- Verificar la tabla [dbo].[BrokerDebugLog]:
SELECT * FROM [dbo].[BrokerDebugLog]
ORDER BY LogID DESC;
-- Verificar si la tabla temporal sigue activa
SELECT * FROM [dbo].[ProcessDebug]
-- Borrar datos de la tabla DebugLog
--DELETE [DiagnosticMessages]
--DBCC CHECKIDENT('DiagnosticMessages', RESEED, 0)
--DROP TABLE ProcessDebug

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


-- Procedimiento almacenado que hace el POST para activar las django signals
ALTER PROCEDURE [dbo].[CallDjangoNotificationAPI](@picking_id INT)
WITH EXECUTE AS 'CmdShellExecutor'
AS
BEGIN
    DECLARE @url NVARCHAR(400) = 'https://appsurgicorperu.com/notificar_picking/';
    DECLARE @cmd VARCHAR(4000)
	SET @cmd = 'curl -X POST ' + @url + ' -H "Content-Type: application/json" -d "{\"picking_id\": ' + CAST(@picking_id AS VARCHAR) + '}"'

    EXEC xp_cmdshell @cmd, no_output
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
SELECT 
    name, 
    is_broker_enabled,
    service_broker_guid 
FROM sys.databases 
WHERE name = DB_NAME();

-- Recrear todos los objetos de Service Broker
DROP SERVICE [PickingNotificationService];
DROP QUEUE [dbo].[PickingNotificationQueue];
DROP CONTRACT [PickingContract];
DROP MESSAGE TYPE [PickingNotification];

-- Volver a crear en el orden correcto
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
    LogTime DATETIME NOT NULL,
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