function Invoke-SetLoadBalancerDnsRecord {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(        
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [pscustomobject]
        $InfrastructureData
    )
    process {
        $params = @{
            Hostname                     = $InfrastructureData.ApplicationServerLoadBalancerHostName
            ZoneName                     = $InfrastructureData.DomainFqdn
            IpAddress                    = $InfrastructureData.ApplicationServerLoadBalancerIP
            KeyVaultName                 = $KeyVaultName 
            DomainControllerComputerName = $InfrastructureData.DomainControllerComputerName
        }
        Set-CustomDnsRecord @params -Verbose:$Verbose
    }
}