function Invoke-SetupDelegation {
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
        $StorageTableNameEnvironments,
        [Parameter(Mandatory = $true)]
        [string]
        $TypeFilter,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [pscustomobject]
        $InfrastructureData
    )
    process {
        # Get Domain-Admin-credentials (will be used to run the script on the Domain Controller)
        $adjoinCredentials = Get-ServiceUserCredentialsObject -KeyVaultName $KeyVaultName

        $delegationParams = @{            
            LoadBalancerHostname         = $InfrastructureData.ApplicationServerLoadBalancerHostName 
            ComputerNamePrefix           = $InfrastructureData.WebserverComputerNamePrefix
            ServiceUserCredentials       = ""
            DomainUserCredentials        = $adjoinCredentials
            DomainControllerComputerName = $InfrastructureData.DomainControllerComputerName
        }
        # Since the SPN is registered on the Service User, we'll use this array to only loop once through all SPNs per User
        $alreadyHandledServiceUsers = @() 

        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $StorageAccountContext -TableNameEnvironments $StorageTableNameEnvironments -TypeFilter $TypeFilter -ConfigType Application -EnvironmentsOnly
        foreach ($environment in $environments) {
            # Get Service User for specific service
            $params = @{KeyVaultName = $KeyVaultName }
            if (-not([string]::IsNullOrEmpty($environment.KVCredentialIdentifier))) {
                $params.Add("KVIdentifier", $environment.KVCredentialIdentifier)
            }
            $credentialsObject = Get-ServiceUserCredentialsObject @params

            if (-not($alreadyHandledServiceUsers.Contains($credentialsObject))) {
                $params = $delegationParams
                $params.ServiceUserCredentials = $credentialsObject
                Set-ConstrainedDelegation @params -Verbose:$Verbose
            }            
        }
    }
}