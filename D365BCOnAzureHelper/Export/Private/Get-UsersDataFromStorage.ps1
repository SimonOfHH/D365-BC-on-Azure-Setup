function Global:Get-UsersDataFromStorage {
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
        $TableNameUsersData,
        [Parameter(Mandatory = $false)]
        [string]
        $TypeFilter
    )
    process {
        Write-Verbose "Loading Users-data from Storage-table $TableNameUsersData..."        
        $storageAccountTable = Get-AzStorageTable -Name $TableNameUsersData -Context $StorageAccountContext
        $cloudTable = $storageAccountTable.CloudTable        
        if (-not([string]::IsNullOrEmpty($TypeFilter))) {
            $rows = Get-AzTableRow -Table $cloudTable | Where-Object { ($_.Type -eq $TypeFilter) }
            if (-not($rows)) {
                $rows = Get-AzTableRow -Table $cloudTable    
            }
        }
        else {
            $rows = Get-AzTableRow -Table $cloudTable
        }
        $users = @()
        foreach ($row in $rows) {
            $user = [pscustomobject]@{
                Username        = $row.UserName
                Fullname        = $row.UserFullname
                Authentication  = $row.AuthenticationType
                Password        = $row.Password
                PermissionSetId = $row.PermissionSetId
            }
            $users += $user
        }
        $users
    }
}