<#
.SYNOPSIS
    Program Based on Jeff Jones's Turbo-SQL-to-SharePoint-List-Sync script: 
    Read source SQL table and synchronize into SharePoint Online (SPO) List destination.
.DESCRIPTION
    Turbo sync SQL table to SharePoint Online List.  Optimized for speed. Insert, Update, and Delete to match rows and columns.  Great for PowerPlatform, PowerApps, and PowerBI integration scenarios.  Simple PS1 to run from on-premise virtual machine Task Scheduler.  No need for Data Managment Gateway (DMG) or complex firewall rules.  Optimized with usage of primary key, index columns, [Compare-Object] cmdlet [System.Data.DataRow] type, hashtable, and PNP batch HTTP POST network traffic.  Includes transcript LOG for support. Connected SP via ENTRA_ID and filtered with Queries for both SQL and Sharepoint Conections.
        * Script will add rows to the SharePoint List that are not in the SharePoint List.  
        * Script will update rows in the SharePoint List that are different in the SQL table.
        * Script will not update rows in the SharePoint List that are the same in the SQL table.
.EXAMPLE
    C:\> .\sql_to_sp_withQuery_HP.ps1
.NOTES
    File Name:  sql_to_sp_withQuery_HP.ps1
    Version:    1.0
    Author:     Jeff Jones - Jairo Castillo
    Modified:   2024-04-26
.LINK
    Reference:  https://github.com/spjeff/Turbo-SQL-to-SharePoint-List-Sync
#>

# DotNet Assembly
using namespace System.Data
using namespace System.Collections.Generic
# Functions to coloring messages
function Write-Yellow($message) {
    Write-Host $message -ForegroundColor "Yellow"
}
function Write-Green($message) {
    Write-Host $message -ForegroundColor "Green"
}
function Write-Blue($message) {
    Write-Host $message -ForegroundColor "Blue"
}
function Write-Red($message) {
    Write-Host $message -ForegroundColor "Red"
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
# Main application
function Main() {
    
    # STEP 1 - Connect SQL
    # Datos del Servidor
    $sqlServer = "SVRSURGI\SVRBIOPRO"
    $sqlDatabase = "SURGICORP_POWERAPPS"
    # Datos del Usuario
    $sqlUser = "powerapps"
    $sqlPass = "*Surgi007"
    # Datos del QUERY
    $sqlTable = "DOCGUI_PWRAPP"
    $sqlcollumns = "ID,EMPRESA,NRO_ITEM,NUMERO_GUIA,OC_CLIENTE,ESTADO,PRODUCTO,DESCRIPCION_PRODUCTO,CANTIDAD,LOTE,NOMBRE_CLIENTE,NRO_PROCESO,FECHA_GUIA"
    $sqlQuery = "SELECT $sqlcollumns FROM SURGICORP_POWERAPPS.dbo.$sqlTable WHERE not(OC_CLIENTE='') and FECHA_GUIA >= DATEADD(DAY,-1,CURRENT_TIMESTAMP)"
    #not(OC_CLIENTE='' or OC_CLIENTE is null) and FECHA_GUIA >= Cast(CURRENT_TIMESTAMP as date)
    $sqlPrimaryKey = "ID"
    # Iniciando Conexión
    $Conection = New-Object SqlClient.SqlConnection
    $Conection.ConnectionString = "Server=$sqlServer;Database=$sqlDatabase;user=$sqlUser;password=$sqlPass"
    $Conection.Open()
    # Aplicando Comandos QUERY
    $command = New-Object SqlClient.SqlCommand
    $command.Connection = $Conection
    $command.CommandText = $sqlQuery
    # Adaptador (Conseguimos los datos del SQL y lo guardamos en una tabla)
    $Adapter = New-Object SqlClient.SqlDataAdapter $command
    $sqlSource = New-Object DataSet
    $Adapter.fill($sqlSource)
    # Cerrar Conexión con SQL
    $Conection.Close()
    # Revisamos si la tabla que obtuvimos del SQL está vacía antes de continuar
    if($sqlSource.Count -eq 0 || $null -eq $sqlSource) {
        Write-Red "No hay datos en la tabla $sqlTable."
        Write-Green "`nTerminando conexión..."
    } else {
        # Convert SQL format to hashtable format
        $sqlSourceHash = $sqlSource.tables[0] | ConvertFrom-DataRow 
        # STEP 2 - Connect SPO
        # Datos del SharePoint
        $spEmpresa = "appsurgicorp"
        $spSite = "AppOrdenesdeCompra-Dev"
        $spListName = "NROGUIAS_2"
        $spUrl = "https://$spEmpresa.sharepoint.com/sites/$spSite/"
        $spClientId = "50e9c267-2992-4b87-9f5b-221430ec4a2f"
        $spThumbPrint = "9BC8DC618818698BB996CF0183C155A8ECAF6B05"
        $spFields = "id0","EMPRESA","NRO_ITEM","NUMERO_GUIA","OC_CLIENTE","ESTADO","PRODUCTO","DESCRIPCION_PRODUCTO","CANTIDAD", "LOTE", "ENTIDAD","N_PROCESO","FECHA_GUIA"
        $spQuery = "<View>  
                        <Query>
                            <Where>
                                <Gt>
                                    <FieldRef Name='FECHA_GUIA'/>
                                    <Value Type='DateTime'>
                                        <Today OffsetDays='-1'/>
                                    </Value>
                                </Gt>
                            </Where>
                        </Query>
                    </View>"
        
        # Connect to PnP Online Using ENTRA: 
        Connect-PnPOnline -Tenant appsurgicorp.onmicrosoft.com -ClientId $spClientId -Thumbprint $spThumbPrint -Url $spUrl
        # Get List Items 
        $start1 = Get-Date
        $spDestination =  Get-PnPListItem -List $spListName -PageSize 4000 -Query $spQuery
        $end1 = Get-Date
        $spDestination
        $totaltime1 = $end1 - $start1
        Write-Yellow "`nTiempo de Get-ListItem: $($totaltime1.tostring("hh\:mm\:ss"))`n"
        # Measure changes to SPLIST
        $added = 0
        $updated = 0
        # Measure SPLIST rows before and after
        $beforeCount = $spDestination.Count
        $afterCount = $sqlSourceHash.Count
        # Inicializar Variables antes de ingresar al foreach
        $spBatch = New-PnPBatch
        $spMatchItem = $null

        # STEP 3 - Add or update SPLIST items on destination by comparing primary keys
        foreach ($row in $sqlSourceHash) {
            # Agrega y reemplaza columna ID por Id0 antes de comparar
            $row[$spFields[0]] = [int]$row[$sqlPrimaryKey]
            $row.remove($sqlPrimaryKey)
            # Da formato de Número a NRO_ITEM
            $row["NRO_ITEM"] = [int]$row["NRO_ITEM"]
            # Da formato de Número a CANTIDAD
            $row["CANTIDAD"] = [int]$row["CANTIDAD"]
            # Agrega y reemplaza columna NOMBRE_CLIENTE por ENTIDAD antes de comparar
            $row[$spFields[10]] = $row["NOMBRE_CLIENTE"]
            $row.remove("NOMBRE_CLIENTE")
            # Agrega y reemplaza columna NRO_PROCESO por N_PROCESO antes de comparar
            $row[$spFields[11]] = $row["NRO_PROCESO"]
            $row.remove("NRO_PROCESO")
            # Crea la primary key de SQL que se usará para comparar
            $pk = $row[$spFields[0]]
            # Compara las primary key de Sharepoint con las de SQL
            $spMatchItem = $spDestination | Where-Object { $_[$spFields[0]] -eq $pk }
            # First matched SPLIST row only
            if ($spMatchItem -is [System.Array]) {
                $spMatchItem = $spMatchItem[0]
            }
            # If row does not exist, add it
            if (!$spMatchItem) {
                # Insert row
                Add-PnPListItem -List $spListName -Values $row -Batch $spBatch
                $added++
                Write-Blue "Agregando: $sqlPrimaryKey = $pk"
            }
            else {
                # If row does exist, update it
                # Crea el hash de Sharepoint y formatea el Id0 para comparar los Hash
                $hashsp = ([Hashtable]$spMatchItem.FieldValues) | Select-Object ($spFields | Select-Object -First 12)
                $hashsp."id0" = [int]$hashsp."id0"
                $hashsp."NRO_ITEM" = [int]$hashsp."NRO_ITEM"
                $hashsp."CANTIDAD" = [int]$hashsp."CANTIDAD"
                if ($null -eq $hashsp."N_PROCESO" ) {
                    $hashsp."N_PROCESO" = ""
                }
                # Crea el hash de SQL para comparar
                $hash = ($row | Select-Object ($spFields | Select-Object -First 12))
                # Compara los hash para verificar si se necesita actualizar
                $needUpdate = (ConvertTo-Json $hash) -ne (ConvertTo-Json $hashsp)
                # Si necesita actualizar, realiza la actualización
                if ($needUpdate) {
                    # Agrega al Batch para actualizar en bloque
                    Set-PnPListItem -List $spListName -Identity $spMatchItem.ID -Values $row -Batch $spBatch
                    Write-Blue "Actualizando: $pk"
                    $updated++
                    $needUpdate = $false
                } 
            }
        }
        $afterCount = $beforeCount + $added
        # Realiza el HTTP POST para agregar o actualizar en bloque
        Invoke-PnPBatch $spBatch
        # Display results with SQL and SPLIST row counts
        Write-Yellow "Filas de Sharepoint Inicial    = $($beforeCount)"
        Write-Yellow "Filas de Sharepoint Final      = $($afterCount)"
        Write-Red "----------------------------------------"
        Write-Green  "Agregados                      = $added"
        Write-Green  "Actualizados                   = $updated"
    }
}

# Open LOG with script name
$prefix = $MyInvocation.MyCommand.Name
$host.UI.RawUI.WindowTitle = $prefix
$stamp = Get-Date -UFormat "%Y-%m-%d-%H-%M-%S"
Write-Yellow "`n"
Start-Transcript "$PSScriptRoot\log\$prefix-$stamp.log"
$start = Get-Date
# Inicia aplicación Principal
Main
# Close LOG and display time elapsed
$end = Get-Date
$totaltime = $end - $start
Write-Yellow "`nTiempo de la operación: $($totaltime.tostring("hh\:mm\:ss"))`n"
Stop-Transcript
Write-Yellow "`n"
