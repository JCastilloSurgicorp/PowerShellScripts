
# Valid Colors: Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, 
#               Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White
function Write-Yellow($message) {
    Write-Host $message -ForegroundColor "Yellow"
}
# SharePoint Site Data
$spEmpresa = "appsurgicorp"
$spSite = "SurgiCorpApp"
$spListName = "GUIAS_REMISION"
$spUrl = "https://$spEmpresa.sharepoint.com/sites/$spSite/"
$spClientId = "50e9c267-2992-4b87-9f5b-221430ec4a2f"
$spThumbPrint = "9BC8DC618818698BB996CF0183C155A8ECAF6B05"
$spQuery = "<View>
                <Query>
                    <Where>
                        <Gt>
                            <FieldRef Name='ID'/>
                            <Value Type='Number'>39560</Value>
                        </Gt>
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
    $option = Read-Host "Que desea hacer con los items encontrados en la Lista '$spListName'? `n([D]Delete / [C]Copy / [F]Filter)"
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
}