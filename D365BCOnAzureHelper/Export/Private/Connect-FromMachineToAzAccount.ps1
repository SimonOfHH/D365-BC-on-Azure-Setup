# Will be called in VM
function Global:Connect-FromMachineToAzAccount {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        This CmdLet assumes that the VM/VMSS-instance has an active managed identity
    .DESCRIPTION
        ...
    #>
    param()
    process {
        Write-Verbose "Trying to connect to Azure account..."
        # Get Access Token from Microsoft Managed Identity Endpoint
        $response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -Headers @{Metadata = "true" } -UseBasicParsing

        # Read response and assign variables
        $content = $response.Content | ConvertFrom-Json
        $AccessToken = $content.access_token
        $ClientId = $content.client_id

        # Connect Account
        Connect-AzAccount -AccessToken $AccessToken -AccountId $ClientId  | Out-Null

        # Get KeyVault-Token
        $response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net' -Headers @{Metadata="true"} -UseBasicParsing
        $content = $response.Content | ConvertFrom-Json
        $AccessTokenKeyVault = $content.access_token

        Add-AzAccount -KeyVaultAccessToken $AccessTokenKeyVault -AccessToken $AccessToken -AccountId $ClientId | Out-Null

        Write-Verbose "Connected."
    }
}