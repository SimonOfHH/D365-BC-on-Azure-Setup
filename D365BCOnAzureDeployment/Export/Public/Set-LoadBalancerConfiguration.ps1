function Set-LoadBalancerConfiguration {
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
        [Parameter(Mandatory = $false)]
        [string]
        $StorageAccountResourceGroup = $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $TableNameEnvironments,
        [Parameter(Mandatory = $true)]
        [string]
        $EnvironmentTypeFilter,
        [HashTable]
        $Tags
    )
    process {
        Write-Verbose "Configuring load balancer $LoadBalancerName..."
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroupName -Name $LoadBalancerName -ErrorAction Stop
        $frontEndConfig = Get-AzLoadBalancerFrontendIpConfig -LoadBalancer $loadBalancer
        $backendPool = Get-AzLoadBalancerBackendAddressPoolConfig -LoadBalancer $loadBalancer

        $storageAccount = Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroup -Name $StorageAccountName
        $storageAccountContext = $storageAccount.Context

        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $storageAccountContext -TableNameEnvironments $TableNameEnvironments -TableNameDefaults "" -TypeFilter $EnvironmentTypeFilter -EnvironmentsOnly
        $counter = 0
        $lbUpdated = $false
        Write-Verbose "Checking probes for $LoadBalancerName..."
        foreach ($environment in $environments) {
            $counter += 1
            foreach ($property in $environment.PSObject.Properties | Where-Object { $_.Name -like '*Port*' }) {
                $probeName = "$($property.Name)HP$counter"
                if (-not(Get-AzLoadBalancerProbeConfig -Name $probeName -LoadBalancer $loadBalancer -ErrorAction SilentlyContinue)) {
                    Write-Verbose "Adding probe $probeName..."
                    $loadBalancer | Add-AzLoadBalancerProbeConfig -Name $probeName -Protocol Tcp -Port $property.Value -IntervalInSeconds 15 -ProbeCount 2 | Out-Null                    
                    $loadBalancer | Set-AzLoadBalancerProbeConfig -Name $probeName -Protocol Tcp -Port $property.Value -IntervalInSeconds 15 -ProbeCount 2 | Out-Null
                    $lbUpdated = $true
                }
            }            
        }
        if ($lbUpdated) {
            Write-Verbose "Saving changes to $LoadBalancerName..."
            $loadBalancer = Set-AzLoadBalancer -LoadBalancer $loadBalancer
        }
        $lbUpdated = $false
        # Needs to be separated, otherwise Get-AzLoadBalancerProbeConfig will return an empty probe objects
        $counter = 0
        Write-Verbose "Checking rules for $LoadBalancerName..."
        foreach ($environment in $environments) {            
            $counter += 1
            foreach ($property in $environment.PSObject.Properties | Where-Object { $_.Name -like '*Port*' }) {
                $probeName = "$($property.Name)HP$counter"                
                $loadBalancingRuleName = "$($property.Name)Rule$counter"
                if (-not(Get-AzLoadBalancerRuleConfig -Name $loadBalancingRuleName -LoadBalancer $loadBalancer -ErrorAction SilentlyContinue)) {
                    $probe = Get-AzLoadBalancerProbeConfig -Name $probeName -LoadBalancer $loadBalancer
                    Write-Verbose "Adding rule $loadBalancingRuleName..."
                    $loadBalancer | Add-AzLoadBalancerRuleConfig -Name $loadBalancingRuleName -Protocol Tcp -FrontendIpConfiguration $frontEndConfig `
                        -BackendPort $property.Value -FrontendPort $property.Value `
                        -Probe $probe -BackendAddressPool $backendPool -LoadDistribution SourceIPProtocol | Out-Null
                        $lbUpdated = $true
                }
            }
        }
        if ($lbUpdated) {
            Write-Verbose "Saving changes to $LoadBalancerName..."
            $loadBalancer = Set-AzLoadBalancer -LoadBalancer $loadBalancer
        }
    }    
}