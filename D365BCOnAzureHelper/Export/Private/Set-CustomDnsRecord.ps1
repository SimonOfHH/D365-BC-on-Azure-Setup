function Global:Set-CustomDnsRecord {
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
        $HostnameParam,
        [Parameter(Mandatory = $true)]
        [Alias('ZoneName')]
        [string]
        $ZoneNameParam,
        [Parameter(Mandatory = $true)]
        [Alias('IpAddress')]
        [string]
        $IpAddressParam,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string]
        $DomainControllerComputerName
    )
    process {
        Write-Verbose "Setting up DNS record for $HostnameParam..."    
        $adjoinCredentials = Get-ServiceUserCredentialsObject -KeyVaultName $KeyVaultName
        $domainUserSession = New-PSSession -Credential $adjoinCredentials -ComputerName $DomainControllerComputerName    

        # Run Command on Domain Controller
        Invoke-Command -Session $domainUserSession -Script {
            [CmdletBinding()]
            param($ipAddress, $hostName, $zoneName)
            $VerbosePreference = 'Continue'      
            $dnsRecord = Get-DnsServerResourceRecord -ZoneName $zoneName -Name $hostName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($dnsRecord) {
                Write-Verbose "DNS Record already exists"
                if ($dnsRecord.RecordData.IPv4Address.IPAddressToString -ne $ipAddress) {
                    Write-Verbose "IP has changed. Removing Old record."
                    Remove-DnsServerResourceRecord -InputObject $dnsRecord -ZoneName $zoneName -Force
                }
            }
            $dnsRecord = Get-DnsServerResourceRecord -ZoneName $zoneName -Name $hostName -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not($dnsRecord)) {
                Write-Verbose "Adding DNS record"
                Add-DnsServerResourceRecordA -Name $hostName -IPv4Address $ipAddress -AllowUpdateAny -ZoneName $zoneName
            }
        } -ArgumentList $IpAddressParam, $HostnameParam, $ZoneNameParam -Verbose:$Verbose
        Remove-PSSession $domainUserSession
    }
}