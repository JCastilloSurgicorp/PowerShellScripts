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