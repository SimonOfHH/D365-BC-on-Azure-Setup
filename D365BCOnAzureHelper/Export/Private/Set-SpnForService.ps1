function Global:Set-SpnForService {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(        
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Environment,
        [Parameter(Mandatory = $true)]
        [string]
        $Hostname,
        [Parameter(Mandatory = $true)]
        [Alias('FullyQualifiedDomainName')]
        [string]
        $Fqdn,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string]
        $DomainControllerComputerName
    )    
    Write-Verbose "Setting up SPNs for $($environment.ServerInstance)..."
    $svcCreds = Get-ServiceUserCredentialsObject -KeyVaultName $KeyVaultName -KVIdentifier $environment.KVCredentialIdentifier
    $username = $svcCreds.Username
    $adjoinCredentials = Get-ServiceUserCredentialsObject -KeyVaultName $KeyVaultName

    $callParams = @()
    $callParams += "DynamicsNAV/$($Hostname):$($environment.ManagementServicesPort)"
    $callParams += "DynamicsNAV/$($Hostname).$($Fqdn):$($environment.ManagementServicesPort)"
    $callParams += "DynamicsNAV/$($Hostname):$($environment.ClientServicesPort)"
    $callParams += "DynamicsNAV/$($Hostname).$($Fqdn):$($environment.ClientServicesPort)"
    $callParams += "http/$($Hostname):$($environment.SoapServicesPort)"
    $callParams += "http/$($Hostname).$($Fqdn):$($environment.SoapServicesPort)"
    $callParams += "http/$($Hostname):$($environment.OdataServicesPort)"
    $callParams += "http/$($Hostname).$($Fqdn):$($environment.OdataServicesPort)"
    $callParams += "HOST/$($Hostname)"
    $callParams += "HOST/$($Hostname).$($Fqdn)"

    $domainUserSession = New-PSSession -Credential $adjoinCredentials -ComputerName $DomainControllerComputerName    

    foreach ($params in $callParams){
        Write-Verbose "Setting SPN $($params)..."
        Invoke-Command -Session $domainUserSession -Script {
            param($spnParam,$spnUser)            
            $AllArgs = @('-S', $spnParam, $spnUser)            
            & 'setspn' $AllArgs
        } -ArgumentList $params, $userName
    }
    Remove-PSSession $domainUserSession
}