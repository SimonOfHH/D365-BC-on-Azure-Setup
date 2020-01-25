# Will be called in VM
function Global:Set-StorageCommandExecuted {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [Parameter(Mandatory = $true)]
        $StorageAccountContext,
        [Parameter(Mandatory = $true)]
        [string]
        $LogTableName,
        [Parameter(Mandatory = $true)]
        $CommandRow,
        [Parameter(Mandatory = $true)]
        [string]
        $ExecutedByName
    )
    process {
        Write-Verbose "Updating execution log..."
        $logTable = Get-AzStorageTable -Name $LogTableName -Context $storageAccountContext
        $logCloudTable = $logTable.CloudTable
        $lastRow = Get-AzTableRow -Table $logCloudTable | Select-Object -Last 1

        $properties = @{ 
            PartitionKey           = 0
            RowKey                 = 0
            LogPartitionKey        = $CommandRow.PartitionKey
            LogRowKey              = $CommandRow.RowKey
            LogCommand             = $CommandRow.Command
            LogObjectName          = $CommandRow.ObjectName
            LogComputerName        = $ExecutedByName
            LogParameter1          = $CommandRow.Parameter1
            LogParameter2          = $CommandRow.Parameter2
            LogRestartNecessary    = $CommandRow.RestartNecessary
            LogGlobalExecuteOnce   = $CommandRow.GlobalExecuteOnce
            LogObsoleteNewInstance = $false
        }        
        if ($null -eq $properties.LogParameter1) {
            $properties.LogParameter1 = ""
        }
        if ($null -eq $properties.LogParameter2) {
            $properties.LogParameter2 = ""
        }        
        $params = @{
            Table          = $logCloudTable
            PartitionKey   = $lastRow.PartitionKey
            RowKey         = "{0:000}" -f (([int]$lastRow.RowKey) + 1)
            property       = $properties
            UpdateExisting = $true
        }
        Add-AzTableRow @params | Out-Null
        Write-Verbose "Entry added"
    }
}