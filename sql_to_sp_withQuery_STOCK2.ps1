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
    $sqlTable = "STOCKS_INVENTARIO"
    $sqlcollumns = "id, STOCK, LOTE, FECHA_VIGENCIA_LOTE, TIPO_ALMACENAJE, DESCRIPCION_DEPOSITO, REGISTRO_SANITARIO, FECHA_VIGENCIA_REGSAN, dep_id_id, prod_id_id, sector_id_id, tipoAlm_id_id, tipoProd_id_id, CODIGO_QR, PRODUCTO"
    $sqlQuery = "SELECT * FROM (SELECT TOP 20 $sqlcollumns FROM SURGICORP_POWERAPPS.dbo.$sqlTable ORDER BY id DESC) AS G ORDER BY G.id"
    $sqlPrimaryKey = "id"
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
        $spSite = "AppStockInventarios"
        $spListName = "STOCK_INVENTARIO"
        $spUrl = "https://$spEmpresa.sharepoint.com/sites/$spSite/"
        $spClientId = "50e9c267-2992-4b87-9f5b-221430ec4a2f"
        $spThumbPrint = "9BC8DC618818698BB996CF0183C155A8ECAF6B05"
        $spFields = "ID", "STOCK", "LOTE", "TIPO_ALMACENAJE", "DESCRIPCION_DEPOSITO", "REGISTRO_SANITARIO", "DEPOSITO_ID", "PRODUCTO_ID", "SECTOR_ID", "TipoAlm_ID", "TipoProd_ID", "VIGENCIA_LOTE", "FECHA_VIGENCIA_REGSAN", "ID_SQL", "CODIGO_QR", "PRODUCTO"
        $spQuery = "<View>  
                        <Query>
                            <Where>
                                <Gt>
                                    <FieldRef Name='ID'/>
                                    <Value Type='Number'>0</Value>
                                </Gt>
                            </Where>
                        </Query>
                        <RowLimit>1</RowLimit>
                    </View>"
        
        # Connect to PnP Online Using ENTRA: 
        Connect-PnPOnline -Tenant appsurgicorp.onmicrosoft.com -ClientId $spClientId -Thumbprint $spThumbPrint -Url $spUrl
        # Get List Items 
        $start1 = Get-Date
        $spDestination =  Get-PnPListItem -List $spListName -Query $spQuery -PageSize 4000
        $end1 = Get-Date
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

        # STEP 3 - Add or update SPLIST items on destination by comparing primary keys
        foreach ($row in $sqlSourceHash) {
            # Agrega y reemplaza columna id por ID_SQL antes de comparar
            $row[$spFields[13]] = [int]$row[$sqlPrimaryKey]
            #$row.remove($sqlPrimaryKey)
            # Formatea columna STOCK antes de comparar
            $row["STOCK"] = [int]$row["STOCK"]
            # Agrega y reemplaza columna dep_id_id por DEPOSITO_ID antes de comparar
            $row[$spFields[6]] = [int]$row["dep_id_id"]
            $row.remove("dep_id_id")
            # Agrega y reemplaza columna prod_id_id por dep_id_id antes de comparar
            $row[$spFields[7]] = [int]$row["prod_id_id"]
            $row.remove("prod_id_id")
            # Agrega y reemplaza columna sector_id_id por dep_id_id antes de comparar
            $row[$spFields[8]] = [int]$row["sector_id_id"]
            $row.remove("sector_id_id")
            # Agrega y reemplaza columna tipoAlm_id_id por dep_id_id antes de comparar
            $row[$spFields[9]] = [int]$row["tipoAlm_id_id"]
            $row.remove("tipoAlm_id_id")
            # Agrega y reemplaza columna tipoProd_id_id por dep_id_id antes de comparar
            $row[$spFields[10]] = [int]$row["tipoProd_id_id"]
            $row.remove("tipoProd_id_id")
            # Agrega y reemplaza columna FECHA_VIGENCIA_LOTE por VIGENCIA_LOTE antes de comparar
            $row[$spFields[11]] = $row["FECHA_VIGENCIA_LOTE"]
            $row.remove("FECHA_VIGENCIA_LOTE")
            # Crea la primary key de SQL que se usará para comparar
            $pk = $row[$spFields[0]]
            # Compara las primary key de Sharepoint con las de SQL
            if ($spDestination.Count -lt $pk){
                $row.remove("id")
                # Insert row
                Add-PnPListItem -List $spListName -Values $row -Batch $spBatch
                $added++
                Write-Blue "Agregando: $sqlPrimaryKey = $pk"
            }
        }
        $afterCount = $beforeCount + $added
        # Realiza el HTTP POST para agregar o actualizar en bloque
        Invoke-PnPBatch $spBatch
        Disconnect-PnPOnline
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
