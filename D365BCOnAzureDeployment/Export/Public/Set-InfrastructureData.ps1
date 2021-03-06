function Set-InfrastructureData {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(        
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,        
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceLocation,        
        [Parameter(Mandatory = $true)]
        [string]
        $LoadBalancerName,
        [Parameter(Mandatory = $false)]
        [string]
        $AppScaleSetName,
        [Parameter(Mandatory = $false)]
        [string]
        $WebScaleSetName,
        [Parameter(Mandatory = $false)]
        [string]
        $StorageAccountResourceGroup = $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $TableNameInfrastructure,
        [Parameter(Mandatory = $false)]
        [string]
        $TypeFilter
    )
    process {
        Write-Verbose "Updating Infrastructure table..."
        $loadBalancer = Get-AzLoadBalancer -ResourceGroupName $ResourceGroupName -Name $LoadBalancerName -ErrorAction Stop        
        $loadBalancerIpAddress = $loadBalancer.FrontendIpConfigurations.PrivateIpAddress
        $appScaleSetPrefix = ""
        if ($AppScaleSetName) {
            $vmss = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $AppScaleSetName -ErrorAction SilentlyContinue
            $appScaleSetPrefix = $vmss.VirtualMachineProfile.OsProfile.ComputerNamePrefix
        }
        $webScaleSetPrefix = ""
        if ($WebScaleSetName) {
            $vmss = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $WebScaleSetName -ErrorAction SilentlyContinue
            $webScaleSetPrefix = $vmss.VirtualMachineProfile.OsProfile.ComputerNamePrefix
        }
        $storageAccount = Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroup -Name $StorageAccountName
        $storageAccountContext = $storageAccount.Context
        $storageAccountTable = Get-AzStorageTable -Name $TableNameInfrastructure -Context $storageAccountContext
        $cloudTable = $storageAccountTable.CloudTable
        if (-not([string]::IsNullOrEmpty($TypeFilter))) {
            $row = Get-AzTableRow -Table $cloudTable | Select-Object -First 1
        } else {
            $row = Get-AzTableRow -Table $cloudTable | Where-Object { ($_.Type -eq $TypeFilter) }
            if (-not($row)) {
                $row = Get-AzTableRow -Table $cloudTable | Select-Object -First 1
            }
        }        
        $row.ApplicationServerLoadBalancerIP = $loadBalancerIpAddress
        $row.AppServerComputerNamePrefix = $appScaleSetPrefix
        $row.WebServerComputerNamePrefix = $webScaleSetPrefix
        $row | Update-AzTableRow -table $cloudTable | Out-Null
    }    
}