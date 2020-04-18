# Will be called in VM
function Global:Save-AzureCertificateToLocalFile {
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
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        $Certificate,
        [Parameter(Mandatory = $true)]
        [string]
        $CertificateType,
        [Parameter(Mandatory = $true)]
        [string]
        $TargetFilename
    )
    process {
        New-Item -Path (Split-Path $TargetFilename -Parent) -ItemType Directory -ErrorAction SilentlyContinue

        $certPasswordSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "$($CertificateType)-CertPassword"
        
        $certSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $Certificate.SecretId -ErrorAction SilentlyContinue
        if (-not($certSecret)) {
            # MS Documentation says that the first command should work (see example2 here: https://docs.microsoft.com/en-us/powershell/module/az.keyvault/get-azkeyvaultcertificate?view=azps-3.3.0)
            # However, when I tested it, SecretID contained the complete URI (like: https://kvname.vault.azure.net:443/secrets/ServiceInstance/00000000000000)
            # So lets here call the same, but only with the last part
            $certSecret = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $Certificate.SecretId.Substring($Certificate.SecretId.IndexOf("secrets/") + 8)
        }        

        $secretByte = [Convert]::FromBase64String($certSecret.SecretValueText)
        $x509Cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
        $x509Cert.Import($secretByte, "", "Exportable,PersistKeySet")
        $type = [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx
        $pfxFileByte = $x509Cert.Export($type, $certPasswordSecret.SecretValueText)
        # Write to a file
        [System.IO.File]::WriteAllBytes($TargetFilename, $pfxFileByte)

        $certificateInfo = @{
            Name       = $CertificateType
            Password   = $certPasswordSecret.SecretValueText
            Thumbprint = $Certificate.Thumbprint
            Path       = $TargetFilename
        }
        $certificateInfo
    }
}