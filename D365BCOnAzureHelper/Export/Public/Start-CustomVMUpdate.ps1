# Will be called in VM
function Start-CustomVMUpdate {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
        Parameters for Commands
        Command                             |       Parameter 1             |     Parameter 2       |
        JoinDomain                          |       none                    |     none              |
        CreateInstances                     | Typefilter (e.g. "TEST") [x]  | "RestartService" [ ]  |
        UpdateInstanceConfiguration         | Typefilter (e.g. "TEST") [x]  | "RestartService" [ ]  |
        UpdateLicense                       | URI to Licensefile [x]        | "RestartService" [ ]  |
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ObjectName,
        [Parameter(Mandatory = $false)]
        [switch]
        $IsScaleSet,
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageTableNameInfrastructureData
    )
    process {
        Write-Verbose "Starting auto update..."

        # Uses managed identity to connect to Azure Account
        Connect-FromMachineToAzAccount
        
        # Disable Internet Explorer Enhanced Security Configuration (for Admins only) - because it's annoying
        Disable-InternetExplorerESC

        Write-Verbose "Loading pending commands..."
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
        $storageAccountCtx = $storageAccount.Context

        $infrastructureData = Get-InfrastructureDataFromStorage -StorageAccountContext $storageAccountCtx -TableNameInfrastructureData $StorageTableNameInfrastructureData
        $TableNameSetup = $infrastructureData.SetupTable
        $TableNameEnvironments = $infrastructureData.EnvironmentsTable
        $TableNameEnvironmentDefaults = $infrastructureData.EnvironmentDefaultsTable
        $TableNameLog = $infrastructureData.LogTable
        $TableNameUsers = $infrastructureData.UsersTable

        $rows = Get-CommandsFromStorageTable -StorageAccountContext $storageAccountCtx -TableName $TableNameSetup -ObjectName $ObjectName
        foreach ($row in $rows) {
            Write-Verbose "Checking if Command $($row.Command) was already executed"
            if (Get-StorageCommandExecutionLog -StorageAccountContext $storageAccountCtx -LogTableName $TableNameLog -CommandRow $row -ExecutedByName $env:computername) {
                Write-Verbose "Command $($row.Command) was already executed. Skipping to next one."
                continue
            }
            $infrastructureData = Get-InfrastructureDataFromStorage -StorageAccountContext $storageAccountCtx -TableNameInfrastructureData $StorageTableNameInfrastructureData -TypeFilter $row.Parameter1
            Write-Verbose "Handling Command: $($row.Command)"
            switch ($row.Command) {
                'SetupNotDone' {
                    Write-Verbose "Setup is not done yet. Exiting here."
                    if ($row.Parameter1 -eq 'ClearLog') {
                        # Removing previous (unnecessary) log-files
                        $logPath = "C:\Install\Log"
                        if (Test-Path -Path $logPath) {
                            Get-ChildItem $logPath\* -Include *.log | Select-Object -SkipLast 1 | Remove-Item -Force
                        }
                    }
                    return
                }
                'CreateInstances' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $row.Parameter1
                    }
                    Invoke-CreateInstances @params -Verbose:$Verbose
                }
                'UpdateInstanceConfiguration' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $row.Parameter1
                        Parameter2                          = $row.Parameter2
                        RestartService                      = $row.RestartNecessary
                    }
                    Invoke-UpdateInstances @params -Verbose:$Verbose
                }
                'UpdateLicense' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $row.Parameter1
                        Parameter2                          = $row.Parameter2
                        RestartService                      = $row.RestartNecessary
                    }
                    Invoke-UpdateLicenses @params -Verbose:$Verbose
                }
                'CreateWebInstances' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $row.Parameter1
                        Parameter2                          = $row.Parameter2
                        InfrastructureData                  = $infrastructureData
                    }
                    Invoke-CreateWebInstances @params -Verbose:$Verbose
                }
                'UpdateWebInstances' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $row.Parameter1
                        Parameter2                          = $row.Parameter2
                        InfrastructureData                  = $infrastructureData
                    }
                    Invoke-UpdateWebInstances @params -Verbose:$Verbose
                }
                'CreateSPN' {
                    $params = @{
                        StorageAccountContext = $storageAccountCtx
                        KeyVaultName          = $KeyVaultName
                        TypeFilter            = $row.Parameter1
                        Parameter2            = $row.Parameter2
                        InfrastructureData    = $infrastructureData
                    }
                    Invoke-SetSpnForServices @params -Verbose:$Verbose
                }
                'SetLoadbalancerDNSRecord' {
                    $params = @{
                        KeyVaultName       = $KeyVaultName
                        InfrastructureData = $infrastructureData
                    }
                    Invoke-SetLoadBalancerDnsRecord @params -Verbose:$Verbose
                }
                'SetupDelegation' {
                    $params = @{
                        StorageAccountContext        = $storageAccountCtx
                        StorageTableNameEnvironments = $TableNameEnvironments 
                        TypeFilter                   = $row.Parameter1
                        KeyVaultName                 = $KeyVaultName
                        InfrastructureData           = $infrastructureData
                    }
                    Invoke-SetupDelegation @params -Verbose:$Verbose
                }
                'RestartServices' {
                    $params = @{
                        StorageAccountContext        = $storageAccountCtx
                        KeyVaultName                 = $KeyVaultName
                        StorageTableNameEnvironments = $TableNameEnvironments 
                        TypeFilter                   = $row.Parameter1
                    }
                    Invoke-RestartServices @params -Verbose:$Verbose
                }
                'RestartIIS' {
                    Write-Verbose "Restarting IIS service (using 'iisreset')"
                    Invoke-Command -Scriptblock { iisreset }
                }
                'AddUsers' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        StorageTableNameUsers               = $TableNameUsers
                        TypeFilter                          = $row.Parameter1
                    }
                    Invoke-AddUsers @params -Verbose:$Verbose
                }
                # Add "UpdateCertificate"
                # Add "UpdateWebCertificate"                
                default {
                    Write-Verbose "Not implemented yet."
                }                
            }
            Set-StorageCommandExecuted -CommandRow $row -ExecutedByName $env:computername -StorageAccountContext $storageAccountCtx -LogTableName $TableNameLog
        }
    }
}