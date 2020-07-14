function Invoke-UpdateInstances {
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
        [string]
        $Parameter2,
        [bool]
        $RestartService
    )
    process {
        function Get-ScriptblockForJob {
            process {
                $scriptBlock = {
                    [CmdletBinding()]
                    param(
                        [Parameter(Mandatory = $true)]        
                        $Environment,
                        [Parameter(Mandatory = $true)]
                        [string]
                        $KeyVaultResourceGroupName,
                        [Parameter(Mandatory = $true)]
                        [string]
                        $KeyVaultName,
                        [boolean]
                        $RestartService,
                        [Parameter(Mandatory = $true)]
                        $CredentialsObject
                    )
                    Write-Verbose "Updating instance $($environment.ServerInstance)"
                    $config = Get-NAVServerConfiguration -ServerInstance $environment.ServerInstance

                    # Convert Result to HashTable
                    $currentConf = @{ }
                    $config | ForEach-Object { $currentConf[$_.key] = $_.value }

                    $updated = $false
                    $updated = $updated -or (Set-NAVConfigurationIfDifferent -ServerInstance $environment.ServerInstance -KeyName DeveloperServicesPort -KeyValue $environment.DeveloperServicesPort -CurrentConfiguration $currentConf -Verbose)
                    $updated = $updated -or (Set-NAVConfigurationIfDifferent -ServerInstance $environment.ServerInstance -KeyName ODataServicesPort -KeyValue $environment.OdataServicesPort -CurrentConfiguration $currentConf -Verbose)
                    $updated = $updated -or (Set-NAVConfigurationIfDifferent -ServerInstance $environment.ServerInstance -KeyName SOAPServicesPort -KeyValue $environment.SoapServicesPort -CurrentConfiguration $currentConf -Verbose)
                    $updated = $updated -or (Set-NAVConfigurationIfDifferent -ServerInstance $environment.ServerInstance -KeyName ClientServicesCredentialType -KeyValue $environment.Authentication -CurrentConfiguration $currentConf -Verbose)

                    #$params = @{KeyVaultName = $KeyVaultName }
                    #if (-not([string]::IsNullOrEmpty($environment.KVCredentialIdentifier))) {
                    #    $params.Add("KVIdentifier", $environment.KVCredentialIdentifier)
                    #}
                    #$credentialsObject = Get-ServiceUserCredentialsObject @params

                    $serviceAccount = (Get-NavServerInstance $environment.ServerInstance).ServiceAccount
                    if ($serviceAccount -ne $credentialsObject.UserName) {
                        Set-NAVServerInstance -ServerInstance $environment.ServerInstance -ServiceAccount User -ServiceAccountCredential $CredentialsObject | Out-Null
                        $updated = $true
                    }

                    foreach ($key in $environment.Settings.Keys) {
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
                            }
                            else {
                                Write-Verbose "Skipping Update of $($key), because 'ServicesCertificateThumbprint' is not set for this instance"
                            }
                        }
                    }
                    if ($updated -and ($RestartService)) {
                        Write-Verbose "Restarting service"
                        Restart-NAVServerInstance -ServerInstance $environment.ServerInstance
                    }
                }
                $scriptBlock
            }
        }
        Import-NecessaryModules -Type Application
        
        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $StorageAccountContext -TableNameEnvironments $StorageTableNameEnvironments -TableNameDefaults $StorageTableNameEnvironmentDefaults -TypeFilter $TypeFilter -ConfigType Application
        foreach ($environment in $environments) {
            if (Get-NavServerInstance -ServerInstance $environment.ServerInstance) {
                # This call needs to be done as job, because otherwise the underlying assembly will cause the transcription to stop and we won't have any log then
                $initScriptBlock = {                    
                    Import-Module D365BCOnAzureHelper
                    #Import-Module Az.Accounts, Az.KeyVault
                    Import-NecessaryModules -Type Application
                }
                Write-Verbose "Loading service-account..."
                $params = @{KeyVaultName = $KeyVaultName }
                if (-not([string]::IsNullOrEmpty($environment.KVCredentialIdentifier))) {
                    $params.Add("KVIdentifier", $environment.KVCredentialIdentifier)
                }
                $credentialsObject = Get-ServiceUserCredentialsObject @params -Verbose:$Verbose

                $scriptBlock = Get-ScriptblockForJob
                $job = Start-Job -ScriptBlock $scriptBlock -InitializationScript $initScriptBlock -ArgumentList $environment, $KeyVaultResourceGroupName, $KeyVaultName, $RestartService, $credentialsObject
                $job | Receive-Job -Wait -Verbose:$Verbose
                $VerboseOutput = $job.ChildJobs[0].verbose.readall()
                Write-Verbose "Printing verbose-output from job: "                
                $VerboseOutput | ForEach-Object { Write-Verbose $_ }
            }
        }
    }
}