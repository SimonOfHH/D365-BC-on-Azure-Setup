function Invoke-AddAddIns {
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
        [Parameter(Mandatory = $false)]
        [string]
        $TypeFilter,
        [string]
        $Parameter2,
        [bool]
        $RestartService
    )
    process {
        if ([string]::IsNullOrEmpty($Parameter2)) {
            throw "You need to specify an URI (in 'Parameter2' of the Setup table) to download the file."
            return
        }        
        
        $destinationFolder = "C:\Program Files\Microsoft Dynamics 365 Business Central\*\Service\Add-ins"
        $destinationFolder = (Get-Item $destinationFolder).FullName        
        if (-not(Test-Path -Path $destinationFolder)) {
            throw "Path $destinationFolder does not exist. Can not proceed."
        }
        
        # Prepare and download File
        $filename = Split-Path -Path $Parameter2 -Leaf
        $targetPath = "C:\Install\ScriptDownloads"
        $archiveTempPath = "C:\Install\ScriptDownloads\ArchiveTemp"
        $targetFilename = Join-path -Path $targetPath -ChildPath $filename
        
        if (Test-Path $archiveTempPath) {
            Remove-Item -Path $archiveTempPath -Force -Recurse
        }
        Receive-CustomFile -URI $Parameter2 -DestinationFile $targetFilename
        
        # If it is an archive, then extract it first to temporary location
        if ($targetFilename.EndsWith('.zip')) {
            Expand-Archive -Path $targetFilename -DestinationPath $archiveTempPath
            $targetFilename = $archiveTempPath
        }
        
        if (((Get-Item $targetFilename) -is [System.IO.DirectoryInfo])) {
            # Copy everything in the folder
            Write-Verbose "Copying (directory contents)"
            Write-Verbose "   From: $targetFilename"
            Write-Verbose "     To: $destinationFolder"
            Copy-Item -Path $targetFilename\* -Destination $destinationFolder -Recurse
        }
        else {
            # Copy single file
            Write-Verbose "Copying (single file)"
            Write-Verbose "   From: $targetFilename"
            Write-Verbose "     To: $destinationFolder"
            Copy-Item -Path $targetFilename -Destination $destinationFolder
        }
        if ($RestartService -eq $true) {
            Import-NecessaryModules -Type Application
            $environments = Get-EnvironmentsFromStorage -StorageAccountContext $storageAccountContext -TableNameEnvironments $StorageTableNameEnvironments -TableNameDefaults $StorageTableNameEnvironmentDefaults -TypeFilter $TypeFilter -ConfigType Application -EnvironmentsOnly
            foreach ($environment in $environments) {
                if (Get-NavServerInstance -ServerInstance $environment.ServerInstance) {
                    Write-Verbose "Restarting service..."
                    Restart-NAVServerInstance -ServerInstance $environment.ServerInstance | Out-Null
                }
            }
        }
    }
}