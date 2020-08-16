# Will be called in VM
function Global:Wait-ForInstanceAvailability {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        This CmdLet will wait until the ScaleSet-Instance of this VM is in ProvisionigState 'Succeeded'
    .DESCRIPTION
        ...
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $false)]
        [switch]
        $IsScaleSet,
        [Parameter(Mandatory = $true)]
        [string]
        $ScaleSetName,
        [Parameter(Mandatory = $false)]
        [string]
        $NewInstanceMarkerFilename
    )
    process {
        Write-Verbose "Checking Instance-availability..."        
        $params = @{
            VMScaleSetName    = $ScaleSetName
            ResourceGroupName = $ResourceGroupName
        }
        if ($IsScaleSet -eq $true) {
            $ComputerName = $env:COMPUTERNAME
            if (-not([string]::IsNullOrEmpty($UpdatedComputerName))){
                $ComputerName = $UpdatedComputerName # Global Varioable from Properties.ps1
            }
            while ((Get-AzVmssVM @params | Where-Object { $_.OsProfile.ComputerName -eq $ComputerName }).ProvisioningState -ne "Succeeded") {        
                Write-Verbose "Waiting for Instance-availability (checking every 5 seconds)"
                Start-Sleep -Seconds 5
            } 
        }
        if ($NewInstanceMarkerFilename) {
            if (Test-Path $NewInstanceMarkerFilename) {
                Write-Verbose "New Instance indicator is set. Sleeping for 90 seconds, because there might be pending restarts"
                Start-Sleep -Seconds 90
            }
        }
        Write-Verbose "Instance is available."
    }
}