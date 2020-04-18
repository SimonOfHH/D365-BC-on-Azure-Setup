function Global:Import-NecessaryModules {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Application', 'Web')]
        [string]
        $Type = "Application"
    )
    # Avoid "Verbose"-output of importing modules (blows up the log files)
    $oldVerbosePreference = $VerbosePreference
    switch ($Type) {
        "Application" {
            Write-Verbose "Importing Cloud.Ready.Software.NAV..."
            $VerbosePreference = 'SilentlyContinue'
            Import-Module Cloud.Ready.Software.NAV -Force
            $VerbosePreference = $oldVerbosePreference
            Write-Verbose "Importing NAV Modules..."
            $VerbosePreference = 'SilentlyContinue'
            Import-NAVModules
        }
        "Web" { 
            # On the WebServer-VM there is no complete NAV/BC installation, so we need to only load the relevant WebClient-module
            Write-Verbose "Importing NAV Modules..."
            $VerbosePreference = 'SilentlyContinue'
            $path = "C:\Program Files\Microsoft Dynamics *\*\Web Client\Modules\NAVWebClientManagement\NAVWebClientManagement.psm1"
            $modulePath = (Get-ChildItem -Path $path | Select-Object -First 1).FullName
            Import-Module -Name $modulePath
            Import-Module WebAdministration
        }
    }
    $VerbosePreference = $oldVerbosePreference
}