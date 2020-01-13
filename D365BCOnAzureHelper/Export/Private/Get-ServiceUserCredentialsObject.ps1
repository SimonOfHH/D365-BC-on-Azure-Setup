function Get-ServiceUserCredentialsObject {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Used to retrieve Service Account credentials from KeyVault
    .DESCRIPTION
        $KVIdentifier comes from the "Environments"-storage table (column: KVCredentialIdentifier)
        If specified the CmdLet will try to read the values from the KeyVault
        Example: 
            Storage Table
                KVCredentialIdentifier = "BC-App-Svc-TST"
            Key Vault:
                BC-App-Svc-TSTUsername = "<ServiceUserName>"
                BC-App-Svc-TSTPassword = "<ServiceUserPassword>"
    #>
    param(        
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $false)]
        [string]
        $KVIdentifier
    )
    process {        
        if ($KVIdentifier){
            Write-Verbose "Getting service-account credentials from KeyVault $KeyVaultName with Identifier $KVIdentifier..."
        } else {
            Write-Verbose "Getting service-account credentials from KeyVault $KeyVaultName..."
        }
        $domainName = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name 'DomainName').SecretValueText          
        if ($KVIdentifier) {
            $svcUserName = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "$($KVIdentifier)Username" -ErrorAction SilentlyContinue).SecretValueText
            $svcUserPass = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name "$($KVIdentifier)Password" -ErrorAction SilentlyContinue).SecretValueText            
        }
        if (($svcUserName) -and ($svcUserPass)){
            $svcUserName = "$domainName\$svcUserName"
        } else {
            $svcUserName = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name 'DomainAdminUsername').SecretValueText
            $svcUserPass = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name 'DomainAdminPassword').SecretValueText
            $svcUserName = "$domainName\$svcUserName"
        }        
        $credentialsObject = New-Object System.Management.Automation.PSCredential ($svcUserName, (ConvertTo-SecureString $svcUserPass -AsPlainText -Force))
        $credentialsObject
    }
}