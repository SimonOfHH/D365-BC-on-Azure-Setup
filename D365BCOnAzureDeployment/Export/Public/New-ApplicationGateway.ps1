function New-ApplicationGateway {
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
        $ApplicationGatewayName,
        [Parameter(Mandatory = $true)]
        [string]
        $VMScaleSetName,
        [Parameter(Mandatory = $false)]
        [string]
        $FrontEndIpConfigNamePrivate = "$($VMScaleSetName)FrontEnd-private",
        [Parameter(Mandatory = $false)]
        [string]
        $FrontEndIpConfigNamePublic = "$($VMScaleSetName)FrontEnd-public",
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
        [Parameter(Mandatory = $true)]
        [string]
        $SubnetAddressPrefix = "10.0.1.0/24",
        [Parameter(Mandatory = $true)]
        [string]
        $PrivateIpAddress,
        [Parameter(Mandatory = $false)]
        [ValidateSet('IPv4', 'IPv6')]
        [string]
        $PrivateIpAddressVersion = 'IPv4',
        [Parameter(Mandatory = $true)]
        [string]
        $PublicIpAddressName,
        [Parameter(Mandatory = $true)]
        [string]
        $PublicIpAddressSku = "Standard",
        [Parameter(Mandatory = $false)]
        [ValidateSet('Dynamic', 'Static')]
        [string]
        $PublicIpAddressAllocation = "Static",
        [Parameter(Mandatory = $false)]
        [string]
        $DomainNameLabel,
        [Parameter(Mandatory = $false)]
        [string]
        $ApplicationGatewaySkuName = "Standard_v2",
        [Parameter(Mandatory = $false)]
        [string]
        $ApplicationGatewaySkuTier = "Standard_v2",
        [Parameter(Mandatory = $false)]
        [int]
        $ApplicationGatewaySkuCapacity = 2,
        [Parameter(Mandatory = $false)]
        [bool]
        $UpdateScaleSet = $true,
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
        [Parameter(Mandatory = $false)]
        [string]
        $KeyVaultResourceGroup = $ResourceGroupName,
        [Parameter(Mandatory = $false)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $false)]
        [string]
        $CertificateName = "ApplicationGateway",
        [HashTable]
        $Tags
    )
    process {        
        if (Get-AzApplicationGateway -ResourceGroupName $ResourceGroupName -Name $ApplicationGatewayName -ErrorAction SilentlyContinue) {
            Write-Verbose "Application Gateway $ApplicationGatewayName already exists."
            return
        }

        # Get environments from Storage; needed to create correct HttpSettings and Probes for Webclients
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroup -Name $StorageAccountName
        $storageAccountContext = $storageAccount.Context
        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $storageAccountContext -TableNameEnvironments $TableNameEnvironments -TypeFilter $EnvironmentTypeFilter -EnvironmentsOnly -Verbose:$Verbose

        $params = @{
            ResourceGroupName      = $KeyVaultResourceGroup
            ResourceLocation       = $ResourceLocation
            ApplicationGatewayName = $ApplicationGatewayName
            KeyVaultName           = $KeyVaultName
            CertificateName        = $CertificateName
        }
        $SslSetup = Get-ApplicationGatewaySslSetupAndIdentity @params

        Write-Verbose "Setting up Application Gateway-configuration for $ApplicationGatewayName..."
        $params = @{
            VirtualNetworkResourceGroupName = $VirtualNetworkResourceGroupName
            VirtualNetworkName              = $VirtualNetworkName
            SubnetName                      = $SubnetName
            SubnetAddressPrefix             = $SubnetAddressPrefix
        }
        $NetworkSetup = New-ApplicationGatewayNetworkSetup @params -IncludeSsl:$SslSetup.HandleSSL -Verbose:$Verbose

        Write-Verbose "Adding BackendAddressPool..."
        $Pool = New-AzApplicationGatewayBackendAddressPool -Name $BackendPoolName

        $Probes = New-ApplicationGatewayProbeConfigs -Environments $environments -IncludeSsl:$SslSetup.HandleSSL -Verbose:$Verbose
        $HttpSettings = New-ApplicationGatewayHttpSettings  -Environments $environments -Probes $Probes -IncludeSsl:$SslSetup.HandleSSL

        # Create FrontendPorts
        $FrontEndPorts = New-ApplicationGatewayFrontendPorts -IncludeSsl:$SslSetup.HandleSSL -Verbose:$Verbose

        # Create FrontendIPConfigurations (incl. PublicIP if necessary)
        $params = @{
            ResourceGroupName           = $ResourceGroupName 
            ResourceLocation            = $ResourceLocation
            FrontEndIpConfigNamePrivate = $FrontEndIpConfigNamePrivate
            FrontEndIpConfigNamePublic  = $FrontEndIpConfigNamePublic
            PublicIpAddressName         = $PublicIpAddressName
            PublicIpAddressSku          = $PublicIpAddressSku
            PublicIpAddressAllocation   = $PublicIpAddressAllocation
            PrivateIpAddress            = $PrivateIpAddress
            PrivateIpAddressVersion     = $PrivateIpAddressVersion
            Subnet                      = $NetworkSetup.Subnet
        }
        $IpConfiguration = New-ApplicationGatewayIpConfigurations @params -Verbose:$Verbose

        # Create HttpListeners
        $params = @{
            IpConfiguration = $IpConfiguration
            FrontendPorts   = $FrontEndPorts            
        }
        if ($SslSetup.HandleSSL) {
            $params.Add("SslCertificate", $SslSetup.Certificate)
        }        
        $Listeners = New-ApplicationGatewayHttpListeners @params -IncludeSsl:$SslSetup.HandleSSL -Verbose:$Verbose

        # Create RoutingRules
        $Rules = New-ApplicationGatewayRoutingRules -HttpSettings $HttpSettings -Listeners $Listeners -BackendAddressPool $Pool -IncludeSsl:$SslSetup.HandleSSL

        # Create Sku
        $Sku = New-AzApplicationGatewaySku -Name $ApplicationGatewaySkuName -Tier $ApplicationGatewaySkuTier -Capacity $ApplicationGatewaySkuCapacity

        # Create Application Gateway
        $params = @{
            Name                          = $ApplicationGatewayName
            ResourceGroupName             = $ResourceGroupName
            Location                      = $ResourceLocation
            BackendAddressPools           = $Pool
            BackendHttpSettingsCollection = $HttpSettings.Collection
            FrontendIpConfigurations      = $IpConfiguration.Collection
            FrontendPorts                 = $FrontEndPorts.Collection
            Probes                        = $Probes.Collection
            GatewayIpConfigurations       = $NetworkSetup.GatewayIPConfiguration
            HttpListeners                 = $Listeners.Collection
            RequestRoutingRules           = $Rules.Collection
            Sku                           = $Sku
        }
        if ($SslSetup.Identity) {
            $params.Add("Identity", $SslSetup.Identity)
        }
        if ($SslSetup.Certificate) {
            $params.Add("SslCertificates", $SslSetup.Certificate)
        }
        if ($Rules.RedirectConfiguration) {
            $params.Add("RedirectConfigurations", $Rules.RedirectConfiguration)
        }
        Write-Verbose "Creating ApplicationGateway..."
        $appGateway = New-AzApplicationGateway @params
        Write-Verbose "Done."

        Set-TagsOnResource -ResourceGroupName $ResourceGroupName -ResourceName $ApplicationGatewayName -Tags $Tags

        # Setup association of gateway with Scale Set
        Set-ApplicationGatewayAssociationForScaleSet -ResourceGroupName $ResourceGroupName -ApplicationGatewayName $ApplicationGatewayName -BackendPoolName $BackendPoolName -ScaleSetName $VMScaleSetName
    }    
}