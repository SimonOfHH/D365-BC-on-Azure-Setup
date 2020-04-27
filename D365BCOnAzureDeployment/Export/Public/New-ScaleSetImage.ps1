function New-ScaleSetImage {
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
        [Parameter(Mandatory = $true)]
        [string]
        $ScaleSetName,
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
        [ValidateSet('App', 'Web')]
        [string]
        $InstallationType,
        [Parameter(Mandatory = $false)]
        [object]
        $ResourceTags,
        [Parameter(Mandatory = $false)]
        [string]
        $TemplateFile,
        [Parameter(Mandatory = $false)]
        [string]
        $TemplateUri = "https://raw.githubusercontent.com/SimonOfHH/ARM-Templates/master/Templates/D365BCOnAzure/VM-for-Image-Prep.json",
        [switch]
        $DoNotGeneralize,
        [switch]
        $AsJob
    )    
    $scriptBlock = {
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
        $image = Get-AzImage -ResourceGroupName $ResourceGroupName -ImageName $ImageName -ErrorAction SilentlyContinue
        if ($image) {                        
            Write-Verbose "Image $ImageName already exists. Exiting here."
            return
        }
        if (-not($TemplateFile) -and (-not($TemplateUri))) {
            Write-Error "You need to either specify 'TemplateFile'- or 'TemplateUri'-parameter"
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
            # These are the actual parameters for the resource group deployment; contains the HashTable from above
            $deployParams = @{
                Name                    = "$ImageName-deploy"
                ResourceGroupName       = $ResourceGroupName
                TemplateParameterObject = $paramsObject
            }
            if ($TemplateFile) {
                $deployParams.Add("TemplateFile", $TemplateFile)
            }
            else {
                if ($TemplateUri) {
                    $deployParams.Add("TemplateUri", $TemplateUri)
                }
            }
            Write-Verbose "Starting AzResourceGroupDeployment..."        
            New-AzResourceGroupDeployment @deployParams | Out-Null
            Write-Verbose "Done"
            
            if ($DoNotGeneralize){
                return
            }

            Write-Verbose "Sleeping for 60 seconds, to avoid weird effects $($VirtualMachineName) $(Get-Date -Format "HH:mm:ss")"
            Start-Sleep -Seconds 60
            Write-Verbose "Done Sleeping"

            Write-Verbose "Removing existing Custom Script Extensions..."
            if (Get-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VirtualMachineName -Name "CustomScriptExtension" -ErrorAction SilentlyContinue) {
                Remove-AzVMCustomScriptExtension -ResourceGroupName $ResourceGroupName -VMName $VirtualMachineName -Name "CustomScriptExtension" -Force -Verbose | Out-Null
            }
            Write-Verbose "Done"
            
            Write-Verbose "Sleeping for 60 seconds, to avoid weird effects $($VirtualMachineName) $(Get-Date -Format "HH:mm:ss")"
            Start-Sleep -Seconds 60
            Write-Verbose "Done Sleeping"
            # Needed to have this outside the Init-Scripts, because "Remove-AzVMCustomScriptExtension" otherwise might fail
            # Also needed to add "Remove-AzVMCustomScriptExtension", because VM-generation from Image failed sometimes otherwise
            $scriptBlock = {
                Write-Verbose "Generalizing VM. "
                Write-Verbose "About to call 'Sysprep.exe /generalize /oobe /shutdown /quiet'"
                $sysprep = 'C:\Windows\System32\Sysprep\Sysprep.exe'
                $arg = '/generalize /oobe /shutdown'
                Start-Process -FilePath $sysprep -ArgumentList $arg    
            }        
            $executionParams = @{
                ResourceGroupName  = $ResourceGroupName 
                ResourceLocation   = $ResourceLocation 
                VMName             = $VirtualMachineName 
                ScriptBlock        = $scriptBlock
                MsgBeforeExecuting = "Calling sysprep on VM"
            }
            Submit-ScriptToVmAndExecute @executionParams

            # The previous script might already be finished, but sysprepping may take a moment. VM will be shut down when it's done, so check status
            Wait-ForVMShutdown -ResourceGroupName $ResourceGroupName -VMName $VirtualMachineName -Verbose:$Verbose
        
            Write-Verbose "Deallocating VM..."
            Stop-AzVm -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -Force | Out-Null

            Write-Verbose "Generalizing VM..."
            Set-AzVM -ResourceGroupName $ResourceGroupName -Name $VirtualMachineName -Generalized | Out-Null

            Write-Verbose "Preparing VM-image..."
            $vm = Get-AzVM -Name $VirtualMachineName -ResourceGroupName $ResourceGroupName
            $image = New-AzImageConfig -Location $ResourceLocation -SourceVirtualMachineId $vm.ID -Tags $ResourceTags
            New-AzImage -Image $image -ImageName $ImageName -ResourceGroupName $ResourceGroupName | Out-Null
            if ($ResourceTags) {
                Set-TagsOnResource -ResourceGroupName $ResourceGroupName -ResourceName $ImageName -Tags $ResourceTags
            }
            Write-Verbose "Done."

            Clear-ScaleSetPreparationResources -ResourceGroupName $ResourceGroupName -Tag $ResourceTags -Verbose:$Verbose
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