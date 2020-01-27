function Global:New-ApplicationGatewayRoutingRules {
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
        $HttpSettings,
        [Parameter(Mandatory = $true)]
        $Listeners,
        [Parameter(Mandatory = $true)]
        $BackendAddressPool,
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeSsl
    )
    process {
        Write-Verbose "Adding RoutingRules..."
        $Rules = @{
            Private               = $null
            Public                = $null
            PublicSsl             = $null
            RedirectConfiguration = $null
            Collection            = @()
        }
        $HttpSettingWebclientFirst = ($HttpSettings.Webclients.GetEnumerator() | Select-Object -First 1).Value
        $Rules.Private = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PrivatePort8080" -RuleType basic -BackendHttpSettings $HttpSettingWebclientFirst -HttpListener $Listeners.PrivateHttp -BackendAddressPool $BackendAddressPool
        $Rules.Collection += $Rules.Private
        if ($IncludeSsl) {
            $Rules.RedirectConfiguration = New-AzApplicationGatewayRedirectConfiguration -Name "PublicPort80to443" -RedirectType Permanent -TargetListener $Listeners.PublicHttps -IncludePath $true -IncludeQueryString $true            
            $Rules.Public = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PublicPort80to443" -RuleType basic -HttpListener $Listeners.PublicHttp -RedirectConfiguration $Rules.RedirectConfiguration
            $Rules.PublicSsl = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PublicPort443" -RuleType basic -BackendHttpSettings $HttpSettingWebclientFirst -HttpListener $Listeners.PublicHttps -BackendAddressPool $BackendAddressPool            
            $Rules.Collection += ($Rules.Public, $Rules.PublicSsl)
        }
        else {
            $Rules.Public = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PublicPort80" -RuleType basic -BackendHttpSettings $HttpSettingWebclientFirst -HttpListener $Listeners.PublicHttp -BackendAddressPool $BackendAddressPool            
            $Rules.Collection += $Rules.Public
        }
        $Rules
    }
}
