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
        $StorageAccountResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageTableNameInfrastructureData,
        [Parameter(Mandatory = $false)]
        [string]
        $NewInstanceMarkerFilename
    )
    process {
        Write-Verbose "Starting auto update..."
        if ($NewInstanceMarkerFilename) {
            Write-Verbose "Indicator for 'New Instance' is set."
        }
        # Uses managed identity to connect to Azure Account
        Connect-FromMachineToAzAccount
        
        # The current instance might still be in creation mode and might also automatically restart during this state
        # This will wait until the instance is marked as "ProvisioningState"="Succeeded"
        Wait-ForInstanceAvailability -ResourceGroupName $ResourceGroupName -ScaleSetName $ObjectName -NewInstanceMarkerFilename $NewInstanceMarkerFilename -IsScaleSet:$IsScaleSet -Verbose:$Verbose

        # Disable Internet Explorer Enhanced Security Configuration (for Admins only) - because it's annoying
        if ($NewInstanceMarkerFilename) {
            Disable-InternetExplorerESC
        }

        Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

        $Resource = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $ObjectName
        if ($Resource.Tags["Staging"]) {
            $TypeFilter = $Resource.Tags["Staging"]
        }

        Write-Verbose "Loading pending commands..."
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName
        $storageAccountCtx = $storageAccount.Context

        $infrastructureData = Get-InfrastructureDataFromStorage -StorageAccountContext $storageAccountCtx -TableNameInfrastructureData $StorageTableNameInfrastructureData -TypeFilter $TypeFilter
        $TableNameSetup = $infrastructureData.SetupTable
        $TableNameEnvironments = $infrastructureData.EnvironmentsTable
        $TableNameEnvironmentDefaults = $infrastructureData.EnvironmentDefaultsTable
        $TableNameLog = $infrastructureData.LogTable
        $TableNameUsers = $infrastructureData.UsersTable
        
        # Workaround, for when an instance of a ScaleSet needed to get a new ComputerName
        $ComputerName = $env:COMPUTERNAME
        if (-not([string]::IsNullOrEmpty($UpdatedComputerName))) {
            $ComputerName = $UpdatedComputerName # Global Varioable from Properties.ps1
        }
        $rows = Get-CommandsFromStorageTable -StorageAccountContext $storageAccountCtx -TableName $TableNameSetup -ObjectName $ObjectName -TypeFilter $TypeFilter
        foreach ($row in $rows) {
            if ($row.Command -ne 'SetupNotDone') {
                if (($NewInstanceMarkerFilename) -and (Test-Path $NewInstanceMarkerFilename)) {
                    # It's possible that we have at one point 2 instances, then remove one and later add it again
                    # The newly added instance might have the same computer name as a previous one and "previous" commands wouldn't be executed again
                    # So this function will mark the previous ones as "Obsolete"
                    Set-StorageCommandsObsolete -StorageAccountContext $storageAccountCtx -LogTableName $TableNameLog -LogObjectName $ObjectName -LogComputerName $ComputerName
                    # Delete File after that, so that we know, that everything is setup as expected
                    Remove-Item $NewInstanceMarkerFilename -Force | Out-Null
                }
            }
            Write-Verbose "Checking if Command $($row.Command) was already executed"
            if (Get-StorageCommandExecutionLog -StorageAccountContext $storageAccountCtx -LogTableName $TableNameLog -CommandRow $row -ExecutedByName $ComputerName) {
                Write-Verbose "Command $($row.Command) was already executed. Skipping to next one."
                continue
            }
            $infrastructureData = Get-InfrastructureDataFromStorage -StorageAccountContext $storageAccountCtx -TableNameInfrastructureData $StorageTableNameInfrastructureData -TypeFilter $TypeFilter
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
                        KeyVaultResourceGroupName           = $KeyVaultResourceGroupName
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $TypeFilter
                    }
                    Invoke-CreateInstances @params -Verbose:$Verbose
                }
                'UpdateInstanceConfiguration' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultResourceGroupName           = $KeyVaultResourceGroupName
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $TypeFilter
                        Parameter2                          = $row.Parameter2
                        RestartService                      = $row.RestartNecessary
                    }
                    Invoke-UpdateInstances @params -Verbose:$Verbose
                }
                'UpdateLicense' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultResourceGroupName           = $KeyVaultResourceGroupName
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $TypeFilter
                        Parameter2                          = $row.Parameter2
                        RestartService                      = $row.RestartNecessary
                    }
                    Invoke-UpdateLicenses @params -Verbose:$Verbose
                }
                'CreateWebInstances' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultResourceGroupName           = $KeyVaultResourceGroupName
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $TypeFilter
                        Parameter2                          = $row.Parameter2
                        InfrastructureData                  = $infrastructureData
                    }
                    Invoke-CreateWebInstances @params -Verbose:$Verbose
                }
                'UpdateWebInstances' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultResourceGroupName           = $KeyVaultResourceGroupName
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $TypeFilter
                        Parameter2                          = $row.Parameter2
                        InfrastructureData                  = $infrastructureData
                    }
                    Invoke-UpdateWebInstances @params -Verbose:$Verbose
                }
                'CreateSPN' {
                    $params = @{
                        StorageAccountContext     = $storageAccountCtx
                        KeyVaultResourceGroupName = $KeyVaultResourceGroupName
                        KeyVaultName              = $KeyVaultName
                        TypeFilter                = $TypeFilter
                        Parameter2                = $row.Parameter2
                        InfrastructureData        = $infrastructureData
                    }
                    Invoke-SetSpnForServices @params -Verbose:$Verbose
                }
                'SetLoadbalancerDNSRecord' {
                    $params = @{
                        KeyVaultResourceGroupName = $KeyVaultResourceGroupName
                        KeyVaultName              = $KeyVaultName
                        InfrastructureData        = $infrastructureData
                    }
                    Invoke-SetLoadBalancerDnsRecord @params -Verbose:$Verbose
                }
                'SetupDelegation' {
                    $params = @{
                        StorageAccountContext        = $storageAccountCtx
                        StorageTableNameEnvironments = $TableNameEnvironments 
                        TypeFilter                   = $TypeFilter
                        KeyVaultResourceGroupName    = $KeyVaultResourceGroupName
                        KeyVaultName                 = $KeyVaultName
                        InfrastructureData           = $infrastructureData
                    }
                    Invoke-SetupDelegation @params -Verbose:$Verbose
                }
                'RestartServices' {
                    $params = @{
                        StorageAccountContext        = $storageAccountCtx
                        KeyVaultResourceGroupName    = $KeyVaultResourceGroupName
                        KeyVaultName                 = $KeyVaultName
                        StorageTableNameEnvironments = $TableNameEnvironments 
                        TypeFilter                   = $TypeFilter
                    }
                    Invoke-RestartServices @params -Verbose:$Verbose
                }
                'RestartIIS' {
                    Write-Verbose "Restarting IIS service (using 'iisreset')"
                    Invoke-Command -Scriptblock { iisreset }
                }
                'AddIIS' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultResourceGroupName           = $KeyVaultResourceGroupName
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $TypeFilter
                        Parameter2                          = $row.Parameter2
                        InfrastructureData                  = $infrastructureData
                    }
                    Invoke-AddIIS @params -Verbose:$Verbose
                }
                'UpdateIIS' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultResourceGroupName           = $KeyVaultResourceGroupName
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $TypeFilter
                        Parameter2                          = $row.Parameter2
                        InfrastructureData                  = $infrastructureData
                    }
                    Invoke-AddIIS @params -Verbose:$Verbose
                }
                'AddUsers' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultResourceGroupName           = $KeyVaultResourceGroupName
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        StorageTableNameUsers               = $TableNameUsers
                        TypeFilter                          = $TypeFilter
                    }
                    Invoke-AddUsers @params -Verbose:$Verbose
                }
                'AddLocalAdminUser' {
                    if ($row.Parameter1) {
                        if (-not(Get-LocalGroupMember -Group "Administrators" -Member $row.Parameter1 -ErrorAction SilentlyContinue)) {
                            Write-Verbose "Adding '$($row.Parameter1)' to local Administrator group"
                            Add-LocalGroupMember -Group "Administrators" -Member $row.Parameter1
                        }
                    }
                    if ($row.Parameter2) {
                        if (-not(Get-LocalGroupMember -Group "Administrators" -Member $row.Parameter2 -ErrorAction SilentlyContinue)) {
                            Write-Verbose "Adding '$($row.Parameter2)' to local Administrator group"
                            Add-LocalGroupMember -Group "Administrators" -Member $row.Parameter2
                        }
                    }
                }
                'AddAddins' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultResourceGroupName           = $KeyVaultResourceGroupName
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults
                        TypeFilter                          = $TypeFilter
                        Parameter2                          = $row.Parameter2
                        RestartService                      = $row.RestartNecessary
                    }
                    Invoke-AddAddIns @params -Verbose:$Verbose
                }
                'SetupCertificate' {
                    $params = @{
                        StorageAccountContext               = $storageAccountCtx
                        KeyVaultResourceGroupName           = $KeyVaultResourceGroupName
                        KeyVaultName                        = $KeyVaultName
                        StorageTableNameEnvironments        = $TableNameEnvironments 
                        StorageTableNameEnvironmentDefaults = $TableNameEnvironmentDefaults 
                        TypeFilter                          = $TypeFilter
                        CertificateType                     = ""
                        RestartService                      = $row.RestartNecessary
                    }
                    switch (Get-MachineInstanceType -InfrastructureData $infrastructureData) {
                        'Application' {
                            $params.CertificateType = "ServiceInstance"
                            Invoke-SetupCertificateAppServer @params -Verbose:$Verbose
                        }
                        'Web' { 
                            $params.CertificateType = "Webclient"
                            Invoke-SetupCertificateWebServer @params -Verbose:$Verbose
                        }
                        'Both' { 
                            $params.CertificateType = "ServiceInstance"
                            Invoke-SetupCertificateAppServer @params -Verbose:$Verbose
                            
                            $params.CertificateType = "Webclient"
                            Invoke-SetupCertificateWebServer @params -Verbose:$Verbose
                        }
                    }
                }
                default {
                    Write-Verbose "Not implemented yet."
                }                
            }
            Set-StorageCommandExecuted -CommandRow $row -ExecutedByName $ComputerName -StorageAccountContext $storageAccountCtx -LogTableName $TableNameLog
        }
        Write-Verbose "Update complete"
    }
}