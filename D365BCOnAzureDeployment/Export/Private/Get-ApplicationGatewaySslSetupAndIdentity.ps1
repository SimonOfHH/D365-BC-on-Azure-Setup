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
    }
}