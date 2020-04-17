function Global:Wait-ForVMShutdown {
    [CmdletBinding()]
    param(
        $ResourceGroupName,
        $VMName
    )
    process {        
        $VMShutdown = $false
        while (-not $VMShutdown) {
            Write-Verbose "Sleeping for 5 seconds, waiting for VM to shutdown $($VMName) $(Get-Date -Format "HH:mm:ss")..."
            Start-Sleep -Seconds 10  
            $statusCode = (Get-AzVM -ResourceGroupName $ResourceGroupName  -Name $VMName -Status).Statuses[1].Code
            $VMShutdown = ($statusCode -eq "PowerState/deallocated") -or ($statusCode -eq "PowerState/stopped")
        }        
    }    
}