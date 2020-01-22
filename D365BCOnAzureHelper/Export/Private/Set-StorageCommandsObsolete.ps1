# Will be called in VM
function Global:Set-StorageCommandsObsolete {
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
        [string]
        $LogComputerName,
        [Parameter(Mandatory = $true)]
        [string]
        $LogObjectName
    )
    process {
        Write-Verbose "Updating execution log..."
        Write-Verbose "Setting logs obsolete for:"
        Write-Verbose "     ObjectName: $LogObjectName"
        Write-Verbose "     ComputerName: $LogComputerName"
        $logTable = Get-AzStorageTable -Name $LogTableName -Context $storageAccountContext
        $logCloudTable = $logTable.CloudTable        
        $rows = Get-AzTableRow -Table $logCloudTable | Where-Object {($_.LogComputerName -eq $LogComputerName) -and ($_.LogObjectName -eq $LogObjectName) -and ($_.LogObsoleteNewInstance -eq $false) -and ($_.LogGlobalExecuteOnce -eq $false)}
        foreach ($row in $rows){
            $row.LogObsoleteNewInstance = $true
            $row | Update-AzTableRow -Table $logCloudTable | Out-Null
            Write-Verbose "Entry updated"
        }        
    }
}