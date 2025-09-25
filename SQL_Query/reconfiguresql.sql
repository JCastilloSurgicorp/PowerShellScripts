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

CREATE CREDENTIAL [https://sqldjangostorage.blob.core.windows.net/sql-backup]
	WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
	SECRET = 'sp=racwdl&st=2025-09-10T22:09:58Z&se=2045-09-11T06:24:58Z&spr=https&sv=2024-11-04&sr=c&sig=EN4M5CxvcKGX%2By3dVR5FPgU92NkTWItPPGVCbqQTE%3D'
SET STATISTICS TIME ON
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
-- Crear CmdShellExecutor
USE [master];
GO
CREATE LOGIN [CmdShellExecutor] WITH PASSWORD = 'j4ir0st123'; -- Cambia la contraseña
GO
USE [SURGICORP_ERP];
GO
CREATE USER [CmdShellExecutor] FOR LOGIN [CmdShellExecutor];
GO
USE [SURGICORP_ERP];
GO
GRANT EXECUTE ON [dbo].[CallDjangoNotificationAPI] TO [CmdShellExecutor];
GRANT EXECUTE ON [dbo].[ProcessPickingNotifications] TO [CmdShellExecutor];
GO
-- Configurar el xp_cmdshell
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
-- Crear proxy con cuenta windows
EXEC sp_xp_cmdshell_proxy_account 'SURGI\srvcaminitos', 'Sistemas@2023';
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