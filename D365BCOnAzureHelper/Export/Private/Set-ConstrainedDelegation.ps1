function Global:Set-ConstrainedDelegation {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(                
        [Parameter(Mandatory = $true)]
        [Alias('HostName')]
        [string]
        $LoadBalancerHostname,
        [Parameter(Mandatory = $true)]
        [string]
        $ComputerNamePrefix,
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $ServiceUserCredentials,
        [Parameter(Mandatory = $true)]
        [PSCredential]
        $DomainUserCredentials,
        [Parameter(Mandatory = $true)]
        [string]
        $DomainControllerComputerName
    )
    process {
        Write-Verbose "Setting up constrained delegations..."

        $domainUserSession = New-PSSession -Credential $DomainUserCredentials -ComputerName $DomainControllerComputerName            
        
        $ServiceUsername = $ServiceUserCredentials.GetNetworkCredential().UserName

        # Run Command on Domain Controller
        Invoke-Command -Session $domainUserSession -Script {
            [CmdletBinding()]
            param($serviceUsername, $lbHostName, $computerNamePrefix)
            $VerbosePreference = 'Continue'
            $spns = @()
            # Get the User-object from the ActiveDirectory and include registered SPNs
            $user = Get-ADUser $serviceUsername -Properties servicePrincipalName
            # Add all registered SPNs to a String-array
            $user.servicePrincipalName | Where-Object { $_ -match $lbHostName } | ForEach-Object { $spns += $_.ToString() }
            $computerNamePrefix = "$($computerNamePrefix)*"
            foreach ($computer in Get-ADComputer -Filter { name -like $computerNamePrefix }) {
                Write-Verbose "Enabling delegation on: $($computer.Name)"
                # Get the Server-identity that should be enabled for constrained delegations
                $identity = Get-ADComputer -Identity $computer.Name
                # Enable the Identity for Delegation and assign the SPN-Array to the services that should be delegated
                Set-ADAccountControl -Identity $identity -TrustedToAuthForDelegation $true
                Set-ADComputer -Identity $computer.Name -Add @{'msDS-AllowedToDelegateTo' = @($spns) }
            }            
        } -ArgumentList $ServiceUsername, $LoadBalancerHostname, $ComputerNamePrefix -Verbose:$Verbose     
        Remove-PSSession $domainUserSession
    }
}