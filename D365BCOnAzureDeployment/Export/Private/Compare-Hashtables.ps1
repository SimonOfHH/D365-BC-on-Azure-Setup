Function Global:Compare-Hashtables {
    [CmdletBinding()]
    [OutputType([boolean])]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $HashtableA,
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $HashtableB
    )
    process{
        foreach($pairA in $HashtableA.GetEnumerator()){
            if (-not($HashtableB.ContainsKey($pairA.Key))){
                $false
                return
            } else {
                if ($HashtableB[$pairA.Key] -ne $pairA.Value){
                    $false
                    return
                }
            }
        }
        foreach($pairB in $HashtableB.GetEnumerator()){
            if (-not($HashtableA.ContainsKey($pairB.Key))){
                $false
                return
            } else {
                if ($HashtableA[$pairB.Key] -ne $pairB.Value){
                    $false
                    return
                }
            }
        }
        $true
    }
}