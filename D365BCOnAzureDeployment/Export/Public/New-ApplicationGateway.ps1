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
        if (Get-AzApplicationGateway -ResourceGroupName $ResourceGroupName -Name $ApplicationGatewayName -ErrorAction SilentlyContinue) {
            Write-Verbose "Application Gateway $ApplicationGatewayName already exists."
            return
        }
        # Get environments from Storage; needed to create correct HttpSettings and Probes for Webclients
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
        $storageAccountContext = $storageAccount.Context
        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $storageAccountContext -TableNameEnvironments $TableNameEnvironments -TypeFilter $EnvironmentTypeFilter -EnvironmentsOnly

        Write-Verbose "Setting up Application Gateway-configuration for $ApplicationGatewayName..."
        Write-Verbose "Getting VirtualNetwork $VirtualNetworkName..."
        $VNet = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VirtualNetworkResourceGroupName
        Write-Verbose "Getting SubnetConfiguration $SubnetName..."
        $Subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $VNet -ErrorAction SilentlyContinue
        if (-not($Subnet)) {
            Write-Verbose "Adding Subnet $SubnetName to Virtual Network $VirtualNetworkName"
            $VNet = Add-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $VNet -AddressPrefix $SubnetAddressPrefix -WarningAction SilentlyContinue
            $VNet | Set-AzVirtualNetwork | Out-Null
            $VNet = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VirtualNetworkResourceGroupName
            $Subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $VNet
        }
        Write-Verbose "Adding IPConfiguration..."
        $GatewayIPconfig = New-AzApplicationGatewayIPConfiguration -Name "GatewayIpConfig01" -Subnet $Subnet
        Write-Verbose "Adding BackendAddressPool..."
        $Pool = New-AzApplicationGatewayBackendAddressPool -Name $BackendPoolName
        Write-Verbose "Adding HealthProbes and HttpSettings..."
        $Probes = @()
        $HttpSettings = @()
        $responsematch = New-AzApplicationGatewayProbeHealthResponseMatch -StatusCode "200-399"
        $ProbeGeneral = New-AzApplicationGatewayProbeConfig -Name "IsServerAlive" -Protocol Http -HostName "127.0.0.1" -Path "/" -Interval 30 -Timeout 30 -UnhealthyThreshold 3 -Match $responsematch # TODO: Check setting per Service
        $HttpSettingGeneral = New-AzApplicationGatewayBackendHttpSetting -Name "HttpGeneral_Port80"  -Port 80 -Protocol "Http" -Probe $ProbeGeneral -CookieBasedAffinity "Disabled"  -WarningAction SilentlyContinue
        $Probes += $ProbeGeneral
        $HttpSettings += $HttpSettingGeneral
        $HttpSettingWebclientFirst = $null
        # TODO: Get-Environments, add Probes per Path (e.g. -Path "/BCDefault-Web")        
        foreach ($environment in $environments) {
            $responsematch = New-AzApplicationGatewayProbeHealthResponseMatch -StatusCode "200-399", "401" # Include 401-status code, because Webclient will return "Unauthorized" when using Windows-authentication
            $ProbeWebclient = New-AzApplicationGatewayProbeConfig -Name "IsNavAlive_$($environment.ServerInstance)" -Protocol Http -HostName "127.0.0.1" -Path "/$($environment.ServerInstance)-Web" -Interval 30 -Timeout 30 -UnhealthyThreshold 3 -Match $responsematch 
            $HttpSettingWebclient = New-AzApplicationGatewayBackendHttpSetting -Name "HttpWebclient_Port8080_$($environment.ServerInstance)"  -Port 8080 -Protocol "Http" -CookieBasedAffinity "Enabled" -AffinityCookieName "WebclientApplicationGatewayAffinity" -Probe $ProbeWebclient -WarningAction SilentlyContinue
            $Probes += $ProbeWebclient
            $HttpSettings += $HttpSettingWebclient
            $HttpSettingWebclientFirst = $HttpSettingWebclient
        }
        Write-Verbose "Adding Frontend-Configuration..."
        $FrontEndPortPrivate = New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Private8080"  -Port 8080
        $FrontEndPortPublic = New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Public80"  -Port 80
        $PublicIP = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpAddressName -ErrorAction SilentlyContinue
        if (-not($PublicIP)) {
            Write-Verbose "Adding Public-IP..."
            $PublicIP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpAddressName -location $ResourceLocation -AllocationMethod Static -Sku Standard
        }
        $FrontEndPrivate = New-AzApplicationGatewayFrontendIPConfig -Name $FrontEndIpConfigNamePrivate -Subnet $Subnet -PrivateIPAddress $PrivateIpAddress
        $FrontEndPublic = New-AzApplicationGatewayFrontendIPConfig -Name $FrontEndIpConfigNamePublic -PublicIPAddress $PublicIP
        Write-Verbose "Adding HttpListener..."
        $ListenerPrivate = New-AzApplicationGatewayHttpListener -Name "Listener_Private8080" -Protocol "Http" -FrontendIpConfiguration $FrontEndPrivate -FrontendPort $FrontEndPortPrivate
        $ListenerPublic = New-AzApplicationGatewayHttpListener -Name "Listener_Public80" -Protocol "Http" -FrontendIpConfiguration $FrontEndPublic -FrontendPort $FrontEndPortPublic
        Write-Verbose "Adding RoutingRules..."
        $RulePrivate = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PrivatePort8080" -RuleType basic -BackendHttpSettings $HttpSettingWebclientFirst -HttpListener $ListenerPrivate -BackendAddressPool $Pool
        $RulePublic = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PublicPort80" -RuleType basic -BackendHttpSettings $HttpSettingWebclientFirst -HttpListener $ListenerPublic -BackendAddressPool $Pool

        $Sku = New-AzApplicationGatewaySku -Name $ApplicationGatewaySkuName -Tier $ApplicationGatewaySkuTier -Capacity $ApplicationGatewaySkuCapacity
        $params = @{
            Name                          = $ApplicationGatewayName
            ResourceGroupName             = $ResourceGroupName
            Location                      = $ResourceLocation
            BackendAddressPools           = $Pool
            BackendHttpSettingsCollection = $HttpSettings
            FrontendIpConfigurations      = ($FrontEndPublic, $FrontEndPrivate)
            FrontendPorts                 = ($FrontEndPortPrivate, $FrontEndPortPublic)
            Probes                        = $Probes
            GatewayIpConfigurations       = $GatewayIPconfig
            HttpListeners                 = ($ListenerPrivate, $ListenerPublic)
            RequestRoutingRules           = ($RulePrivate, $RulePublic)
            Sku                           = $Sku
        }
        Write-Verbose "Creating ApplicationGateway..."
        $appGateway = New-AzApplicationGateway @params

        Set-ApplicationGatewayAssociationForScaleSet -ResourceGroupName $ResourceGroupName -ApplicationGatewayName $ApplicationGatewayName -BackendPoolName $BackendPoolName -ScaleSetName $VMScaleSetName
    }    
}