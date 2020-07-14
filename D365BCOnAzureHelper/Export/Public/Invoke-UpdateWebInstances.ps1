function Invoke-UpdateWebInstances {
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
        $InfrastructureData,
        [Parameter(Mandatory = $true)]
        [string]
        $TypeFilter,
        [string]
        $Parameter2
    )
    process {
        Write-Verbose "Updating Web Client Configuration..."
        Import-NecessaryModules -Type Web

        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $storageAccountContext -TableNameEnvironments $StorageTableNameEnvironments -TableNameDefaults $StorageTableNameEnvironmentDefaults -TypeFilter $TypeFilter -ConfigType Web
        foreach ($environment in $environments) {
            $serverInstanceName = "$($environment.ServerInstance)-Web"
            if (Get-NAVWebServerInstance -WebServerInstance $serverInstanceName) { 
                Set-NAVWebServerInstanceConfiguration -WebServerInstance $serverInstanceName -KeyName Server -KeyValue $InfrastructureData.ApplicationServerLoadBalancerHostName
                Set-NAVWebServerInstanceConfiguration -WebServerInstance $serverInstanceName -KeyName ServerInstance -KeyValue $environment.ServerInstance
                Set-NAVWebServerInstanceConfiguration -WebServerInstance $serverInstanceName -KeyName ClientServicesCredentialType -KeyValue $environment.Authentication
                Set-NAVWebServerInstanceConfiguration -WebServerInstance $serverInstanceName -KeyName ClientServicesPort -KeyValue $environment.ClientServicesPort                
                foreach ($key in $environment.Settings.Keys) {
                    Set-NAVWebServerInstanceConfiguration -WebServerInstance $serverInstanceName -KeyName $key -KeyValue $environment.Settings[$key]
                }
            }
        }
        Write-Verbose "Restarting Web Client..."
        Stop-WebSite 'Microsoft Dynamics 365 Business Central Web Client'
        Start-WebSite 'Microsoft Dynamics 365 Business Central Web Client'
    }
}