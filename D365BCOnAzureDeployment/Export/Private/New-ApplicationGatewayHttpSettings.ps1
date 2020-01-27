function Global:New-ApplicationGatewayHttpSettings {
    <#
	.SYNOPSIS
	...
	
	.EXAMPLE
	...
	
	.PARAMETER xxx
	...
	#>
    [CmdletBinding()]    
    param
    (
        [Parameter(Mandatory = $true)]
        $Environments,
        [Parameter(Mandatory = $true)]
        $Probes,
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeSsl
    )
    process {
        Write-Verbose "Adding HttpSettings..."
        $HttpSettings = @{
            General    = $null
            Webclients = @{ }
            Collection = @()
        }        
        $HttpSettings.General = New-AzApplicationGatewayBackendHttpSetting -Name "HttpGeneral_Port80" -Port 80 -Protocol "Http" -Probe $Probes.General -CookieBasedAffinity "Disabled" -WarningAction SilentlyContinue                
        $HttpSettings.Collection += $HttpSettings.General
        # TODO: Get-Environments, add Probes per Path (e.g. -Path "/BCDefault-Web")
        foreach ($environment in $Environments) {
            $ProbeWebclient = $Probes.Webclients[$environment.ServerInstance]
            $HttpSettingWebclient = New-AzApplicationGatewayBackendHttpSetting -Name "HttpWebclient_Port8080_$($environment.ServerInstance)"  -Port 8080 -Protocol "Http" -CookieBasedAffinity "Enabled" -AffinityCookieName "WebclientApplicationGatewayAffinity" -Probe $ProbeWebclient -WarningAction SilentlyContinue            
            $HttpSettings.Webclients.Add($environment.ServerInstance, $HttpSettingWebclient)
            $HttpSettings.Collection += $HttpSettingWebclient
        }
        $HttpSettings
    }
}
