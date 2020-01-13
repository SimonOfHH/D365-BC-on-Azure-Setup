function Invoke-UpdateLicenses {
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
        [string]
        $Parameter2,
        [bool]
        $RestartService
    )
    process {
        if ([string]::IsNullOrEmpty($Parameter2)) {
            throw "You need to specify an URI (in 'Parameter2' of the Setup table) to download the license."
            return
        }

        if ($Parameter2 -eq "DEMO") {
            $path = "C:\Install\DVD\SQLDemoDatabase\*\Cronus.flf"
            $targetFilename = (Get-ChildItem -Path $path -Recurse | Select-Object -First 1).FullName
        }
        else {
            # Download License
            Write-Verbose "Downloading license file"
            $targetFilename = 'C:\Install\ScriptDownload\license.flf'
            Receive-CustomFile -URI $Parameter2 -DestinationFile $targetFilename
        }
        if (-not($targetFilename)){
            throw "No license file found."
            return
        }
        Import-NecessaryModules -Type Application
        
        $environments = Get-EnvironmentsFromStorage -StorageAccountContext $storageAccountContext -TableNameEnvironments $StorageTableNameEnvironments -TableNameDefaults $StorageTableNameEnvironmentDefaults -TypeFilter $TypeFilter -ConfigType Application -EnvironmentsOnly
        foreach ($environment in $environments) {
            if (Get-NavServerInstance -ServerInstance $environment.ServerInstance) {
                Write-Verbose "Updating license..."
                Import-NAVServerLicense -ServerInstance $environment.ServerInstance -LicenseFile $targetFilename
                if ($RestartService -eq $true) {
                    Write-Verbose "Restarting service..."
                    Restart-NAVServerInstance -ServerInstance $environment.ServerInstance | Out-Null
                }
            }
        }
    }
}