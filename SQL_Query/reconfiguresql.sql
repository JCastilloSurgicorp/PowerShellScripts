declare @chkCMDShell as sql_variant
select @chkCMDShell = value from sys.configurations where name = 'xp_cmdshell'
if @chkCMDShell = 0
begin
   EXEC sp_configure 'xp_cmdshell', 1
   RECONFIGURE;
end
else
begin
   Print 'xp_cmdshell is already enabled'
end
--DefaultEndpointsProtocol=https;AccountName=surgisqlbackup;AccountKey=oiEp+rxaFGtLNVMzT7OeW0v5TVXX00qabQv+TzvpDhXFh8R83jWkO7VndhWGdOYbK5rXj==
ALTER CREDENTIAL [https://surgisqlbackup.blob.core.windows.net/sql-backup]
	WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
	SECRET = ''
SET STATISTICS TIME ON
--DROP CREDENTIAL
SELECT name, credential_identity 
FROM sys.credentials 
WHERE name = 'https://surgisqlbackup.blob.core.windows.net/sql-backup';
-- FULL BACKUP
BACKUP DATABASE SURGICORP_ERP
TO URL = 'https://surgisqlbackup.blob.core.windows.net/sql-backup/SURGICORP_ERP_Full.bak'
WITH FORMAT, COMPRESSION, STATS = 5
SET STATISTICS TIME ON;
-- DIFERENCIAL BACKUP
BACKUP DATABASE SURGICORP_ERP
TO URL = 'https://surgisqlbackup.blob.core.windows.net/sql-backup/SURGICORP_ERP_Diff.bak'
WITH DIFFERENTIAL, COMPRESSION;
SET STATISTICS TIME ON;
-- TRANSACCIONES BACKUP
BACKUP LOG SURGICORP_ERP
TO URL = 'https://surgisqlbackup.blob.core.windows.net/sql-backup/SURGICORP_ERP_Log.trn'
WITH COMPRESSION;
--EXEC xp_cmdshell 'powershell.exe -File "C:\SomePath\ThePowerShellFile.ps1"'
/*declare @chkCMDShell as sql_variant
select @chkCMDShell = value from sys.configurations where name = 'xp_cmdshell'
if @chkCMDShell = 0
begin
   EXEC sp_configure 'xp_cmdshell', 1
   RECONFIGURE;
end
else
begin
   Print 'xp_cmdshell is already enabled'
end*/

-- Configurar el xp_cmdshell
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
-- Crear proxy con cuenta windows
EXEC sp_xp_cmdshell_proxy_account '', '';
-- Crear Proxy manualmente
USE [master];
GO
CREATE CREDENTIAL ##xp_cmdshell_proxy_account##
WITH IDENTITY = 'SURGI\srvcaminitos',
SECRET = 'Sistemas@2023';
GO
--GRANT IMPERSONATE ANY LOGIN TO [NT SERVICE\MSSQLSERVER];
-- Borrar Proxy
DROP CREDENTIAL ##xp_cmdshell_proxy_account##
EXEC xp_cmdshell 'whoami';
-- Permitir que el usuario actual ejecute xp_cmdshell
GRANT EXECUTE ON sys.xp_cmdshell TO [SURGI\srvcaminitos];
GRANT EXECUTE ON ProcessPickingNotifications TO [SURGI\srvcaminitos];