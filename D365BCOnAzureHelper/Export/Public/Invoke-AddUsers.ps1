function Invoke-AddUsers {
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
        $KeyVaultResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageTableNameEnvironments,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageTableNameEnvironmentDefaults,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageTableNameUsers,
        [Parameter(Mandatory = $true)]
        [string]
        $TypeFilter
    )
    process {
        Write-Verbose "Creating users..."
        Import-NecessaryModules -Type Application

        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $StorageAccountContext -TableNameEnvironments $StorageTableNameEnvironments -TableNameDefaults $StorageTableNameEnvironmentDefaults -TypeFilter $TypeFilter -ConfigType Application
        $users = Get-UsersDataFromStorage -StorageAccountContext $StorageAccountContext -TableNameUsersData $StorageTableNameUsers -TypeFilter $TypeFilter
        foreach ($environment in $environments) {
            if (Get-NavServerInstance -ServerInstance $environment.ServerInstance) {
                foreach ($user in $users) {
                    switch ($user.Authentication) {
                        'Windows' {
                            Add-UserToServiceWindowsAccount -Environment $environment -User $user
                        }
                        'UserPassword' {
                            Add-UserToServiceUserPassword -Environment $environment -User $user
                        }

                    }                    
                }
            }
        }
    }
}