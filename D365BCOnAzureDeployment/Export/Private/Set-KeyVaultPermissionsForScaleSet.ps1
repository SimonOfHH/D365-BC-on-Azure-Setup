function Global:Set-KeyVaultPermissionsForScaleSet {
    [CmdletBinding()]
    param(        
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,        
        [Parameter(Mandatory = $false)]
        [string]
        $KeyVaultResourceGroup = $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string]
        $ScaleSetName
    )
    process {
        Write-Verbose "Setting KeyVault policies for $ScaleSetName on $KeyVaultName ..."
        $VMSS = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $ScaleSetName -ErrorAction SilentlyContinue
        if (-not($VMSS)){
            Write-Verbose "Scale Set $ScaleSetName does not exists. Stopping here."
            return
        }
        $keyVault = Get-AzKeyVault -ResourceGroupName $KeyVaultResourceGroup -VaultName $KeyVaultName -ErrorAction SilentlyContinue         
        if (-not($keyVault)) {
            Write-Verbose "KeyVault $KeyVaultName does not exists. Stopping here."
            return
        }
        Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -ResourceGroupName $KeyVaultResourceGroup -ObjectId $VMSS.Identity.PrincipalId -PermissionsToKeys get,list -PermissionsToSecrets get,list -PermissionsToCertificates get,list,getissuers,listissuers
        Write-Verbose "Done."
    }    
}