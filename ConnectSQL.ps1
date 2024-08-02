# DotNet Assembly
using namespace System.Data
using namespace System.Collections.Generic

# Datos del Servidor
$sqlServer = "SVRSURGI\SVRBIOPRO"
$sqlDatabase = "SURGICORP_POWERAPPS"
# Datos del Usuario
$sqlUser = "powerapps"
$sqlPass = "*Surgi007"
# Datos del QUERY
$sqlTable = "DOCGUI_PWRAPP"
$sqlQuery = "SELECT * FROM SURGICORP_POWERAPPS.dbo.$sqlTable WHERE OC_CLIENTE='' and FECHA_GUIA >= DATEADD(DAY,-1,CURRENT_TIMESTAMP)"
# Iniciando Conexión
$Conection = New-Object SqlClient.SqlConnection
$Conection.ConnectionString = "Server=$sqlServer;Database=$sqlDatabase;user=$sqlUser;password=$sqlPass"
$Conection.Open()
# Aplicando Comandos QUERY
$command = New-Object SqlClient.SqlCommand
$command.Connection = $Conection
$command.CommandText = $sqlQuery
# Adaptador
$Adapter = New-Object SqlClient.SqlDataAdapter $command
$dataSet = New-Object DataSet
$Adapter.fill($dataSet)
# Cerrar Conexión con SQL
$Conection.Close()
# Show Data
Write-Output $dataSet.tables[0]