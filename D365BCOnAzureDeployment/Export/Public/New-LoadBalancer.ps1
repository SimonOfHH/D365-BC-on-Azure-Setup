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
        [switch]
        $EnableAcceleratedNetworking,
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
                $publicIP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpAddressName -Location $ResourceLocation -DomainNameLabel $DomainNameLabel -AllocationMethod "Static" -Sku Standard -Tag $Tags
                if ($Tags) {
                    Set-TagsOnResource -ResourceGroupName $ResourceGroupName -ResourceName $PublicIpAddressName -Tags $Tags
                }
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
        if ($Tags) {
            $params.Add("Tag", $Tags)
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
            ResourceGroupName           = $ResourceGroupName
            LoadBalancerName            = $LoadBalancerName
            BackendPoolName             = $BackendPoolName
            ScaleSetName                = $VMScaleSetName
            EnableAcceleratedNetworking = $EnableAcceleratedNetworking
        }
        Set-LoadBalancerAssociationForScaleSet @params
    }    
}