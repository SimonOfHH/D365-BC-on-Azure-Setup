function New-StandAloneServer {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        Creates a new Application Server, installs Business Central, sys-preps it and saves it as an image
    .DESCRIPTION
        This CmdLet will create a new VM, initialize it (install this and other modules to it), download the desired Business Central DVD and install it locally.
        Afterwards it will generalize the created VM and set it as an Image to be used for future ScaleSets
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceGroupName,        
        [Parameter(Mandatory = $true)]
        [string]
        $ResourceLocation,
        [Parameter(Mandatory = $false)]
        [string]
        $ImageResourceGroupName = $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $ImageName,
        [Parameter(Mandatory = $false)]
        [string]
        $VirtualNetworkResourceGroup,
        [Parameter(Mandatory = $false)]
        [string]
        $StorageAccountType,
        [Parameter(Mandatory = $true)]
        [string]
        $VirtualMachineName,        
        [Parameter(Mandatory = $false)]
        [string]
        $StorageAccountResourceGroupName = $ResourceGroupName,
        [Parameter(Mandatory = $false)]
        [string]
        $StorageAccountName,
        [Parameter(Mandatory = $true)]
        [string]
        $VirtualNetworkName,
        [Parameter(Mandatory = $true)]
        [string]
        $SubnetName,
        $PrivateIpAddress,
        [Parameter(Mandatory = $false)]
        [string]
        $KeyVaultResourceGroupName = $ResourceGroupName,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyVaultName,
        [Parameter(Mandatory = $false)]
        [string]
        [Alias("Version")]
        $BCVersion,
        [Parameter(Mandatory = $false)]
        [string]
        [Alias("CumulativeUpdate")]
        $BCCumulativeUpdate,
        [Parameter(Mandatory = $false)]
        [string]
        [Alias("Language")]
        $BCLanguage,
        [Parameter(Mandatory = $true)]
        [string]
        $VmAdminUserName,
        [Parameter(Mandatory = $true)]
        [string]
        $VmAdminPassword,
        [Parameter(Mandatory = $false)]
        [string]
        $VmSize,
        [Parameter(Mandatory = $false)]
        [string]
        $VmOperatingSystem,
        [Parameter(Mandatory = $true)]
        [ValidateSet('App', 'Web', 'Both')]
        [string]
        $InstallationType,
        [Parameter(Mandatory = $false)]
        [HashTable]
        $Tags,
        [switch]
        $AsJob
    ) 
    $scriptBlock = {
        $VM = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -ErrorAction SilentlyContinue
        if ($VM){
            Write-Verbose "VM $VirtualMachineName already exists. Stopping here."
            return
        }
        $oldErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "Stop"

        $oldVerbosePreference = $VerbosePreference
        $VerbosePreference = 'SilentlyContinue'
        Import-Module Az.Compute, Az.Resources
        $VerbosePreference = 'Continue'
        
        # Needed if started as Job
        $args[0].GetEnumerator() | ForEach-Object {
            New-Variable -Name $_.Key -Value $_.Value
        }
        
        Write-Verbose "Checking if Image $ImageName already exists"
        $image = Get-AzImage -ResourceGroupName $ImageResourceGroupName -ImageName $ImageName -ErrorAction SilentlyContinue
        if (-not($image)) {                        
            Write-Verbose "Image $ImageName does not exist. Exiting here."
            return
        }        
        Write-Verbose "Starting Image creation for $ImageName"

        try {
            # Copy necessary parameters to new HashTable; this will be used inside the Parameters for the upcoming New-AzResourceGroupDeployment
            $paramsObject = @{ }        
            foreach ($var in $args[0].GetEnumerator()) {
                if ($var.Key -notin @('ResourceGroupName', 'ResourceLocation', 'ImageName', 'TemplateFile', 'TemplateUri', 'AsJob', 'DoNotGeneralize')) {
                    $paramsObject.Add($var.Key, $var.Value)
                }
            }
            $VmAdminPasswordSecured = ConvertTo-SecureString $VmAdminPassword -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ($VmAdminUserName, $VmAdminPasswordSecured);

            $VNet = Get-AzVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $VirtualNetworkResourceGroup
            $Subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $VNet            
            $NIC = New-AzNetworkInterface -Name "$($VirtualMachineName)_Nic_01" -ResourceGroupName $ResourceGroupName -Location $ResourceLocation -Subnet $Subnet -IpConfigurationName "IPConfig1" -Tag $Tags

            $VirtualMachine = New-AzVMConfig -VMName $VirtualMachineName -VMSize $VmSize -IdentityType SystemAssigned -Tag $Tags
            $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VirtualMachineName -Credential $Credential -ProvisionVMAgent
            $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
            $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -Id $image.Id
            $VirtualMachine = Set-AzVMOSDisk -VM $VirtualMachine -Name "$($VirtualMachineName)_OsDisk_01" -CreateOption FromImage -DiskSizeInGB 128 -StorageAccountType StandardSSD_LRS

            $vm = New-AzVM -ResourceGroupName $ResourceGroupName -Location $ResourceLocation -VM $VirtualMachine -Verbose:$Verbose
            $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName

            Wait-ForNewlyCreatedIdentity -ResourceGroupName $ResourceGroupName -ObjectId $vm.Identity.PrincipalId -Verbose:$Verbose
            Write-Verbose "Assigning role 'Reader' on Resource Group-level..."
            New-AzRoleAssignment -ObjectId $vm.Identity.PrincipalId -RoleDefinitionName "Reader" -ResourceGroupName $ResourceGroupName | Out-Null        
            Write-Verbose "Assigning role 'Contributor' on Storage Account-level..."
            New-AzRoleAssignment -ObjectId $vm.Identity.PrincipalId -RoleDefinitionName "Contributor" -ResourceGroupName $StorageAccountResourceGroupName -ResourceName (Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroupName -Name $StorageAccountName | Select-Object -First 1).StorageAccountName -ResourceType "Microsoft.Storage/storageAccounts" | Out-Null

            Set-KeyVaultPermissionsForVM -ResourceGroupName $ResourceGroupName -KeyVaultResourceGroup $KeyVaultResourceGroupName -KeyVaultName $KeyVaultName -VMName $VirtualMachineName -Verbose
        }
        catch {
            Write-Error $_
        }
        $VerbosePreference = $oldVerbosePreference
        $ErrorActionPreference = $oldErrorActionPreference
    }
    $params = Get-FunctionParameters $MyInvocation
    
    if ($AsJob) {            
        Start-Job -ScriptBlock $scriptBlock -InitializationScript { Import-Module D365BCOnAzureDeployment -Force } -ArgumentList $params
    }
    else {
        Invoke-Command -ScriptBlock $scriptBlock -ArgumentList $params
    }
}