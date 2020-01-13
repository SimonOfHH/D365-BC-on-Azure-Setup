function New-DemoSqlServer {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Creates a new SQL Server, for demonstration purposes
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
        $ImageName,
        [Parameter(Mandatory = $true)]
        [string]
        $ScaleSetName,
        [Parameter(Mandatory = $true)]
        [string]
        $VirtualNetworkName,
        [Parameter(Mandatory = $true)]
        [string]
        $SubnetName,
        $PrivateIpAddress,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $true)]
        [string]
        $VmAdminUserName,
        [Parameter(Mandatory = $true)]
        [string]
        $VmAdminPassword,
        [Parameter(Mandatory = $false)]
        [string]
        $VmSize,
        [int]
        [Parameter(Mandatory = $false)]
        $InstanceCount = 2,
        [Parameter(Mandatory = $false)]
        [object]
        $ResourceTags,
        [Parameter(Mandatory = $false)]
        [string]
        $TemplateFile,
        [Parameter(Mandatory = $false)]
        [string]
        $TemplateUri = "https://raw.githubusercontent.com/SimonOfHH/ARM-Templates/master/Templates/D365BCOnAzure/Demo-Sql-Server.json",
        [switch]
        $AsJob
    )
    $scriptBlock = {
        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Stop"

        $oldVerbosePreference = $VerbosePreference        
        $VerbosePreference = 'SilentlyContinue'
        Import-Module Az.Compute, Az.Resources, Az.KeyVault
        $VerbosePreference = 'Continue'
        
        # Needed if started as Job
        $args[0].GetEnumerator() | ForEach-Object {
            New-Variable -Name $_.Key -Value $_.Value
        }
        try {
            Write-Verbose "Validating that Scale Set does not exist yet"
            if (Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $ScaleSetName -ErrorAction SilentlyContinue) {
                Write-Verbose "Scale Set already exists. Exiting here."
                return
            }
            Write-Verbose "Validating that desired base image exists"
            $image = Get-AzImage -ResourceGroupName $resourceGroupName -ImageName $ImageName -ErrorAction SilentlyContinue
            if (-not($image)) {
                throw "Image $ImageName does not exist"
                return
            }

            Write-Verbose "Retrieving Domain-Join values from KeyVault"
            $domainAdminUserName = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name 'DomainAdminUsername').SecretValueText
            $domainAdminUserPass = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name 'DomainAdminPassword').SecretValueText
            $domainName = (Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name 'DomainName').SecretValueText

            $vmssSettings = @{
                VmSsName            = $ScaleSetName
                VmSize              = $VmSize
                InstanceCount       = "$InstanceCount"
                VmAdminUserName     = $VmAdminUserName
                VmAdminPassword     = $VmAdminPassword
                BaseImageId         = $image.Id
                VirtualNetworkName  = $VirtualNetworkName
                SubnetName          = $SubnetName
                DomainName          = $domainName
                DomainAdminUsername = "$domainName\$domainAdminUserName"
                DomainAdminPassword = $domainAdminUserPass
            }
            $deployParams = @{
                Name                    = "$ScaleSetName-deploy"
                ResourceGroupName       = $ResourceGroupName
                TemplateParameterObject = $vmssSettings
            }
            if ($TemplateFile) {
                $deployParams.Add("TemplateFile", $TemplateFile)
            }
            else {
                if ($TemplateUri) {
                    $deployParams.Add("TemplateUri", $TemplateUri)
                }
            }
            New-AzResourceGroupDeployment @deployParams | Out-Null
        } catch {

        }
        $VerbosePreference = $oldVerbosePreference
        $ErrorActionPreference = $oldErrorActionPreference
    }

    $params = Get-FunctionParameters $MyInvocation
    
    if ($AsJob) {            
        #Start-Job -ScriptBlock $scriptBlock -InitializationScript { Import-Module D365BCOnAzureDeployment -Force } -ArgumentList $params
        Start-Job -ScriptBlock $scriptBlock -ArgumentList $params
    }
    else {
        Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $params
    }
}