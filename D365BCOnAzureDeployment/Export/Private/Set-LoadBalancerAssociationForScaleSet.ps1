function Global:Set-LoadBalancerAssociationForScaleSet {
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
        $LoadBalancerName,        
        [Parameter(Mandatory = $true)]
        [string]
        $BackendPoolName,
        [Parameter(Mandatory = $true)]
        [string]
        $ScaleSetName,
        [switch]
        $EnableAcceleratedNetworking
    )
    process {
        Write-Verbose "Starting association of Load Balancer $LoadBalancerName to Scale Set $ScaleSetName Network Interface..."

        Write-Verbose "Getting Load Balancer $LoadBalancerName"
        $LoadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroupName -Name $LoadBalancerName
        Write-Verbose "Getting Load Balancer Backend Pool $BackendPoolName"
        $BackendPool = Get-AzLoadBalancerBackendAddressPoolConfig -LoadBalancer $LoadBalancer -Name $BackendPoolName
        Write-Verbose "Getting Scale Set $ScaleSetName"
        $VMScaleSet = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $ScaleSetName
        
        $NetworkInterfaceConfig = $VMScaleSet.VirtualMachineProfile.NetworkProfile.NetworkInterfaceConfigurations[0]
        $Ipconfig = $VMScaleSet.VirtualMachineProfile.NetworkProfile.NetworkInterfaceConfigurations[0].IpConfigurations[0]
        if (-not($Ipconfig.LoadBalancerBackendAddressPools)) {
            # This is only a helper-variable; the Scale Set already has a NetworkInterface, but initially without LoadBalancerBackendAddressPools
            # Since it's not possible (or: I don't know how) to create the object for the generic collection manually, we use it as a helper for the first BackendPool
            $ipconfigBase = New-AzVmssIpConfig -Name $Ipconfig.Name -LoadBalancerBackendAddressPoolsId $BackendPool.Id
            # Assign created LoadBalancerBackendAddressPool to existing IpConfiguration
            $Ipconfig.LoadBalancerBackendAddressPools = $ipconfigBase.LoadBalancerBackendAddressPools
        }
        else {
            # Add BackendAddressPool to existing IpConfiguration
            $ipconfig.LoadBalancerBackendAddressPools.Add($BackendPool.Id);
        }

        # Remove the existing NetworkInterfaceConfiguration from the object (because we add basically the same, slightly extended Configuration again)
        Write-Verbose "Removing existing NetworkInterfaceConfiguration from Scale Set $ScaleSetName"
        $VMScaleSet = Remove-AzVmssNetworkInterfaceConfiguration -VirtualMachineScaleSet $VMScaleSet -Name $NetworkInterfaceConfig.Name
        # Add the updated configuration back to the Scale Set-object
        Write-Verbose "Adding NetworkInterfaceConfiguration from Scale Set $ScaleSetName"
        $VMScaleSet = Add-AzVmssNetworkInterfaceConfiguration -VirtualMachineScaleSet $VMScaleSet -IpConfiguration $ipConfig -Name $NetworkInterfaceConfig.Name -Primary $true -EnableAcceleratedNetworking:$EnableAcceleratedNetworking
        
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