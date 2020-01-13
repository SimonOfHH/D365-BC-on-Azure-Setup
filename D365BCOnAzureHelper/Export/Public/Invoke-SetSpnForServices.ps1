function Invoke-SetSpnForServices {
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
        $TypeFilter,
        [string]
        $Parameter2,
        [pscustomobject]
        $InfrastructureData
    )
    process {
        Import-NecessaryModules -Type Application
        
        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $storageAccountContext -TableNameEnvironments $infrastructureData.EnvironmentsTable $infrastructureData.EnvironmentDefaultsTable -TypeFilter $TypeFilter -ConfigType Application -EnvironmentsOnly
        foreach ($environment in $environments) {
            if (Get-NavServerInstance -ServerInstance $environment.ServerInstance) {
                $params = @{
                    Environment                  = $environment
                    Hostname                     = $InfrastructureData.ApplicationServerLoadBalancerHostName
                    FullyQualifiedDomainName     = $InfrastructureData.DomainFqdn 
                    KeyVaultName                 = $KeyVaultName 
                    DomainControllerComputerName = $InfrastructureData.DomainControllerComputerName
                }
                Set-SpnForService @params
            }
        }
    }
}