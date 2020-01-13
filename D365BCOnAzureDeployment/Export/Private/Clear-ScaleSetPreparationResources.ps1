function Global:Clear-ScaleSetPreparationResources {
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
        [HashTable]
        $Tags
    )
    process {        
        if (-not(Get-AzResource -ResourceGroupName $ResourceGroupName -Tag $Tags -ErrorAction SilentlyContinue)){
            return
        }
        Write-Verbose "Cleaning up resources..."
        Write-Verbose "Removing VM..."
        Get-AzResource -ResourceGroupName $ResourceGroupName -Tag $Tags | Where-Object {$_.ResourceType -like 'Microsoft.Compute/virtualMachines'} | Remove-AzResource -Force | Out-Null
        Write-Verbose "Removing child-resources..."
        foreach ($resource in Get-AzResource -ResourceGroupName $ResourceGroupName -Tag $Tags){
            Write-Verbose "Removing $($resource.Name)..."
            $resource | Remove-AzResource -Force  | Out-Null
        }       
        Write-Verbose "Done."
    }
}