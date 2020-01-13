function Global:Submit-ScriptToVmAndExecute {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
        Do not pass any secure-objects in $RunParameter (like SecureString for Passwords); these will cause to run indefinitely
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
        $VMName,
        [Parameter(Mandatory = $true)]        
        $ScriptBlock,
        [Parameter(Mandatory = $false)]
        $RunParameter,
        [Parameter(Mandatory = $false)]
        [string]
        $MsgBeforeExecuting,
        [Parameter(Mandatory = $false)]
        [switch]
        $ScaleSetExecution = $false
    )
    process {
        if ($MsgBeforeExecuting) {
            Write-Verbose $MsgBeforeExecuting
        }
        # Temporary save script-block as file
        $fullscriptpath = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'ps1' } -PassThru | Select-Object -ExpandProperty FullName
        Set-Content -Path $fullscriptpath -Value $ScriptBlock
        Write-Verbose "Running command on $VMName..."
        if (-not($ScaleSetExecution)) {
            Invoke-AzVMRunCommand -ResourceGroupName $ResourceGroupName -VMName $VMName -CommandId 'RunPowerShellScript' -ScriptPath $fullscriptpath -Parameter $RunParameter | Out-Null
        }
        else {
            foreach ($instance in Get-AzVmssVM -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMName) {
                $instanceId = $instance.InstanceId
            
                Write-Verbose "on Instance $instanceId..."
                Invoke-AzVmssVMRunCommand -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMName -InstanceId $instanceId -CommandId 'RunPowerShellScript' -ScriptPath $fullscriptpath -Parameter $RunParameter | Out-Null
            }
        }
        Write-Verbose "Command completed."
        Remove-Item $fullscriptpath -Force
    }
}