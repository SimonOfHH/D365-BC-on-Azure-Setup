function Global:Add-UserToServiceUserPassword {
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
            Write-Verbose "Creating user $($User.Username) (UserPassword)..."
            New-NAVServerUser -ServerInstance $Environment.ServerInstance -Tenant default -UserName $User.Username -FullName $User.Fullname -Password $User.Password
        }
        if ($user.PermissionSetId) {
            if (-not (Get-NAVServerUserPermissionSet -ServerInstance $Environment.ServerInstance -UserName $User.Username -PermissionSetId $User.PermissionSetId)) {
                Write-Verbose "Creating user permission $($User.Username)..."
                New-NAVServerUserPermissionSet -ServerInstance $Environment.ServerInstance -Tenant default -UserName $User.Username -PermissionSetId $User.PermissionSetId
            }
        }
    }
}