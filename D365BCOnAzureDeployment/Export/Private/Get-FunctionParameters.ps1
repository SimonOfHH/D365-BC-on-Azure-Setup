function Global:Get-FunctionParameters {
    <#
	.SYNOPSIS
	This is a function that will create a HashTable of all Parameters from another function-call
	
	.EXAMPLE
	PS> Get-FunctionParameters $MyInvocation
	
	.PARAMETER MyPreviousInvocation
	A mandatory parameter representing the PS builtin variable $MyInvocation
	
	#>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $MyPreviousInvocation
    )
    try {
        $ht = @{ }
        $ParameterList = $MyPreviousInvocation.MyCommand.Parameters
        foreach ($key in $ParameterList.keys) {
            $var = Get-Variable -Name $key -ErrorAction SilentlyContinue;
            if ($var) {
                $ht[$var.Name] = $var.Value
            }
        }
		$ht
    }
    catch {
        Write-Error -Message $_.Exception.Message
    }
}
