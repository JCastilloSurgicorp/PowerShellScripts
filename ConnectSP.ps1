
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
$spSite = "SurgiCorpApp"
$spListName = "GR_BUSQUEDA"
$spUrl = "https://$spEmpresa.sharepoint.com/sites/$spSite/"
$spClientId = "50e9c267-2992-4b87-9f5b-221430ec4a2f"
$spThumbPrint = "9BC8DC618818698BB996CF0183C155A8ECAF6B05"
#$spFields = "ID", "LIMA_PROVINCIA"
$spQuery = "<View>
                <Query>
                    <Where>
                        <And>
                            <Gt>
                                <FieldRef Name='ID'/>
                                <Value Type='Number'>55104</Value>
                            </Gt>
                            <Lt>
                                <FieldRef Name='ID'/>
                                <Value Type='Number'>916239</Value>
                            </Lt>
                        </And>
                    </Where>
                </Query>
            </View>"

#                       <And>
#                            <Gt>
#                               <FieldRef Name='ID'/>
#                               <Value Type='Number'>666</Value>
#                           </Gt>
#                           <Lt>
#                               <FieldRef Name='ID'/>
#                               <Value Type='Number'>672</Value>
#                           </Lt>
#                       </And>
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
    $option = Read-Host "Que desea hacer con los items encontrados en la Lista '$spListName'? `n([D]Delete / [C]Copy / [F]Filter / [U]Update)"
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
            Write-Host "`nActualizando ID N° $ItemID. $Filter = $FilterValue" -ForegroundColor "Green"
            # Agrega al Batch para actualizar en bloque
            Set-PnPListItem -List $spListName -Identity $ItemID -Values @{"$Filter"=$FilterValue} -Batch $spBatch
            $count++
        }
        # Realiza el HTTP POST para agregar o actualizar en bloque
        Invoke-PnPBatch $spBatch
        Write-Host "`nTotal de Registros Actualizados: $count" -ForegroundColor "DarkGreen"
    }
}