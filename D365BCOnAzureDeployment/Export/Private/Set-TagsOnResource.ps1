function Global:Set-TagsOnResource {
    <#
	.SYNOPSIS
	...
	
	.EXAMPLE
	...
	#>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceName,        
        [Parameter(Mandatory = $true)]
        [HashTable]
        $Tags
    )
    process {
        Write-Verbose "Adding Tags to Resource..."
        $Resource = Get-AzResource -ResourceGroupName $ResourceGroupName -Name $ResourceName
        #$Tags.GetEnumerator() | ForEach-Object { $Resource.Tags.Add($_.Key, $_.Value) }
        $Resource | Set-AzResource -Tag $Tags -Force  | Out-Null
        #$Resource | Set-AzResource -Force | Out-Null
        Write-Verbose "Done."
    }
}