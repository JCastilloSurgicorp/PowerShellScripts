$Programacion1= New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Tuesday -At 6:15pm

$Accion1= New-ScheduledTaskAction -Execute «PowerShell.exe» -Argument «C:\Users\facturacion01\Documents\AppsSurgi\Scripts\remove pruebas.ps1»

Register-ScheduledTask -TaskName «eliminar» -Trigger $Programacion1 -Action $Accion1 -RunLevel Highest –Force 