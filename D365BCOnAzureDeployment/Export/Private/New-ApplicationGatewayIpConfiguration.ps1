function Global:New-ApplicationGatewayIpConfigurations {
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
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceLocation,
        [Parameter(Mandatory = $true)]
        [string]
        $FrontEndIpConfigNamePrivate,
        [Parameter(Mandatory = $true)]
        [string]
        $FrontEndIpConfigNamePublic,
        [Parameter(Mandatory = $true)]
        [string]
        $PublicIpAddressName,
        [Parameter(Mandatory = $true)]
        [string]
        $PrivateIpAddress,
        [Parameter(Mandatory = $false)]
        [ValidateSet('IPv4', 'IPv6')]
        [string]
        $PrivateIpAddressVersion = 'IPv4',
        $Subnet
    )
    process {
        Write-Verbose "Adding FrontendIP-Configuration..."
        $Ipconfiguration = @{
            Private    = $null
            Public     = $null
            PIP        = $null
            Collection = @()
        }
        $Ipconfiguration.PIP = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpAddressName -ErrorAction SilentlyContinue
        if (-not($Ipconfiguration.PIP)) {
            Write-Verbose "Adding Public-IP..."
            $Ipconfiguration.PIP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpAddressName -location $ResourceLocation -AllocationMethod Static -Sku Standard
        }
        $Ipconfiguration.Private = New-AzApplicationGatewayFrontendIPConfig -Name $FrontEndIpConfigNamePrivate -Subnet $Subnet -PrivateIPAddress $PrivateIpAddress
        $Ipconfiguration.Public = New-AzApplicationGatewayFrontendIPConfig -Name $FrontEndIpConfigNamePublic -PublicIPAddress $Ipconfiguration.PIP
        $Ipconfiguration.Collection += ($Ipconfiguration.Private,$Ipconfiguration.Public)
        $Ipconfiguration
    }
}
