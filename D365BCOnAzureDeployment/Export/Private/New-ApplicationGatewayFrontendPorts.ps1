function Global:New-ApplicationGatewayFrontendPorts {
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
        [switch]
        $IncludeSsl
    )
    process {
        Write-Verbose "Adding Frontend-Configuration..."
        $FrontEndPorts = @{
            PrivateHttp = $null
            PublicHttp  = $null
            PublicHttps = $null
            Collection  = @()
        }
        $FrontEndPorts.PrivateHttp = New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Private8080"  -Port 8080
        $FrontEndPorts.PublicHttp = New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Public80"  -Port 80        
        $FrontEndPorts.Collection += ($FrontEndPorts.PrivateHttp,$FrontEndPorts.PublicHttp)
        if ($IncludeSsl) {
            $FrontEndPorts.PublicHttps = New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Public443"  -Port 443            
            $FrontEndPorts.Collection += ($FrontEndPorts.PublicHttps)
        }        
        $FrontEndPorts
    }
}