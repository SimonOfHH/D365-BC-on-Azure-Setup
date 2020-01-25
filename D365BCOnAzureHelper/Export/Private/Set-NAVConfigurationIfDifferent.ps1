function Global:Set-NAVConfigurationIfDifferent {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $ServerInstance,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyName,
        [Parameter(Mandatory = $true)]
        [string]
        $KeyValue,
        [Parameter(Mandatory = $true)]
        [Hashtable]
        $CurrentConfiguration
    )
    process {
        if ($CurrentConfiguration[$KeyName].ToString() -ne $KeyValue.ToString()) {
            if ($Verbose) {
                Write-Verbose "Updating setting:"
                Write-Verbose "         Instance: $ServerInstance"
                Write-Verbose "          Setting: $KeyName"
                Write-Verbose "        Old Value: $($CurrentConfiguration[$KeyName].ToString())"
                Write-Verbose "        New Value: $($KeyValue.ToString())"
            }
            Set-NAVServerConfiguration -ServerInstance $ServerInstance -KeyName $KeyName -KeyValue $KeyValue            
            $true
        }
        else {
            $false
        }
    }
}