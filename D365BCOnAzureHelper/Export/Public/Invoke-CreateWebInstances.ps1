function Invoke-CreateWebInstances {
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
        Import-NecessaryModules -Type Web

        # Add Firewall-rule, if not existing
        if (-not(Get-NetFirewallRule -Name 'BCHttpsInbound' -ErrorAction SilentlyContinue)){
            Write-Verbose "Adding Firewall-Rule"
            New-NetFirewallRule -Name 'BCHttpsInbound' -DisplayName 'Business Central HTTP(S) Inbound' -Profile @('Domain', 'Public', 'Private') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @('80', '443', '8080')
        }
        if (-not(Get-NetFirewallRule -Name 'ApplicationGatewayHealthCheck' -ErrorAction SilentlyContinue)){
            Write-Verbose "Adding Firewall-Rule"
            New-NetFirewallRule -Name 'ApplicationGatewayHealthCheck' -DisplayName 'Application Gateway Health Check' -Profile @('Domain', 'Public', 'Private') -Direction Inbound -Action Allow -Protocol TCP -LocalPort @('65200-65535')
        }

        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $storageAccountContext -TableNameEnvironments $StorageTableNameEnvironments -TableNameDefaults $StorageTableNameEnvironmentDefaults -TypeFilter $TypeFilter -ConfigType Web
        foreach ($environment in $environments) {
            $serverInstanceName = "$($environment.ServerInstance)-Web"
            if (-not (Get-NAVWebServerInstance -WebServerInstance $serverInstanceName)) { 
                Write-Verbose "Creating instance: $serverInstanceName"
                $params = @{
                    WebServerInstance            = $serverInstanceName
                    Server                       = $InfrastructureData.ApplicationServerLoadBalancerHostName
                    ServerInstance               = $environment.ServerInstance
                    ClientServicesCredentialType = $environment.Authentication
                    ClientServicesPort           = $environment.ClientServicesPort
                }
                if (-not([string]::IsNullOrEmpty($infrastructureData.DnsIdentity))) {
                    $params.Add("DnsIdentity", $infrastructureData.DnsIdentity)
                }
                New-NAVWebServerInstance @params                            
                Write-Verbose "Updating navsettings.json..."
                $configFile = "C:\inetpub\wwwroot\$($serverInstanceName)\navsettings.json"
                $a = Get-Content $configFile -raw | ConvertFrom-Json        
                $a.NAVWebSettings.ManagementServicesPort = $environment.ManagementServicesPort
                $a | ConvertTo-Json -depth 32 | set-content $configFile

                Write-Verbose "Checking for existing binding for port $($environment.OdataServicesPort)..."
                if (-not(Get-WebBinding -Name "Default Web Site" -Protocol http -Port $environment.OdataServicesPort)){
                    Write-Verbose "Adding binding for port $($environment.OdataServicesPort)..."
                    New-WebBinding -Name "Default Web Site" -IPAddress "*" -Port $environment.OdataServicesPort -Protocol http
                }
                Write-Verbose "Checking for existing binding for port $($environment.SoapServicesPort)..."
                if (-not(Get-WebBinding -Name "Default Web Site" -Protocol http -Port $environment.SoapServicesPort)){
                    Write-Verbose "Adding binding for port $($environment.OdataServicesPort)..."
                    New-WebBinding -Name "Default Web Site" -IPAddress "*" -Port $environment.SoapServicesPort -Protocol http
                }    
            }
        }
        Set-RootIndexHtml -DestinationFile "C:\inetpub\wwwroot\index.html"
    }
}