function New-LoadBalancer {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(        
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceLocation,        
        [Parameter(Mandatory = $true)]
        [string]
        $LoadBalancerName,
        [Parameter(Mandatory = $true)]
        [string]
        $VMScaleSetName,
        [Parameter(Mandatory = $false)]
        [string]
        $FrontEndIpConfigName = "$($VMScaleSetName)FrontEnd",
        [Parameter(Mandatory = $false)]
        [string]
        $BackendPoolName = "$($VMScaleSetName)BackEnd",
        [Parameter(Mandatory = $true)]
        [string]
        $VirtualNetworkName,
        [Parameter(Mandatory = $false)]
        [string]
        $VirtualNetworkResourceGroupName = $ResourceGroupName,        
        [Parameter(Mandatory = $true)]
        [string]
        $SubnetName,
        [Parameter(Mandatory = $false)]
        [string]
        $PrivateIpAddress,
        [Parameter(Mandatory = $false)]
        [ValidateSet('IPv4', 'IPv6')]
        [string]
        $PrivateIpAddressVersion = 'IPv4',
        [Parameter(Mandatory = $false)]
        [string]
        $PublicIpAddressName,
        [Parameter(Mandatory = $false)]
        [string]
        $DomainNameLabel,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Standard', 'Basic')]
        [string]
        $LoadBalancerSku = "Standard",
        [Parameter(Mandatory = $false)]
        [bool]
        $UpdateScaleSet = $true,
        [HashTable]
        $Tags
    )
    process {
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroupName -Name $LoadBalancerName -ErrorAction SilentlyContinue
        if ($loadBalancer) {
            Write-Verbose "Load Balancer $LoadBalancerName already exists."
            return
        }
        $VMScaleSet = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSetName

        Write-Verbose "Setting up LoadBalancer-configuration for $LoadBalancerName..."

        Write-Verbose "Getting VirtualNetwork $VirtualNetworkName..."
        $vnet = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VirtualNetworkResourceGroupName
        Write-Verbose "Getting SubnetConfiguration $SubnetName..."
        $subnet = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name $SubnetName
        if ($PublicIpAddressName) {
            Write-Verbose "Using PublicIP..."
            # Get or create PublicIP
            $publicIP = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpAddressName -ErrorAction SilentlyContinue
            if (-not($publicIP)) {
                Write-Verbose "Creating PublicIP..."
                $publicIP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpAddressName -Location $ResourceLocation -DomainNameLabel $DomainNameLabel -AllocationMethod "Static" -Sku Standard
            }     
            $frontEndArgs = @{
                Name            = "$FrontEndIpConfigName-public"
                PublicIpAddress = $publicIP
            }            
        }
        else {
            Write-Verbose "Using PrivateIP..."
            $frontEndArgs = @{
                Name                    = "$FrontEndIpConfigName-private"
                Subnet                  = $subnet
                PrivateIpAddressVersion = $PrivateIpAddressVersion
            }        
            if (-not([string]::IsNullOrEmpty($PrivateIpAddress))) {
                $frontEndArgs.Add("PrivateIpAddress", $PrivateIpAddress)
            }
        }
        $backendpool = New-AzLoadBalancerBackendAddressPoolConfig -Name $BackendPoolName

        Write-Verbose "Creating FrontEndConfiguration..."
        $frontendConfig = New-AzLoadBalancerFrontendIPConfig @frontEndArgs
        if ($PublicIpAddressName) {
            # This is the necessary configuration, so that the Scale set will be able to create outbound connections
            $probeName = "HttpProbe"
            $inboundRuleName = "InboundRule"
            $outboundRuleName = "OutboundRuleInternet"
            Write-Verbose "Creating Probe for PublicIP-access..."
            $probe = New-AzLoadBalancerProbeConfig -Name $probeName -Protocol "http" -Port 80 -IntervalInSeconds 15 -ProbeCount 2 -RequestPath /
            Write-Verbose "Creating InboundRule for PublicIP-access..."
            $inboundRule = New-AzLoadBalancerRuleConfig -Name $inboundRuleName -FrontendIPConfiguration $frontendConfig -BackendAddressPool $backendpool -Probe $probe -Protocol "Tcp" -FrontendPort 80 -BackendPort 80 -IdleTimeoutInMinutes 15 -EnableFloatingIP -LoadDistribution SourceIP -DisableOutboundSNAT
            Write-Verbose "Creating OutboundRule for PublicIP-access..."
            $outboundRule = New-AzLoadBalancerOutBoundRuleConfig -Name $outboundRuleName -FrontendIPConfiguration $frontendConfig -BackendAddressPool $backendpool -Protocol All -IdleTimeoutInMinutes 15 -AllocatedOutboundPort 10000
        }        

        Write-Verbose "Creating Load Balancer $LoadBalancerName..."
        $params = @{
            Name                    = $LoadBalancerName 
            Sku                     = $LoadBalancerSku
            ResourceGroupName       = $ResourceGroupName 
            Location                = $resourceLocation 
            FrontendIpConfiguration = $frontendConfig 
            BackendAddressPool      = $backendpool
        }
        if ($PublicIpAddressName) {
            $params.Add("Probe", $probe)
            $params.Add("LoadBalancingRule", $inboundrule)
            $params.Add("OutboundRule", $outboundrule)            
        }        
        $loadBalancer = New-AzLoadBalancer @params

        Set-TagsOnResource -ResourceGroupName $ResourceGroupName -ResourceName $LoadBalancerName -Tags $Tags

        # Add Scale Set to Backend
        $params = @{
            ResourceGroupName = $ResourceGroupName
            LoadBalancerName  = $LoadBalancerName
            BackendPoolName   = $BackendPoolName
            ScaleSetName      = $VMScaleSetName
        }
        Set-LoadBalancerAssociationForScaleSet @params

        return
        # Update instances
        Write-Verbose "Updating Scale Set $($VMScaleSet.Name)..."
        foreach ($instance in Get-AzVmssVM -ResourceGroupName $resourceGroupName -VMScaleSetName $VMScaleSet.Name -ErrorAction SilentlyContinue) {    
            Update-AzVmssInstance -ResourceGroupName $resourceGroupName -VMScaleSetName $VMScaleSet.Name -InstanceId $instance.InstanceID | Out-Null
        }

        <#
        ################################# TEST #################################
        $LBPrefix = "AppScaleSetLB-Public"
        #$inboundPublicIPName = "$LBPrefix-InboundPIP"
        $outboundPublicIPName = "$LBPrefix-OutboundPIP"
        #$frontEndInboundName = "$LBPrefix-FrontEndInbound"
        $frontEndOutboundName = "$LBPrefix-FrontEndOutbound"
        #$backEndInboundName = "$LBPrefix-BackEndInbound"
        $backEndOutboundName = "$LBPrefix-BackEndOutbound"
        $probeName = "HttpProbe"
        $inboundRuleName = "InboundRule"
        $outboundRuleName = "OutboundRuleInternet"
        #$pubIPin = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $inboundPublicIPName -AllocationMethod Static -Sku Standard -Location $resourceLocation
        $pubIPout = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $outboundPublicIPName -AllocationMethod Static -Sku Standard -Location $resourceLocation
        #$frontendIPin = New-AzLoadBalancerFrontendIPConfig -Name $frontEndInboundName -PublicIpAddress $pubIPin
        $frontendIPout = New-AzLoadBalancerFrontendIPConfig -Name $frontEndOutboundName -PublicIpAddress $pubIPout
        #$bepoolin = New-AzLoadBalancerBackendAddressPoolConfig -Name $backEndInboundName
        $bepoolout = New-AzLoadBalancerBackendAddressPoolConfig -Name $backEndOutboundName
        $probe = New-AzLoadBalancerProbeConfig -Name $probeName -Protocol "http" -Port 80 -IntervalInSeconds 15 -ProbeCount 2 -RequestPath /
        $inboundRule = New-AzLoadBalancerRuleConfig -Name $inboundRuleName -FrontendIPConfiguration $frontendIPout -BackendAddressPool $bepoolout -Probe $probe -Protocol "Tcp" -FrontendPort 80 -BackendPort 80 -IdleTimeoutInMinutes 15 -EnableFloatingIP -LoadDistribution SourceIP -DisableOutboundSNAT
        $outboundRule = New-AzLoadBalancerOutBoundRuleConfig -Name $outboundRuleName -FrontendIPConfiguration $frontendIPout -BackendAddressPool $bepoolout -Protocol All -IdleTimeoutInMinutes 15 -AllocatedOutboundPort 10000
        New-AzLoadBalancer -Name $LBPrefix -Sku Standard -ResourceGroupName $ResourceGroupName -Location $resourceLocation -FrontendIpConfiguration $frontendIPout -BackendAddressPool $bepoolout -Probe $probe -LoadBalancingRule $inboundrule -OutboundRule $outboundrule
        #>
        <#
        # Only update Scale Set, if it's for the Private-IP-Configuration, this saves around 5 minutes
        #if ($UpdateScaleSet) {
        Write-Verbose "Scale Set needs to be stopped to be able to update the IP Configuration."
        Write-Verbose "Stopping Scale Set..."
        Stop-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSet.Name -Force | Out-Null            
        #}
        
        Write-Verbose "Creating IPConfiguration..."
        $ipconfigName = "LBIPConfig"
        if ($PublicIpAddressName) {
            $ipconfigName = "LBIPConfig-public"
        }

        # IPConfig for Scale Set
        $ipConfig = New-AzVmssIpConfig `
            -Name $ipconfigName `
            -LoadBalancerBackendAddressPoolsId $loadBalancer.BackendAddressPools[0].Id `
            -SubnetId $vnet.Subnets[0].Id

        Write-Verbose "Adding IPConfiguration to Scale Set $($VMScaleSet.Name)..."
        if ($PublicIpAddressName) {
            $VMScaleSet = Add-AzVmssNetworkInterfaceConfiguration -VirtualMachineScaleSet $VMScaleSet -IpConfiguration $ipConfig -Name "LBIPConfigNic-public"
        }
        else {
            $VMScaleSet = Add-AzVmssNetworkInterfaceConfiguration -VirtualMachineScaleSet $VMScaleSet -IpConfiguration $ipConfig -Name "LBIPConfigNic-private"
        }

        Write-Verbose "Updating Scale Set $($VMScaleSet.Name)..."
        Update-AzVmss -ResourceGroupName $ResourceGroupName -VirtualMachineScaleSet $VMScaleSet -VMScaleSetName $VMScaleSet.Name | Out-Null        

        Write-Verbose "Starting Scale Set $($VMScaleSet.Name)..."
        Start-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSet.Name | Out-Null
        
        # We need to stop the Scale Set again, because the new Network-settings for the Load Balancer can not be applied before
        Write-Verbose "Scale Set needs to be stopped and started again so that all Instances can be updated and get the new IP Configuration."
        Write-Verbose "Stopping Scale Set..."
        Stop-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSet.Name -Force | Out-Null
             
        foreach ($instance in Get-AzVmssVM -ResourceGroupName $resourceGroupName -VMScaleSetName $VMScaleSet.Name -ErrorAction SilentlyContinue) {    
            Update-AzVmssInstance -ResourceGroupName $resourceGroupName -VMScaleSetName $VMScaleSet.Name -InstanceId $instance.InstanceID | Out-Null
        }
        Write-Verbose "Starting Scale Set $($VMScaleSet.Name)..."
        Start-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSet.Name | Out-Null
        #>
    }    
}