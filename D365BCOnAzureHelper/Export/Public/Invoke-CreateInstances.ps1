function Invoke-CreateInstances {
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
        $TypeFilter
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
                        $KeyVaultName
                    )
                    Write-Verbose "Creating instance: $($environment.ServerInstance)"
                
                    $output = New-NAVServerInstance $environment.ServerInstance `
                        -DatabaseServer $environment.DatabaseServer  `
                        -DatabaseInstance $environment.DatabaseInstance  `
                        -Databasename $environment.Databasename `
                        -ClientServicesPort $environment.ClientServicesPort   `
                        -ManagementServicesPort $environment.ManagementServicesPort `
                        -SOAPServicesPort $environment.SoapServicesPort   `
                        -ODataServicesPort $environment.OdataServicesPort -Verbose:$Verbose
                
                    Write-Verbose "Changing port-configuration..."
                    Set-NAVServerConfiguration -ServerInstance $environment.ServerInstance -KeyName DeveloperServicesPort -KeyValue $environment.DeveloperServicesPort -Verbose:$Verbose
                    Write-Verbose "Updating authentication-method..."
                    Set-NAVServerConfiguration -ServerInstance $environment.ServerInstance -KeyName ClientServicesCredentialType -KeyValue $environment.Authentication -Verbose:$Verbose

                    Write-Verbose "Updating service-account..."
                    $params = @{KeyVaultName = $KeyVaultName }
                    if (-not([string]::IsNullOrEmpty($environment.KVCredentialIdentifier))) {
                        $params.Add("KVIdentifier", $environment.KVCredentialIdentifier)
                    }
                    $credentialsObject = Get-ServiceUserCredentialsObject @params -Verbose:$Verbose
                    Set-NAVServerInstance -ServerInstance $environment.ServerInstance -ServiceAccount User -ServiceAccountCredential $credentialsObject -Verbose:$Verbose

                    foreach ($key in $environment.Settings.Keys) {
                        if ((-not([string]::IsNullOrEmpty($key))) -and (-not([string]::IsNullOrEmpty($environment.Settings[$key])))) {
                            Set-NAVServerConfiguration -ServerInstance $environment.ServerInstance -KeyName $key -KeyValue $environment.Settings[$key] -Verbose:$Verbose
                        }
                    }
                    # Do not start right away
                    #Write-Verbose "Restarting service"
                    #Restart-NAVServerInstance -ServerInstance $environment.ServerInstance | Out-Null
                    #Write-Verbose "Service restarted"
                }
                $scriptBlock
            }
        }
        Import-NecessaryModules -Type Application

        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $StorageAccountContext -TableNameEnvironments $StorageTableNameEnvironments -TableNameDefaults $StorageTableNameEnvironmentDefaults -TypeFilter $TypeFilter -ConfigType Application
        foreach ($environment in $environments) {
            if (-not (Get-NavServerInstance -ServerInstance $environment.ServerInstance)) {
                # This call needs to be done as job, because otherwise the underlying assembly will cause the transcription to stop and we won't have any log then
                $initScriptBlock = {                    
                    Import-Module D365BCOnAzureHelper
                    Import-Module Az.Accounts, Az.KeyVault
                    Import-NecessaryModules -Type Application
                }
                $scriptBlock = Get-ScriptblockForJob
                $job = Start-Job -ScriptBlock $scriptBlock -InitializationScript $initScriptBlock -ArgumentList $environment, $KeyVaultName
                $job | Receive-Job -Wait -Verbose:$Verbose
                $VerboseOutput = $job.ChildJobs[0].verbose.readall()
                Write-Verbose "Printing verbose-output from job: "                
                $VerboseOutput | ForEach-Object { Write-Verbose $_ }
            }
        }
    }
}