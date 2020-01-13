function Global:Get-EnvironmentsFromStorage {
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
        $TableNameEnvironments,
        [Parameter(Mandatory = $false)]
        [string]
        $TableNameDefaults,
        [Parameter(Mandatory = $true)]
        [string]
        $TypeFilter,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Application', 'Web')]
        [string]
        $ConfigType = "Application",
        [Parameter(Mandatory = $false)]
        [switch]
        $EnvironmentsOnly
    )
    process {
        Write-Verbose "Loading Environment-data from Storage-table $TableName..."
        $environments = @()
        if (-not($EnvironmentsOnly)){
            if ([string]::IsNullOrEmpty($TableNameDefaults)){
                throw "TableNameDefaults might not be empty"
            }
        }
        $storageAccountTable = Get-AzStorageTable -Name $TableNameEnvironments -Context $StorageAccountContext
        $cloudTable = $storageAccountTable.CloudTable
        $rows = Get-AzTableRow -Table $cloudTable  | Where-Object { ($_.Type -eq $TypeFilter) }
        foreach ($row in $rows) {
            $instance = [pscustomobject]@{
                ServerInstance         = $row.ServiceName;
                DatabaseServer         = $row.DatabaseServer;
                DatabaseInstance       = $row.DatabaseInstance;
                Databasename           = $row.DatabaseName;
                ClientServicesPort     = $row.ClientServicesPort ;
                ManagementServicesPort = $row.ManagementServicesPort 
                SoapServicesPort       = $row.SoapServicesPort;
                OdataServicesPort      = $row.ODataServicesPort;
                DeveloperServicesPort  = $row.DeveloperServicesPort;
                Authentication         = $row.AuthType
                KVCredentialIdentifier = $row.KVCredentialIdentifier
                Settings               = @{ }
            }
            $environments += $instance
        }
        if ($EnvironmentsOnly){
            $environments
            return
        }
        foreach ($environment in $environments) {
            $storageAccountTable = Get-AzStorageTable -Name $TableNameDefaults -Context $storageAccountContext.Context
            $cloudTable = $storageAccountTable.CloudTable
            if ($ConfigType -eq "Application"){
                $rows = Get-AzTableRow -Table $cloudTable | Where-Object { (($_.ServiceName -eq $null) -or ($_.ServiceName -eq "") -or ($_.ServiceName -eq $instanceRow.ServiceName)) -and (($_.WebConfig -eq $false) -or ($_.WebConfig -eq $null)) }
            } else {
                $rows = Get-AzTableRow -Table $cloudTable | Where-Object { (($_.ServiceName -eq $null) -or ($_.ServiceName -eq "") -or ($_.ServiceName -eq $instanceRow.ServiceName)) -and (($_.WebConfig -eq $true)) }
            }
            $settings = @{}
            foreach ($row in $rows) {
                $settings.Add($row.KeyName, $row.KeyValue)
            }
            $environment.Settings = $settings
        }
        $environments
    }
}