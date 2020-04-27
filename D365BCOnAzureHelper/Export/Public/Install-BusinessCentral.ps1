# Will be called in VM
function Install-BusinessCentral {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(        
        [Parameter(Mandatory = $false)]
        [string]
        $DownloadDirectory = "C:\Install\DVD",
        [Parameter(Mandatory = $false)]
        [string]
        $ConfigurationFile,
        [Parameter(Mandatory = $false)]
        [string]
        $LicenseFilename,
        [ValidateSet('App', 'Web', 'Both')]
        [Parameter(Mandatory = $false)]
        [string]
        $InstallationType = "App",
        [Parameter(Mandatory = $false)]
        [ValidateSet('13', '14', '15')]
        [string]
        $Version,
        [Parameter(Mandatory = $false)]
        [PSCredential]
        $VMCredentials
    )

    # Check prerequisities
    if (-not (Get-Module -Name Cloud.Ready.Software.NAV)) {
        Write-Verbose "Importing Module Cloud.Ready.Software.NAV" 
        Import-Module Cloud.Ready.Software.NAV -Force -Verbose:$false -DisableNameChecking -WarningAction SilentlyContinue
    }

    $setupFilename = Join-Path $DownloadDirectory 'setup.exe'
    if (-not(Test-Path $setupFilename)) {
        throw "$setupFilename doesn not exist. Make sure that 'DownloadDirectory' contains the path to the extracted DVD."
    }

    # Create Default Configuration if file was not given
    if ([string]::IsNullOrEmpty($ConfigurationFile)) {
        $configArgs = @{        
        }
        if (-not([string]::IsNullOrEmpty($InstallationType))) {
            $configArgs.Add('InstallationType', $InstallationType)
        }
        if (-not([string]::IsNullOrEmpty($Version))) {
            $configArgs.Add('BusinessCentralVersion', $Version)
        }
        if (-not([string]::IsNullOrEmpty($DownloadDirectory))) {
            $FileDirectory = Split-Path $DownloadDirectory -Parent
            $configArgs.Add('FileDirectory', $FileDirectory)
        }
        $ConfigurationFile = Get-BusinessCentralDefaultInstallConfig @configArgs        
    }

    # Check if it's necessary to download the config-file
    if (-not(Test-Path $ConfigurationFile)) {
        $DestinationFilename = Join-Path (Split-Path $DownloadDirectory -Parent) (Split-Path $ConfigurationFile -Leaf)
        Download-CustomFile -URI $ConfigurationFile -DestinationFile $DestinationFilename
        $ConfigurationFile = $DestinationFilename
    }

    # Start Install
    $LogPath = Join-Path (Split-Path $DownloadDirectory -Parent) '\Log\NavInstallLog.txt'

    $psexecPath = "C:\ProgramData\chocolatey\lib\sysinternals\tools\PsExec.exe"
    if (Test-Path $psexecPath){
        Write-Verbose "Starting Install via PsExec..."
        $VmAdminUser = $VMCredentials.GetNetworkCredential().UserName
        $VmAdminPass = $VMCredentials.GetNetworkCredential().Password
        & $psexecPath -h -u $VmAdminUser -p $VmAdminPass -accepteula cmd /c "$($setupFilename) "/config "$($ConfigurationFile)" /Log "$($LogPath)" /quiet"" 2> $null
    } else {
        Write-Verbose "Starting Install directly..."
        Install-NAV -DVDFolder $DownloadDirectory -Configfile $ConfigurationFile -LicenseFile $LicenseFilename -Log $LogPath
    }
}