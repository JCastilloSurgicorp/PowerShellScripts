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