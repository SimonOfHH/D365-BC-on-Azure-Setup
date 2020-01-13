function Global:Set-StorageTableSetupDone {
    <#
	.SYNOPSIS
	...
	
	.EXAMPLE
	...
	#>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountName,        
        [Parameter(Mandatory = $true)]
        [string]
        $StorageTableNameSetup
    )
    process {
        Write-Verbose "Removing 'SetupNotDone'-entry from storage table $StorageTableNameSetup to indicate that the setup is done now"
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
        $storageAccountContext = $storageAccount.Context
        $storageAccountTable = Get-AzStorageTable -Name $StorageTableNameSetup -Context $storageAccountContext.Context
        $cloudTable = $storageAccountTable.CloudTable
        #$rows = Get-AzTableRow -Table $cloudTable | Where-Object { ($_.Command -eq 'SetupNotDone') }
        $row = Get-AzTableRow -Table $cloudTable | Where-Object { ($_.Command -eq 'SetupNotDone') } | Select-Object -First 1
        #foreach ($row in $rows) {
        if ($row){
            Remove-AzTableRow -Table $cloudTable -entity $row | Out-Null
            Write-Verbose "Entry removed"
        }
        #}
    }
}