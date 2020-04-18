function Global:Get-CommandsFromStorageTable {
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
        $TableName,
        [string]
        $ObjectName,
        [Parameter(Mandatory = $false)]
        [string]
        $TypeFilter
    )
    process {
        $setupTable = Get-AzStorageTable -Name $TableName -Context $StorageAccountContext
        $setupCloudTable = $setupTable.CloudTable
        $rows = Get-AzTableRow -Table $setupCloudTable | Where-Object { ($_.ObjectName -eq 'NULL') -or ($_.ObjectName -eq '') -or ($_.ObjectName -eq $ObjectName) } | Sort-Object -Property PartitionKey, RowKey
        if ($TypeFilter) {
            $rows = Get-AzTableRow -Table $setupCloudTable | Where-Object { (($_.ObjectName -eq 'NULL') -or ($_.ObjectName -eq '') -or ($_.ObjectName -eq $ObjectName)) -and ( ($_.TypeFilter -eq '') -or ($_.TypeFilter -eq $TypeFilter)) } | Sort-Object -Property PartitionKey, RowKey
        }
        $rows
    }
}