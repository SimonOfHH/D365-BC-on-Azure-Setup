# Will be called in VM
function Global:Get-MachineInstanceType {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [Parameter(Mandatory = $true)]
        $InfrastructureData        
    )
    process {        
        if ($env:computername.ToLower().StartsWith($infrastructureData.AppServerComputerNamePrefix.ToLower())){
            "Application"
        }
        if ($env:computername.ToLower().StartsWith($infrastructureData.WebserverComputerNamePrefix.ToLower())){
            "Web"
        }
        if ($infrastructureData.WebserverComputerNamePrefix.ToLower() -eq $infrastructureData.AppServerComputerNamePrefix.ToLower()){
            "Both"
        }
    }
}
