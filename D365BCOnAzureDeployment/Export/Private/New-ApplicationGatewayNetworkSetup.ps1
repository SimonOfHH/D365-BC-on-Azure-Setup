function Global:New-ApplicationGatewayNetworkSetup {
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
        $VirtualNetworkResourceGroupName,
        [Parameter(Mandatory = $true)]
        $VirtualNetworkName,
        [Parameter(Mandatory = $true)]
        $SubnetName,
        [Parameter(Mandatory = $true)]
        $SubnetAddressPrefix,
        [Parameter(Mandatory = $false)]
        [switch]
        $IncludeSsl
    )
    process {
        $NetworkSetup = @{
            VirtualNetwork         = $null
            Subnet                 = $null
            GatewayIPConfiguration = $null
        }
        Write-Verbose "Getting VirtualNetwork $VirtualNetworkName..."
        $NetworkSetup.VirtualNetwork = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VirtualNetworkResourceGroupName
        Write-Verbose "Getting SubnetConfiguration $SubnetName..."
        $NetworkSetup.Subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $NetworkSetup.VirtualNetwork -ErrorAction SilentlyContinue
        if (-not($NetworkSetup.Subnet)) {
            Write-Verbose "Adding Subnet $SubnetName to Virtual Network $VirtualNetworkName"
            $NetworkSetup.VirtualNetwork = Add-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $NetworkSetup.VirtualNetwork -AddressPrefix $SubnetAddressPrefix -WarningAction SilentlyContinue
            $NetworkSetup.VirtualNetwork | Set-AzVirtualNetwork | Out-Null
            $NetworkSetup.VirtualNetwork = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VirtualNetworkResourceGroupName
            $NetworkSetup.Subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $NetworkSetup.VirtualNetwork
        }
        Write-Verbose "Adding IPConfiguration..."
        $NetworkSetup.GatewayIPConfiguration = New-AzApplicationGatewayIPConfiguration -Name "GatewayIpConfig01" -Subnet $NetworkSetup.Subnet
        $NetworkSetup
    }
}
