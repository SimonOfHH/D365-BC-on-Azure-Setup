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
        if ($env:computername.StartsWith($infrastructureData.AppServerComputerNamePrefix)){
            "Application"
        }
        if ($env:computername.StartsWith($infrastructureData.WebserverComputerNamePrefix)){
            "Web"
        }
    }
}
