function Global:Add-UserToServiceWindowsAccount {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]
        $Environment,
        [Parameter(Mandatory = $true)]
        [pscustomobject]
        $User
    )
    process {
        if (-not (Get-NAVServerUser -ServerInstance $Environment.ServerInstance | Where-Object { $_.UserName -like $User.Username })) {
            Write-Verbose "Creating user $($User.Username) (Windows-account)..."
            New-NAVServerUser -ServerInstance $Environment.ServerInstance -Tenant default -WindowsAccount $User.Username -FullName $User.Fullname
        }
        if ($user.PermissionSetId) {
            if (-not (Get-NAVServerUserPermissionSet -ServerInstance $Environment.ServerInstance -WindowsAccount $User.Username -PermissionSetId $User.PermissionSetId)) {
                Write-Verbose "Creating user permission for $($User.Username)..."
                New-NAVServerUserPermissionSet -ServerInstance $Environment.ServerInstance -Tenant default -WindowsAccount $User.Username -PermissionSetId $User.PermissionSetId
            }
        }
    }
}