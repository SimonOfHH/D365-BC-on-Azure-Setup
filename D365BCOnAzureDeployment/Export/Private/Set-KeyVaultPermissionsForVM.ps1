function Global:Set-KeyVaultPermissionsForVM {
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
        $VMName
    )
    process {
        Write-Verbose "Setting KeyVault policies for $ScaleSetName on $KeyVaultName ..."
        $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -ErrorAction SilentlyContinue
        if (-not($VM)){
            Write-Verbose "Scale Set $ScaleSetName does not exists. Stopping here."
            return
        }
        $keyVault = Get-AzKeyVault -ResourceGroupName $KeyVaultResourceGroup -VaultName $KeyVaultName -ErrorAction SilentlyContinue         
        if (-not($keyVault)) {
            Write-Verbose "KeyVault $KeyVaultName does not exists. Stopping here."
            return
        }
        Set-AzKeyVaultAccessPolicy -VaultName $KeyVaultName -ResourceGroupName $KeyVaultResourceGroup -ObjectId $VM.Identity.PrincipalId -PermissionsToKeys get,list -PermissionsToSecrets get,list -PermissionsToCertificates get,list,getissuers,listissuers
        Write-Verbose "Done."
    }    
}