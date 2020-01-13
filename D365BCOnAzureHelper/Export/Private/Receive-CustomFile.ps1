# Will be called in VM
function Global:Receive-CustomFile {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(        
        [Parameter(Mandatory = $false, Position = 1)]
        [string]
        $URI,
        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $DestinationFile
    )
    if (Test-Path $DestinationFile) {
        Remove-Item $DestinationFile -Force
    }
    $ParentDirectory = Split-Path $DestinationFile -Parent
    if (-not (Test-Path $ParentDirectory)){
        New-Item -Path $ParentDirectory -ItemType Directory
    }
    Write-Verbose "Download file..."
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($URI, $DestinationFile)
    Write-Verbose "File $(Split-Path $DestinationFile -Leaf) downloaded."
}