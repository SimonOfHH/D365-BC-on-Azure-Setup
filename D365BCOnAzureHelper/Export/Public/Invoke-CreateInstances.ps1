function Invoke-CreateInstances {
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
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageTableNameEnvironments,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageTableNameEnvironmentDefaults,
        [Parameter(Mandatory = $true)]
        [string]
        $TypeFilter
    )
    process {
        Import-NecessaryModules -Type Application

        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $StorageAccountContext -TableNameEnvironments $StorageTableNameEnvironments -TableNameDefaults $StorageTableNameEnvironmentDefaults -TypeFilter $TypeFilter -ConfigType Application
        foreach ($environment in $environments) {
            if (-not (Get-NavServerInstance -ServerInstance $environment.ServerInstance)) {
                Write-Verbose "Creating instance: $($environment.ServerInstance)"
                
                $output = New-NAVServerInstance $environment.ServerInstance `
                    -DatabaseServer $environment.DatabaseServer  `
                    -DatabaseInstance $environment.DatabaseInstance  `
                    -Databasename $environment.Databasename `
                    -ClientServicesPort $environment.ClientServicesPort   `
                    -ManagementServicesPort $environment.ManagementServicesPort `
                    -SOAPServicesPort $environment.SoapServicesPort   `
                    -ODataServicesPort $environment.OdataServicesPort -Verbose:$Verbose
                
                Write-Verbose "Changing port-configuration..."
                Set-NAVServerConfiguration -ServerInstance $environment.ServerInstance -KeyName DeveloperServicesPort -KeyValue $environment.DeveloperServicesPort -Verbose:$Verbose
                Write-Verbose "Updating authentication-method..."
                Set-NAVServerConfiguration -ServerInstance $environment.ServerInstance -KeyName ClientServicesCredentialType -KeyValue $environment.Authentication -Verbose:$Verbose

                Write-Verbose "Updating service-account..."
                $params = @{KeyVaultName = $KeyVaultName }
                if (-not([string]::IsNullOrEmpty($environment.KVCredentialIdentifier))) {
                    $params.Add("KVIdentifier", $environment.KVCredentialIdentifier)
                }
                $credentialsObject = Get-ServiceUserCredentialsObject @params -Verbose:$Verbose
                Set-NAVServerInstance -ServerInstance $environment.ServerInstance -ServiceAccount User -ServiceAccountCredential $credentialsObject -Verbose:$Verbose

                foreach ($key in $environment.Settings.Keys) {
                    if ((-not([string]::IsNullOrEmpty($key))) -and (-not([string]::IsNullOrEmpty($environment.Settings[$key])))) {
                        Set-NAVServerConfiguration -ServerInstance $environment.ServerInstance -KeyName $key -KeyValue $environment.Settings[$key] -Verbose:$Verbose
                    }
                }
                Write-Verbose "Restarting service"
                Restart-NAVServerInstance -ServerInstance $environment.ServerInstance
            }
        }
    }
}