function Global:Set-ApplicationGatewayAssociationForScaleSet {
    <#
	.SYNOPSIS
	...
	
	.EXAMPLE
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
        $ApplicationGatewayName,        
        [Parameter(Mandatory = $true)]
        [string]
        $BackendPoolName,
        [Parameter(Mandatory = $true)]
        [string]
        $ScaleSetName
    )
    process {
        Write-Verbose "Starting association of Application Gateway $ApplicationGatewayName to Scale Set $ScaleSetName Network Interface..."

        Write-Verbose "Getting Application Gateway $ApplicationGatewayName"
        $AppGateway = Get-AzApplicationGateway -ResourceGroupName $ResourceGroupName -Name $ApplicationGatewayName
        Write-Verbose "Getting Application Gateway Backend Pool $BackendPoolName"
        $BackendPool = Get-AzApplicationGatewayBackendAddressPool -ApplicationGateway $AppGateway -Name $BackendPoolName
        Write-Verbose "Getting Scale Set $ScaleSetName"
        $VMScaleSet = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $ScaleSetName
        
        $NetworkInterfaceConfig = $VMScaleSet.VirtualMachineProfile.NetworkProfile.NetworkInterfaceConfigurations[0]
        $Ipconfig = $VMScaleSet.VirtualMachineProfile.NetworkProfile.NetworkInterfaceConfigurations[0].IpConfigurations[0]
        if (-not($Ipconfig.ApplicationGatewayBackendAddressPools)) {
            # This is only a helper-variable; the Scale Set already has a NetworkInterface, but initially without LoadBalancerBackendAddressPools
            # Since it's not possible (or: I don't know how) to create the object for the generic collection manually, we use it as a helper for the first BackendPool
            $ipconfigBase = New-AzVmssIpConfig -Name $Ipconfig.Name -ApplicationGatewayBackendAddressPoolsId $BackendPool.Id
            # Assign created LoadBalancerBackendAddressPool to existing IpConfiguration
            $Ipconfig.ApplicationGatewayBackendAddressPools = $ipconfigBase.ApplicationGatewayBackendAddressPools
        }
        else {
            # Add BackendAddressPool to existing IpConfiguration
            $ipconfig.ApplicationGatewayBackendAddressPools.Add($BackendPool.Id);
        }

        # Remove the existing NetworkInterfaceConfiguration from the object (because we add basically the same, slightly extended Configuration again)
        Write-Verbose "Removing existing NetworkInterfaceConfiguration from Scale Set $ScaleSetName"
        $VMScaleSet = Remove-AzVmssNetworkInterfaceConfiguration -VirtualMachineScaleSet $VMScaleSet -Name $NetworkInterfaceConfig.Name
        # Add the updated configuration back to the Scale Set-object
        Write-Verbose "Adding NetworkInterfaceConfiguration from Scale Set $ScaleSetName"
        $VMScaleSet = Add-AzVmssNetworkInterfaceConfiguration -VirtualMachineScaleSet $VMScaleSet -IpConfiguration $ipConfig -Name $NetworkInterfaceConfig.Name -Primary $true -EnableAcceleratedNetworking
        
        # Update the Scale Set
        Write-Verbose "Scale Set needs to be stopped and started again so that all Instances can be updated and get the new IP Configuration."
        Write-Verbose "Stopping Scale Set $($VMScaleSet.Name)..."
        Stop-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSet.Name -Force | Out-Null
        Write-Verbose "Updating the Scale Set $($VMScaleSet.Name)"
        Update-AzVmss -ResourceGroupName $ResourceGroupName -VirtualMachineScaleSet $VMScaleSet -VMScaleSetName $VMScaleSet.Name | Out-Null
        foreach ($instance in Get-AzVmssVM -ResourceGroupName $resourceGroupName -VMScaleSetName $VMScaleSet.Name -ErrorAction SilentlyContinue) {    
            Update-AzVmssInstance -ResourceGroupName $resourceGroupName -VMScaleSetName $VMScaleSet.Name -InstanceId $instance.InstanceID | Out-Null
        }
        Write-Verbose "Starting Scale Set $($VMScaleSet.Name)..."
        Start-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSet.Name | Out-Null
    }
}