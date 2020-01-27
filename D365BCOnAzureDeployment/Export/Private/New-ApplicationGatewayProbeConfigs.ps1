function Global:New-ApplicationGatewayProbeConfigs {
    <#
	.SYNOPSIS
	...
	
	.EXAMPLE
	...
	
	.PARAMETER Environments
    ...
    .PARAMETER IncludeSsl
    ...
	#>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $Environments,
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeSsl
    )
    process {
        Write-Verbose "Adding Probes..."
        $Probes = @{
            General    = $null
            Webclients = @{ }
            Collection = @()
        }
        $responsematch = New-AzApplicationGatewayProbeHealthResponseMatch -StatusCode "200-399"
        $Probes.General = New-AzApplicationGatewayProbeConfig -Name "IsServerAlive" -Protocol Http -HostName "127.0.0.1" -Path "/" -Interval 30 -Timeout 30 -UnhealthyThreshold 3 -Match $responsematch
        $Probes.Collection += $Probes.General
        $responsematchWebclient = New-AzApplicationGatewayProbeHealthResponseMatch -StatusCode "200-399", "401" # Include 401-status code, because Webclient will return "Unauthorized" when using Windows-authentication
        # TODO: Get-Environments, add Probes per Path (e.g. -Path "/BCDefault-Web")
        foreach ($environment in $Environments) {
            $ProbeWebclient = New-AzApplicationGatewayProbeConfig -Name "IsNavAlive_$($environment.ServerInstance)" -Protocol Http -HostName "127.0.0.1" -Path "/$($environment.ServerInstance)-Web" -Interval 30 -Timeout 30 -UnhealthyThreshold 3 -Match $responsematchWebclient             
            $Probes.Webclients.Add($environment.ServerInstance, $ProbeWebclient)
            $Probes.Collection += $ProbeWebclient
        }
        $Probes
    }
}