
# Valid Colors: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, 
#               Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White
function Write-Yellow($message) {
    Write-Host $message -ForegroundColor "Yellow"
}
# Helper function to convert table data from SQL into hash table
# from https://www.powershellgallery.com/packages/ConvertFrom-DataRow/0.9.1/Content/ConvertFrom-DataRow.psm1
function ConvertFrom-DataRow {
    [CmdletBinding( DefaultParameterSetName = 'AsHashtable' )]
    [OutputType( [System.Collections.Specialized.OrderedDictionary], ParameterSetName = 'AsHashtable' )]
    [OutputType( [pscustomobject], ParameterSetName = 'AsObject' )]
    param(
        [Parameter( Mandatory, Position = 0, ValueFromPipeline = $true )]
        [DataRow[]]
        $InputObject,
        [Parameter( Mandatory, ParameterSetName = 'AsObject' )]
        [switch]
        $AsObject,
        $DbNullValue = $null
    )
    begin {
        [List[string]]$Columns = @()
    }
    process {
        foreach ( $DataRow in $InputObject ) {
            if ( $Columns.Count -eq 0 ) {
                $Columns.AddRange( [string[]]$DataRow.Table.Columns.ColumnName )
            }
            $ReturnObject = @{}
            $Columns | ForEach-Object {
                if ( $DataRow.$_ -is [System.DBNull] ) {
                    $ReturnObject[$_] = $DbNullValue
                }
                else {
                    $ReturnObject[$_] = $DataRow.$_
                }
            }
            if ( $AsObject ) {
                Write-Output ( [pscustomobject]$ReturnObject )
            }
            else {
                Write-Output ( $ReturnObject )
            }
        }
    }
}
# SharePoint Site Data
$spEmpresa = "appsurgicorp"
$spSite = "GUIAS_PENDIENTES"
$spListName = "PEND_GUIAS"
# Tabla SQL a Actualizar
$sqlTable = "[dbo].[HP_PROVEEDOR]"
$spUrl = "https://$spEmpresa.sharepoint.com/sites/$spSite/"
$spClientId = "50e9c267-2992-4b87-9f5b-221430ec4a2f"
$spThumbPrint = "9BC8DC618818698BB996CF0183C155A8ECAF6B05"
$spFields = "ID","Title","field_2"
$spQuery = "<View>
                <Query>
                    <Where>
                        <And>
                            <Gt>
                                <FieldRef Name='ID'/>
                                <Value Type='Number'>0</Value>
                            </Gt>
                            <Lt>
                                <FieldRef Name='ID'/>
                                <Value Type='Number'>90000</Value>
                            </Lt>
                        </And>
                    </Where>
                </Query>
            </View>"
# Connect to PnP Online Using ENTRA: 
Connect-PnPOnline -Tenant appsurgicorp.onmicrosoft.com -ClientId $spClientId -Thumbprint $spThumbPrint -Url $spUrl

$start = Get-Date
# Get List Items 
$spListItems =  Get-PnPListItem -List $spListName -PageSize 4000 -Query $spQuery 
$end1 = Get-Date
$totaltime = $end1 - $start
$deleted = 0
$count = 0
Write-Yellow "`nTiempo de Get-ListItem: $($totaltime.tostring("hh\:mm\:ss"))"
Write-host "Total Number of Items Found: "$spListItems.Count -ForegroundColor "Cyan"
if($spListItems.Count -eq 0 || $null -eq $spListItems) {
    Write-Host "No hay datos en la tabla: $spListName." -ForegroundColor "Red"
} else {
    # Opciones para la Sharepoint List
    $option = Read-Host "Que desea hacer con los items encontrados en la Lista '$spListName'? `n([D]Delete / [E]Export SQL / [F]Filter / [U]Update / [I]Import Fron Excel)"
    if($option -contains "D"){
        # Create a New Batch
        $Batch = New-PnPBatch
        # Delete All List Items
        ForEach($Item in $spListItems)
        {   
            Remove-PnPListItem -List $spListName -Identity $Item.ID -Batch $Batch
            $Item = $Item.ID
            $deleted++
            Write-Host "ID:$Item Deleting" -ForegroundColor "Blue"
        }  
        # Send Batch to the server
        Invoke-PnPBatch -Batch $Batch
        # Desconectar del sharepoint
        Disconnect-PnPOnline
        Write-Yellow "`nItems Deleted    = $deleted"
        Write-Host "Deleted from $spListName Sharepoint List" -ForegroundColor "Green"

        $end2 = Get-Date
        $totaltime = $end2 - $start
        Write-Yellow "`nTiempo de Total: $($totaltime.tostring("hh\:mm\:ss"))"
        

    } elseif ($option -contains "F") {
        $Filter = Read-Host "Ingrese la Columna a Filtrar"
        $FilterValue = Read-Host "Ingrese el valor a Filtrar"
        $FilteredItems  = $spListItems | Where-Object {$_[$Filter] -eq $FilterValue}
        
        ForEach($Item in $FilteredItems){
            
            $Item = $Item.FieldValues.Title
            Write-Host "`n$Item" -ForegroundColor "Green"
            $count++
        }
        Write-Host "`n$count" -ForegroundColor "DarkGreen"
        # Desconectar del sharepoint
        Disconnect-PnPOnline
    }
    elseif ($option -contains "U") {
        # Create a New Batch
        $spBatch = New-PnPBatch
        # Ingresar campo a actualizar
        $Filter = Read-Host "Ingrese la Columna a Actualizar(Update)"
        # Ingresar valor a actualizar
        $FilterValue = Read-Host "Ingrese el valor a Actualizar(Update)"
        # para cada item de la lista conseguida
        ForEach($Item in $spListItems){
            # Guarda el ID del la fila a actualizar
            $ItemID = [int]$Item.ID
            Write-Host "Actualizando ID N° $ItemID. $Filter = $FilterValue" -ForegroundColor "DarkGreen"
            # Agrega al Batch para actualizar en bloque
            Set-PnPListItem -List $spListName -Identity $ItemID -Values @{"$Filter"=$FilterValue} -Batch $spBatch
            $count++
        }
        # Realiza el HTTP POST para agregar o actualizar en bloque
        Invoke-PnPBatch $spBatch
        # Desconectar del sharepoint
        Disconnect-PnPOnline
        Write-Host "-----------------------------------------" -ForegroundColor "Red"
        Write-Host "Total de Registros Actualizados: $count" -ForegroundColor "Blue"
        
    }
    elseif ($option -contains "E") {   
        # Create a New Query
        $sqlQuery = "INSERT INTO $sqlTable `nVALUES`n"
        # Ruta del Archivo a guardar
        $fPath = "D:\Documentos\AppsSurgi\Scripts\PowerShellScripts\log\SQLqueryfromSP.sql"
        # para cada item de la lista conseguida
        ForEach($Item in $spListItems){
            # Genera su respectivo SQL query
            $sqlQuery +=   "( '" + $Item[$spFields[1]] + "', '" + $Item[$spFields[2]] + "'),`n"
            # Muestra al usuario los item que se estan grabando en el archivo
            Write-Host "`nActualizando ID N° " + $Item[$spFields[0]] -ForegroundColor "Green"
            # Realiza el conteo de los items guardados
            $count++
        }
        # Realiza la desconexion de Sharepoint Online
        Disconnect-PnPOnline
        # Guarda los Datos en la ruta asignada
        Set-Content -path $fPath -value $sqlQuery
        # Se Muestra conteo de Registros Actualizados
        Write-Host "`nTotal de Registros Actualizados: $count" -ForegroundColor "DarkGreen"
        # Se Muestra donde se guardó el archivo
        Write-Host "`nLos datos se encuentran en el Archivo: " + $fPath -ForegroundColor "DarkGreen"
    }
    elseif ($option -contains "I") {
        # Create a New Batch
        $spBatch = New-PnPBatch
        # Ruta del Archivo a guardar
        $fPath = "D:\Documentos\BBDD_Instrumentales.xlsx"
        # Abre excel
        $excel = New-Object -ComObject Excel.Application
        # Abre el archivo en fpath
        $workbook = $excel.Workbooks.Open($fPath)
        # Abre la primera página de trabajo
        $worksheet = $workbook.Sheets.Item(1)
        # para cada item del archivo de excel
        For($i=2; $i -le ($worksheet.UsedRange.Rows.Count); $i++){
            # Crea un nuevo objeto PowerShell
            $Value= New-Object PSObject
            # Obtiene la fila de Excel a trabajar
            $row1 = $WorkSheet.Columns.Item(1).Rows.Item($i).Text
            $row2 = $WorkSheet.Columns.Item(2).Rows.Item($i).Text
            $row3 = $WorkSheet.Columns.Item(3).Rows.Item($i).Text
            $row4 = $WorkSheet.Columns.Item(4).Rows.Item($i).Text
            $row5 = $WorkSheet.Columns.Item(5).Rows.Item($i).Text
            $row6 = $WorkSheet.Columns.Item(6).Rows.Item($i).Text
            # Crea un registro con los datos extraidos de Excel
            $Value | Add-Member -MemberType noteproperty -Name "Title" -Value $row1
            $Value | Add-Member -MemberType noteproperty -Name "MARCA" -Value $row2
            $Value | Add-Member -MemberType noteproperty -Name "MODELO" -Value $row3
            $Value | Add-Member -MemberType noteproperty -Name "EMPRESA" -Value $row4
            $Value | Add-Member -MemberType noteproperty -Name "FECHA_OPERATIVIDAD" -Value $row5
            $Value | Add-Member -MemberType noteproperty -Name "FRECUENCIA_MANTENIMIENTO" -Value $row6
            #$Value = @{"Title" = $row.Range("A$i").Text; 
             #           "MARCA" = $row.Range("B$i").Text;
               #         "MODELO" = $row.Range("C$i").Text;
                #        "EMPRESA" = $row.Range("D$i").Text;
                 #       "FECHA_OPERATIVIDAD" = $row.Range("E$i").Text;
                  #      "FRECUENCIA_MANTENIMIENTO" = $row.Range("F$i").Text }
            $Value
            # Agrega el registro al Batch de sharepoint
            Add-PnPListItem -List $spListName -Values $Value -Batch $spBatch
            # Muestra al usuario los item que se estan grabando en el archivo
            Write-Host "`nAgregando Fila N° $i" -ForegroundColor "Green"
            # Realiza el conteo de los items guardados
            $count++
        }
        # Cierra el archivo y el programa de excel
        $workbook.Close()
        $excel.Quit()
        # Realiza el HTTP POST para agregar o actualizar en bloque
        Invoke-PnPBatch $spBatch
        # Desconectar del sharepoint
        Disconnect-PnPOnline
        # Conteo de los registros Agregados
        Write-Host "`nTotal de Registros Agregados: $count" -ForegroundColor "DarkGreen"
    }
}
