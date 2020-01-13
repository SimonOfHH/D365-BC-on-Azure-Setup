function New-StorageTables {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Creates Storage Tables and imports default data
    .DESCRIPTION
        ...
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,        
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceLocation,
        [Parameter(Mandatory = $true)]
        $StorageAccountContext,
        [Parameter(Mandatory = $true)]
        [Object[]]
        $Tables,
        [switch]
        $AsJob
    )
    function Add-Entity() {
        [CmdletBinding()]
        param
        (
            $Table,
            [Hashtable] $KeyValuePairs
        )
        Write-Verbose "Adding entry to storage table"
        $properties = @{ }
        foreach ($key in $KeyValuePairs.Keys) {
            if (($key.ToString() -ne "PartitionKey") -and ($key.ToString() -ne "RowKey")) {
                $properties.Add($key, $KeyValuePairs[$key])
            }
        }

        $params = @{
            Table          = $table
            PartitionKey   = $KeyValuePairs.PartitionKey
            RowKey         = $KeyValuePairs.RowKey
            property       = $properties
            UpdateExisting = $true
        }
        Add-AzTableRow @params | Out-Null
        Write-Verbose "Entry added"
    }
    foreach ($table in $Tables) {
        if (-not(Get-AzStorageTable -Name $table.TableName -Context $storageAccountContext -ErrorAction SilentlyContinue)) {
            Write-Verbose "Creating Storage Account Table $($table.TableName)..."
            $storageAccountTable = New-AzStorageTable -Name $table.TableName -Context $StorageAccountContext
            foreach ($valueEntry in $table.Values) {
                Add-Entity -Table $storageAccountTable.CloudTable -KeyValuePairs $valueEntry | Out-Null
            }
        }
    }
}
