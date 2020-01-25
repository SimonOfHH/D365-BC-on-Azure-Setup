function Add-CertificatesToKeyVault {
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
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        [Object[]]
        $Certificates
    )
    process {
        function Get-NewSelfSignedCertificate() {
            [CmdletBinding()]
            param
            (
                [Parameter(Mandatory = $true)]
                [string]
                $DnsName,
                [Parameter(Mandatory = $true)]
                [SecureString]
                $CertificatePassword,
                [Parameter(Mandatory = $false)]
                [string]
                $CertificateStoreLocation = "cert:\LocalMachine\My",
                [Parameter(Mandatory = $false)]
                [string]
                $TargetFilename
            )
            Write-Verbose "Generating new self-signed certificate"
            if (-not($TargetFilename)) {
                $TargetFilename = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'pfx' } -PassThru | Select-Object -ExpandProperty FullName
            }
            Write-Verbose "Target Filename is: $TargetFilename"
            $certificate = New-SelfSignedCertificate -DnsName $DnsName -CertStoreLocation $CertificateStoreLocation -NotAfter (Get-Date).AddYears(5)
            $fileinfo = Get-ChildItem -Path $certificate.PSPath | Export-PfxCertificate -FilePath $TargetFilename -Password $CertificatePassword

            # Remove from local storage
            Get-ChildItem -Path $certificate.PSPath | Remove-Item -Force
            $fileinfo.FullName
            
        }
        function Get-CertificateThumbprint {
            # 
            # This will return a certificate thumbprint, null if the file isn't found or throw an exception.
            #
        
            param (
                [parameter(Mandatory = $true)][string] $CertificatePath,
                [parameter(Mandatory = $false)][SecureString] $CertificatePassword
            )
        
            try {
                if (!(Test-Path $CertificatePath)) {
                    return $null;
                }
        
                $certificateObject = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
                $certificateObject.Import($CertificatePath, $CertificatePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet);
        
                return $certificateObject.Thumbprint
            }
            catch [Exception] {
                # 
                # Catch accounts already added.
                throw $_;
            }
        }
        $keyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName -ErrorAction SilentlyContinue         
        if (-not($keyVault)) {
            Write-Verbose "KeyVault $KeyVaultName does not exists. Stopping here."
            return
        }
        $generatedCertificatePath = ""
        foreach ($certificate in $Certificates) {
            if (-not($certificate.Path)) {
                if ($generatedCertificatePath) {
                    $certificate.Path = $generatedCertificatePath
                }
            }
            if (-not($certificate.Path)) {
                if (-not($certificate.DnsName)) {
                    throw "You need to set DnsName for certificate-element if you don't provide an existing file."
                }
                $generatedCertificatePath = Get-NewSelfSignedCertificate -DnsName $certificate.DnsName -CertificatePassword (ConvertTo-SecureString -String $certificate.Password -Force -AsPlainText) -Verbose:$Verbose
                $certificate.Path = $generatedCertificatePath
            }            
            if ($generatedCertificatePath) {
                $source = "Temporary Self-Signed Certificate"
            }
            else {
                $source = "Existing Certificate"
            }
            $tags = @{
                "AddedOn"    = "$(get-date -format yyyyMMddhhmmss)"
                "FromSource" = $source
            }
            if (-not($generatedCertificatePath)) {
                $tags += @{"SourceFile" = "$(Split-Path $certificate.Path -Leaf)" }
            }            
            Write-Verbose "Checking if Certificate $($certificate.Type) already exists in KeyVault..."
            $vaultCert = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $certificate.Type -ErrorAction SilentlyContinue
            if ($vaultCert) {
                if ($vaultCert.Thumbprint -ne (Get-CertificateThumbprint -CertificatePath $certificate.Path -CertificatePassword (ConvertTo-SecureString -String $certificate.Password -Force -AsPlainText))) {
                    Write-Verbose "Updating Certificate $($certificate.Type) and password in KeyVault..."
                    Import-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $certificate.Type -FilePath $certificate.Path -Password (ConvertTo-SecureString -String $certificate.Password -AsPlainText -Force) -Tag $tags | Out-Null
                    Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "$($certificate.Type)-CertPassword" -SecretValue (ConvertTo-SecureString -String $certificate.Password -AsPlainText -Force) | Out-Null
                }
                else {
                    Write-Verbose "Certificate $($certificate.Type) already exists in KeyVault..."
                }
            }
            else {                
                Write-Verbose "Adding Certificate $($certificate.Type) and password to KeyVault..."
                Import-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $certificate.Type -FilePath $certificate.Path -Password (ConvertTo-SecureString -String $certificate.Password -AsPlainText -Force)  -Tag $tags | Out-Null
                Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "$($certificate.Type)-CertPassword" -SecretValue (ConvertTo-SecureString -String $certificate.Password -AsPlainText -Force) | Out-Null
            }
        }
    }
}
