function Invoke-SetupCertificateAppServer {
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
        
        Import-NecessaryModules -Type Application        

        $certificateInfo = Save-AzureCertificateToLocalFile -KeyVaultName $KeyVaultName -Certificate $certificate -CertificateType $CertificateType
        # Add Cert to My-Store
        Write-Verbose "Importing certificate to Personal-store..."
        Import-PfxCertificate -FilePath $certificateInfo.Path -CertStoreLocation Cert:\LocalMachine\My -Password (ConvertTo-SecureString -String $certificateInfo.Password -AsPlainText -Force)
        # Add Cert to Trusted Root-Store
        Write-Verbose "Importing certificate to Trusted Root-store..."
        Import-PfxCertificate -FilePath $certificateInfo.Path -CertStoreLocation Cert:\LocalMachine\Root -Password (ConvertTo-SecureString -String $certificateInfo.Password -AsPlainText -Force)

        # Update Service Instances
        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $StorageAccountContext -TableNameEnvironments $StorageTableNameEnvironments -TableNameDefaults $StorageTableNameEnvironmentDefaults -TypeFilter $TypeFilter -ConfigType Application        
        foreach ($environment in $environments) {
            if (Get-NavServerInstance -ServerInstance $environment.ServerInstance) {
                $config = Get-NAVServerConfiguration -ServerInstance $environment.ServerInstance
                # Convert Result to HashTable
                $currentConf = @{ }
                $config | ForEach-Object { $currentConf[$_.key] = $_.value }

                $updated = $false
                $updated = $updated -or (Set-NAVConfigurationIfDifferent -ServerInstance $environment.ServerInstance -KeyName ServicesCertificateThumbprint -KeyValue $certificateInfo.Thumbprint -CurrentConfiguration $currentConf -Verbose)
                
                # Update SSL-related settings
                foreach ($key in $environment.Settings.Keys | Where-Object {$_ -like '*SSL*'}) {
                    if ((-not([string]::IsNullOrEmpty($key))) -and (-not([string]::IsNullOrEmpty($environment.Settings[$key])))) {
                        $skipUpdate = $false
                        if ($key.ToString().Contains("SSL")) {
                            if ([string]::IsNullOrEmpty($config["ServicesCertificateThumbprint"])) {
                                $skipUpdate = $true                                
                            }
                        }
                        if (-not($skipUpdate)) {
                            $updated = $updated -or (Set-NAVConfigurationIfDifferent -ServerInstance $environment.ServerInstance -KeyName $key -KeyValue $environment.Settings[$key] -CurrentConfiguration $currentConf -Verbose)
                            # Update Current Config
                            $currentConf[$key] = $environment.Settings[$key]
                        } else {
                            Write-Verbose "Skipping Update of $($key), because 'ServicesCertificateThumbprint' is not set for this instance"
                        }
                    }
                }

                if ($updated -and $RestartService) {
                    Write-Verbose "Restarting service $($environment.ServerInstance)"
                    Restart-NAVServerInstance -ServerInstance $environment.ServerInstance
                }
            }
        }
    }
}