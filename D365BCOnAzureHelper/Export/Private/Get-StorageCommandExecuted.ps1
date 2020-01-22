# Will be called in VM
function Global:Get-StorageCommandExecutionLog {
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
        Write-Verbose "Loading execution log..."
        if ($CommandRow.GlobalExecuteOnce -eq $true){
            $ExecutedByName = "*"            
        }
        $logTable = Get-AzStorageTable -Name $LogTableName -Context $storageAccountContext.Context
        $logCloudTable = $logTable.CloudTable
        $row = Get-AzTableRow -Table $logCloudTable | Where-Object { ($_.LogPartitionKey -eq $CommandRow.PartitionKey) -and ($_.LogRowKey -eq $CommandRow.RowKey) -and ($_.LogCommand -eq $CommandRow.Command) -and ($_.LogObjectName -eq $CommandRow.ObjectName) -and ($_.LogComputerName -like $ExecutedByName) -and ($_.LogObsoleteNewInstance -eq $false) }
        $row        
    }
}