function Global:Wait-ForNewlyCreatedIdentity {
    [CmdletBinding()]
    param(
        $ResourceGroupName,
        $ObjectId
    )
    process {        
        $principal = $null
        while (-not($principal)){            
            $principal = Get-AzADServicePrincipal -ObjectId $ObjectId -ErrorAction SilentlyContinue
            if (-not($principal)){
                Write-Verbose "Waiting for availability of newly created identity... (Checking again in 2 seconds)"
                Start-Sleep -Seconds 2
            }            
        }
    }    
}