function Invoke-SetupCertificateWebServer {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [Parameter(Mandatory = $true)]
        $StorageAccountContext,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageTableNameEnvironments,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageTableNameEnvironmentDefaults,        
        [Parameter(Mandatory = $true)]
        [string]
        $TypeFilter,
        [Parameter(Mandatory = $true)]
        [ValidateSet('ServiceInstance', 'Webclient')]
        [string]
        $CertificateType,
        [bool]
        $RestartService
    )
    process {
        Write-Verbose "Setting up certificate..."
        Write-Verbose "Checking if certificate exists..."
        $certificate = Get-AzKeyVaultCertificate -VaultName $KeyVaultName -Name $CertificateType -ErrorAction SilentlyContinue
        if (-not($certificate)){
            Write-Verbose "Certificate does not exist. Exiting here."
            return
        }

        Import-NecessaryModules -Type Web

        $certificateInfo = Save-AzureCertificateToLocalFile -KeyVaultName $KeyVaultName -Certificate $certificate -CertificateType $CertificateType
        # Add Cert to My-Store
        Write-Verbose "Importing certificate to Personal-store..."
        Import-PfxCertificate -FilePath $certificateInfo.Path -CertStoreLocation Cert:\LocalMachine\My -Password (ConvertTo-SecureString -String $certificateInfo.Password -AsPlainText -Force)
        Set-CertificatePermissions -CertificateThumbprint $certificateInfo.Thumbprint
        
        # Add Cert to Trusted Root-Store
        Write-Verbose "Importing certificate to Trusted Root-store..."
        Import-PfxCertificate -FilePath $certificateInfo.Path -CertStoreLocation Cert:\LocalMachine\Root -Password (ConvertTo-SecureString -String $certificateInfo.Password -AsPlainText -Force)

        # Add Binding to IIS Site
        Write-Verbose "Adding binding to IIS Site..."
        New-WebBinding -Name (Get-IISSite | Where-Object {$_.Name -like '*Dynamics*Web*'} | Select-Object -ExpandProperty Name) -IP "*" -Port 443 -Protocol https
        # Assign certificate to Binding
        Write-Verbose "Adding certificate to binding..."
        Get-Item cert:\LocalMachine\My\$($certificateInfo.Thumbprint) | New-Item 'IIS:\SSLBindings\0.0.0.0!443'
    }
}