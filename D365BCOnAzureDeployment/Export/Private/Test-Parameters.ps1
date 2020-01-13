function Global:Test-Parameters {
    [CmdletBinding()]
    param(
        $ResourceGroupName,
        $ObjectID,
        $SubscriptionName,
        $KeyVaultName,
        $StorageAccountName
    )
    process {
        $somethingmissing = $false
        $optionalMissing = $false
        Write-Verbose "Validating Parameters"
        if (-not($ObjectID)) {
            Write-Verbose "Missing Parameter: `$ObjectID"
            Write-Verbose "     Obtain it by using Get-AzADUser and search for your User"
            $somethingmissing = $true
        }
        if (-not($KeyVaultName)) {
            Write-Verbose "Missing Parameter: `$KeyVaultName"            
            $somethingmissing = $true
        }
        else {
            $keyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName -ErrorAction SilentlyContinue
            if (-not($keyVault)) {
                $StatusCode = $null
                $uri = "https://$($KeyVaultName).vault.azure.net"
                try {
                    $response = invoke-WebRequest -Uri $Uri -ErrorAction Stop
                    $StatusCode = $Response.StatusCode
                }
                catch [System.Net.WebException] { 
                    $StatusCode = $_.Exception.Response.StatusCode.value__    
                }
                if ($null -ne $StatusCode) {
                    throw "KeyVaultName $KeyVaultName is already in use."
                }
            }
        }
        if (-not($StorageAccountName)) {
            Write-Verbose "Missing Parameter: `$StorageAccountName"            
            $somethingmissing = $true
        }
        else {
            $storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ErrorAction SilentlyContinue
            if (-not($storageAccount)) {
                $StatusCode = $null
                $uri = "https://$($StorageAccountName).blob.core.windows.net/"
                try {
                    $response = invoke-WebRequest -Uri $Uri -ErrorAction Stop
                    $StatusCode = $Response.StatusCode
                }
                catch [System.Net.WebException] { 
                    $StatusCode = $_.Exception.Response.StatusCode.value__    
                }
                if ($null -ne $StatusCode) {
                    throw "StorageAccount name $StorageAccountName is already in use."
                }
            }
        }
        if (-not($SubscriptionName)) {
            Write-Verbose "Missing Parameter: `$SubscriptionName"
            Write-Verbose "     This one is optional, but make sure that you're connected to the correct subscription"
            Write-Verbose "     Currently used subscription is: $((Get-AzContext).Subscription.Name)"
            $optionalMissing = $true
        }
        Write-Verbose "Parameters validated."
        if ($somethingmissing) {
            return $false
        }
        else {
            return $true
        }
    }    
}