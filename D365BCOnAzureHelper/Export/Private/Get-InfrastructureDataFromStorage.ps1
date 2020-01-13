function Global:Get-InfrastructureDataFromStorage {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
        maybe obsolete
    .DESCRIPTION
        ...
    #>
    param(
        [Parameter(Mandatory = $true)]
        $StorageAccountContext,
        [Parameter(Mandatory = $true)]
        [string]
        $TableNameInfrastructureData,
        [Parameter(Mandatory = $false)]
        [string]
        $TypeFilter
    )
    process {
        Write-Verbose "Loading infrastructure-data from Storage-table $TableNameInfrastructureData..."
        
        $storageAccountTable = Get-AzStorageTable -Name $TableNameInfrastructureData -Context $StorageAccountContext
        $cloudTable = $storageAccountTable.CloudTable        
        if (-not([string]::IsNullOrEmpty($TypeFilter))) {
            $row = Get-AzTableRow -Table $cloudTable | Where-Object { ($_.Type -eq $TypeFilter) }
            if (-not($row)) {
                $row = Get-AzTableRow -Table $cloudTable    
            }
        }
        else {
            $row = Get-AzTableRow -Table $cloudTable
        }

        $infrastructure = New-Object PSCustomObject        
        foreach ($property in $row | Get-Member -MemberType NoteProperty | Where-Object { $_.Name -ne "Etag" } | Select-Object -ExpandProperty Name) {
            $infrastructure | Add-Member -type NoteProperty -name $property -Value $row.$property
        }
        $infrastructure
    }
}