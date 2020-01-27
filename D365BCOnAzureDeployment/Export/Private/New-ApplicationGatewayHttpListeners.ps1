function Global:New-ApplicationGatewayHttpListeners {
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
        $IpConfiguration,
        [Parameter(Mandatory = $true)]
        $FrontendPorts,
        [Parameter(Mandatory = $false)]
        $SslCertificate,
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeSsl
    )
    process {
        Write-Verbose "Adding HttpListener..."
        $Listeners = @{
            PrivateHttp = $null
            PublicHttp  = $null
            PublicHttps = $null
            Collection  = @()
        }        
        $Listeners.PrivateHttp = New-AzApplicationGatewayHttpListener -Name "Listener_Private8080" -Protocol "Http" -FrontendIpConfiguration $IpConfiguration.Private -FrontendPort $FrontendPorts.PrivateHttp
        $Listeners.PublicHttp = New-AzApplicationGatewayHttpListener -Name "Listener_Public80" -Protocol "Http" -FrontendIpConfiguration $IpConfiguration.Public -FrontendPort $FrontendPorts.PublicHttp        
        $Listeners.Collection += ($Listeners.PrivateHttp, $Listeners.PublicHttp)
        if ($IncludeSsl) {
            $Listeners.PublicHttps = New-AzApplicationGatewayHttpListener -Name "Listener_Public443" -Protocol "Https" -FrontendIpConfiguration $IpConfiguration.Public -FrontendPort $FrontendPorts.PublicHttps -SslCertificate $SslCertificate
            $Listeners.Collection += $Listeners.PublicHttps
        }        
        $Listeners
    }
}
