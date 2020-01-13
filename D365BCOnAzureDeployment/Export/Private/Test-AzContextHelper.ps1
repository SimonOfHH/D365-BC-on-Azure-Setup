function Global:Test-AzContextHelper {
    [CmdletBinding()]
    param()
    process {
        Write-Verbose "Checking for active Azure Connection..."        
        if (-not(Get-AzContext -ErrorAction SilentlyContinue)) {
            Write-Verbose "No active AzContext found. Initiating Connect-AzAccount"
            Connect-AzAccount -Force | Out-Null
        }
        if ($subscriptionName) {            
            $connected = (Get-AzContext).Subscription.Name -eq $subscriptionName
            if (-not($connected)) {    
                Write-Verbose "Selecting correct subscription..."
                if (-not(Get-AzSubscription -SubscriptionName $subscriptionName -ErrorAction SilentlyContinue)) {
                    Write-Verbose "Subscription '$subscriptionName' does not exist in current context. Initiating Connect-AzAccount"
                    Connect-AzAccount -Force | Out-Null
                    if (-not(Get-AzSubscription -SubscriptionName $subscriptionName -ErrorAction SilentlyContinue)) {
                        Write-Verbose "Still couldn't find subscription '$subscriptionName'. Exiting here"
                        throw "Invalid subscription given"                            
                    }
                }
                else {
                    $context = Get-AzSubscription -SubscriptionName $subscriptionName
                    Set-AzContext $context | Out-Null
                }                
            }
        }
        Write-Verbose "Connected. Currently used subscription is: $((Get-AzContext).Subscription.Name)"
    }    
}