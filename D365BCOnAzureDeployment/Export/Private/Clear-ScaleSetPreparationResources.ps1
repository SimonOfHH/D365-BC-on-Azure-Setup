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
        Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Compute/virtualMachines' | Where-Object {($null -ne $_.Tags) -and ((Compare-Hashtables $_.Tags $Tags) -eq $true)} | Remove-AzResource -Force | Out-Null
        Write-Verbose "Removing child-resources..."
        foreach ($resource in Get-AzResource -ResourceGroupName $ResourceGroupName | Where-Object {($null -ne $_.Tags) -and ((Compare-Hashtables $_.Tags $Tags) -eq $true) -and ($_.ResourceType -ne 'Microsoft.Compute/images')}) {
            Write-Verbose "Removing $($resource.Name)..."
            $resource | Remove-AzResource -Force  | Out-Null
        }       
        Write-Verbose "Done."
    }
}