#Get public and private function definition files.
$Public = @( Get-ChildItem -Path $PSScriptRoot\Export\Public\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Export\Private\*.ps1 -ErrorAction SilentlyContinue )

# Dot source the files
Foreach ($import in @($Public + $Private)) {
    Try {
        Write-Verbose "Importing $($import.fullname)"
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

Foreach ($import in $Public) {
    Write-Verbose "Exporting ModuleMember for $($import.Basename)"
    Export-ModuleMember -Function $import.Basename
}