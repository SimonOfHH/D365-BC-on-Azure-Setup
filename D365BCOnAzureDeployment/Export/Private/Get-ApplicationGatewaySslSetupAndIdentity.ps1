function Global:Get-ApplicationGatewaySslSetupAndIdentity {
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
        $ApplicationGatewayName,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $false)]
        [string]
        $CertificateName = "ApplicationGateway"
    )
    process {
        $SslSetup = @{
            HandleSSL = $false
            Certificate  = $null
            Identity = $null
        }
        
        if ($KeyVaultName) {
            $certificate = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateName -ErrorAction SilentlyContinue
            if ($certificate) {
                $SslSetup.HandleSSL = $true
            }
        }
        if (-not($SslSetup.HandleSSL)){
            $SslSetup
            return 
        }
        Write-Verbose "Preparing SSL Setup..."
        if ($SslSetup.HandleSSL) {
            Write-Verbose "Retrieving certificate from KeyVault"
            $secret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $CertificateName
            $secretId = $secret.Id.Replace($secret.Version, "") # https://<keyvaultname>.vault.azure.net/secrets/
            $sslCertificate = New-AzApplicationGatewaySslCertificate -Name "$ApplicationGatewayName-certificate01" -KeyVaultSecretId $secretId

            # Identity is needed, to be able to read from KeyVault
            Write-Verbose "Generating identity for Application Gateway, to be able to read from KeyVault"
            $Identity = Get-AzUserAssignedIdentity -Name "$ApplicationGatewayName-Identity01" -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            if (-not($Identity)) {
                $Identity = New-AzUserAssignedIdentity -Name "$ApplicationGatewayName-Identity01" -ResourceGroupName $ResourceGroupName -Location $ResourceLocation
            }
            Wait-ForNewlyCreatedIdentity -ResourceGroupName $ResourceGroupName -ObjectId $Identity.PrincipalId  -Verbose:$Verbose

            $AppgwIdentity = New-AzApplicationGatewayIdentity -UserAssignedIdentity $Identity.Id
            Write-Verbose "Updating KeyVault-access policy for new identity"
            Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -ObjectId $Identity.PrincipalId -PermissionsToKeys get -PermissionsToSecrets get -PermissionsToCertificates get | Out-Null

            $SslSetup.Certificate = $sslCertificate
            $SslSetup.Identity = $AppgwIdentity
        }
        $SslSetup
        #xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

        Write-Verbose "Adding Frontend-Configuration..."
        $FrontEndPorts = @{
            PrivateHttp = $null
            PublicHttp  = $null
            PublicHttps = $null
            Collection  = @()
        }
        $FrontEndPorts.PrivateHttp += New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Private8080"  -Port 8080
        $FrontEndPorts.PublicHttp += New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Public80"  -Port 80        
        $FrontEndPorts.Collection += ($FrontEndPorts.PrivateHttp,$FrontEndPorts.PublicHttp)
        if ($IncludeSsl) {
            $FrontEndPorts.PublicHttps += New-AzApplicationGatewayFrontendPort -Name "FrontendPort_Public443"  -Port 443            
            $FrontEndPorts.Collection += ($FrontEndPorts.PublicHttps)
        }        
        $FrontEndPorts
    }
}