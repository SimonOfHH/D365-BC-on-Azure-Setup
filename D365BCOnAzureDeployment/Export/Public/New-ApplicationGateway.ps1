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
        [Parameter(Mandatory = $false)]
        [string]
        $KeyVaultName,
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
        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $storageAccountContext -TableNameEnvironments $TableNameEnvironments -TypeFilter $EnvironmentTypeFilter -EnvironmentsOnly -Verbose:$Verbose

        $handleSslSetup = $false
        if ($KeyVaultName) {
            $certificate = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name "ApplicationGateway" -ErrorAction SilentlyContinue
            if ($certificate) {
                $handleSslSetup = $true
            }
        }
        if ($handleSslSetup) {
            Write-Verbose "Retrieving certificate from KeyVault"
            $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "ApplicationGateway"
            $secretId = $secret.Id.Replace($secret.Version, "") # https://<keyvaultname>.vault.azure.net/secrets/
            $sslCertificate = New-AzApplicationGatewaySslCertificate -Name "$ApplicationGatewayName-certificate01" -KeyVaultSecretId $secretId

            # Identity is needed, to be able to read from KeyVault
            Write-Verbose "Generating identity for Application Gateway, to be able to read from KeyVault"
            $Identity = Get-AzUserAssignedIdentity -Name "$ApplicationGatewayName-Identity01" -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            if (-not($Identity)){
                $Identity = New-AzUserAssignedIdentity -Name "$ApplicationGatewayName-Identity01" -ResourceGroupName $ResourceGroupName -Location $ResourceLocation
            }
            Wait-ForNewlyCreatedIdentity -ResourceGroupName $ResourceGroupName -ObjectId $Identity.PrincipalId  -Verbose:$Verbose

            $AppgwIdentity = New-AzApplicationGatewayIdentity -UserAssignedIdentity $Identity.Id
            Write-Verbose "Updating KeyVault-access policy for new identity"
            Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -ObjectId $Identity.PrincipalId -PermissionsToKeys get -PermissionsToSecrets get -PermissionsToCertificates get 
        }        

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
        $FrontEndPorts = @()
        $FrontEndPortPrivate = New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Private8080"  -Port 8080
        $FrontEndPortPublic = New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Public80"  -Port 80
        $FrontEndPorts += $FrontEndPortPrivate
        $FrontEndPorts += $FrontEndPortPublic
        if ($true -eq $handleSslSetup) {
            $FrontEndPortPublicSsl = New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Public443"  -Port 443
            $FrontEndPorts += $FrontEndPortPublicSsl
        }
        $PublicIP = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpAddressName -ErrorAction SilentlyContinue
        if (-not($PublicIP)) {
            Write-Verbose "Adding Public-IP..."
            $PublicIP = New-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $PublicIpAddressName -location $ResourceLocation -AllocationMethod Static -Sku Standard
        }
        $FrontEndPrivate = New-AzApplicationGatewayFrontendIPConfig -Name $FrontEndIpConfigNamePrivate -Subnet $Subnet -PrivateIPAddress $PrivateIpAddress
        $FrontEndPublic = New-AzApplicationGatewayFrontendIPConfig -Name $FrontEndIpConfigNamePublic -PublicIPAddress $PublicIP
        Write-Verbose "Adding HttpListener..."        
        $Listeners = @()
        $ListenerPrivate = New-AzApplicationGatewayHttpListener -Name "Listener_Private8080" -Protocol "Http" -FrontendIpConfiguration $FrontEndPrivate -FrontendPort $FrontEndPortPrivate
        $ListenerPublic = New-AzApplicationGatewayHttpListener -Name "Listener_Public80" -Protocol "Http" -FrontendIpConfiguration $FrontEndPublic -FrontendPort $FrontEndPortPublic
        $Listeners += $ListenerPrivate
        $Listeners += $ListenerPublic
        if ($true -eq $handleSslSetup) {
            $ListenerPublicSsl = New-AzApplicationGatewayHttpListener -Name "Listener_Public443" -Protocol "Https" -FrontendIpConfiguration $FrontEndPublic -FrontendPort $FrontEndPortPublicSsl -SslCertificate $sslCertificate
            $Listeners += $ListenerPublicSsl
        }        
        Write-Verbose "Adding RoutingRules..."
        $Rules = @()
        $RulePrivate = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PrivatePort8080" -RuleType basic -BackendHttpSettings $HttpSettingWebclientFirst -HttpListener $ListenerPrivate -BackendAddressPool $Pool
        if ($true -eq $handleSslSetup) {            
            $sslRedirectConfig = New-AzApplicationGatewayRedirectConfiguration -Name "PublicPort80to443" -RedirectType Permanent -TargetListener $ListenerPublicSsl -IncludePath $true -IncludeQueryString $true            
            $RulePublic = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PublicPort80to443" -RuleType basic -HttpListener $ListenerPublic -RedirectConfiguration $sslRedirectConfig
            $RulePublicSsl = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PublicPort443" -RuleType basic -BackendHttpSettings $HttpSettingWebclientFirst -HttpListener $ListenerPublicSsl -BackendAddressPool $Pool
            $Rules += $RulePublicSsl
        }
        else {
            $RulePrivate = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PrivatePort8080" -RuleType basic -BackendHttpSettings $HttpSettingWebclientFirst -HttpListener $ListenerPrivate -BackendAddressPool $Pool
            $RulePublic = New-AzApplicationGatewayRequestRoutingRule -Name "WebclientRule_PublicPort80" -RuleType basic -BackendHttpSettings $HttpSettingWebclientFirst -HttpListener $ListenerPublic -BackendAddressPool $Pool            
        }
        $Rules += $RulePrivate
        $Rules += $RulePublic

        $Sku = New-AzApplicationGatewaySku -Name $ApplicationGatewaySkuName -Tier $ApplicationGatewaySkuTier -Capacity $ApplicationGatewaySkuCapacity
        $params = @{
            Name                          = $ApplicationGatewayName
            ResourceGroupName             = $ResourceGroupName
            Location                      = $ResourceLocation
            BackendAddressPools           = $Pool
            BackendHttpSettingsCollection = $HttpSettings
            FrontendIpConfigurations      = ($FrontEndPublic, $FrontEndPrivate)
            FrontendPorts                 = $FrontEndPorts
            Probes                        = $Probes
            GatewayIpConfigurations       = $GatewayIPconfig
            HttpListeners                 = $Listeners
            RequestRoutingRules           = $Rules
            Sku                           = $Sku            
        }
        if ($AppgwIdentity) {
            $params.Add("Identity", $AppgwIdentity)
        }
        if ($sslCertificate) {
            $params.Add("SslCertificates", $sslCertificate)
        }
        if ($sslRedirectConfig) {
            $params.Add("RedirectConfigurations", $sslRedirectConfig)
        }
        Write-Verbose "Creating ApplicationGateway..."
        $appGateway = New-AzApplicationGateway @params

        Set-ApplicationGatewayAssociationForScaleSet -ResourceGroupName $ResourceGroupName -ApplicationGatewayName $ApplicationGatewayName -BackendPoolName $BackendPoolName -ScaleSetName $VMScaleSetName
    }    
}