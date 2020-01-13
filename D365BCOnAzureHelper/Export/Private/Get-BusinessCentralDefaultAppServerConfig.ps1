# Will be called in VM
function Global:Get-BusinessCentralDefaultAppServerConfig {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(               
        [Parameter(Mandatory = $false)]
        [ValidateSet('13', '14', '15')]
        [string]
        $BusinessCentralVersion = '14',        
        [Parameter(Mandatory = $true)]
        [ref]
        $ComponentSettings,        
        [Parameter(Mandatory = $true)]
        [ref]
        $Parameters
    )
    process {
        switch ($BusinessCentralVersion) {
            '13' { $versionReplacement = '130' }
            '14' { $versionReplacement = '140' }
            '15' { $versionReplacement = '150' }
            Default { }
        }                 
        $ComponentSettings.Value = @(
            [pscustomobject]@{Id = "RoleTailoredClient"; State = "Local"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "ExcelAddin"; State = "Absent"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "ClassicClient"; State = "Local"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "ClickOnceInstallerTools"; State = "Local"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "NavHelpServer"; State = "Absent"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "WebClient"; State = "Absent"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "AutomatedDataCaptureSystem"; State = "Absent"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "OutlookAddIn"; State = "Absent"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "SQLServerDatabase"; State = "Absent"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "SQLDemoDatabase"; State = "Absent"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "ServiceTier"; State = "Local"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "Pagetest"; State = "Local"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "STOutlookIntegration"; State = "Absent"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "ServerManager"; State = "Local"; ShowOptionNode = "yes"; },
            [pscustomobject]@{Id = "DevelopmentEnvironment"; State = "Local"; ShowOptionNode = "yes"; }            
        )
        $Parameters.Value = @(
            [pscustomobject]@{Id = "TargetPath"; Value = "C:\Program Files (x86)\Microsoft Dynamics 365 Business Central\$versionReplacement"; IsHidden = $null; },
            [pscustomobject]@{Id = "TargetPathX64"; Value = "C:\Program Files\Microsoft Dynamics 365 Business Central\$versionReplacement"; IsHidden = $null; },
            [pscustomobject]@{Id = "NavServiceServerName"; Value = "localhost"; IsHidden = $null; },
            [pscustomobject]@{Id = "NavServiceInstanceName"; Value = "BC$versionReplacement"; IsHidden = $null; },
            [pscustomobject]@{Id = "NavServiceAccount"; Value = "NT AUTHORITY\NETWORK SERVICE"; IsHidden = $null; },
            [pscustomobject]@{Id = "NavServiceAccountPassword"; Value = ""; IsHidden = "yes"; },
            [pscustomobject]@{Id = "ServiceCertificateThumbprint"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "ManagementServiceServerPort"; Value = "7045"; IsHidden = $null; },
            [pscustomobject]@{Id = "ManagementServiceFirewallOption"; Value = "false"; IsHidden = $null; },
            [pscustomobject]@{Id = "NavServiceClientServicesPort"; Value = "7046"; IsHidden = $null; },
            [pscustomobject]@{Id = "WebServiceServerPort"; Value = "7047"; IsHidden = $null; },
            [pscustomobject]@{Id = "WebServiceServerEnabled"; Value = "false"; IsHidden = $null; },
            [pscustomobject]@{Id = "DataServiceServerPort"; Value = "7048"; IsHidden = $null; },
            [pscustomobject]@{Id = "DataServiceServerEnabled"; Value = "false"; IsHidden = $null; },
            [pscustomobject]@{Id = "DeveloperServiceServerPort"; Value = "7049"; IsHidden = $null; },
            [pscustomobject]@{Id = "DeveloperServiceServerEnabled"; Value = "true"; IsHidden = $null; },
            [pscustomobject]@{Id = "NavFirewallOption"; Value = "false"; IsHidden = $null; },
            [pscustomobject]@{Id = "CredentialTypeOption"; Value = "Windows"; IsHidden = $null; },
            [pscustomobject]@{Id = "DnsIdentity"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "ACSUri"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "SQLServer"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "SQLInstanceName"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "SQLDatabaseName"; Value = "Demo Database NAV ($BusinessCentralVersion-0)"; IsHidden = $null; },
            [pscustomobject]@{Id = "SQLReplaceDb"; Value = "FAILINSTALLATION"; IsHidden = $null; },
            [pscustomobject]@{Id = "SQLAddLicense"; Value = "true"; IsHidden = $null; },
            [pscustomobject]@{Id = "PostponeServerStartup"; Value = "false"; IsHidden = $null; },
            [pscustomobject]@{Id = "PublicODataBaseUrl"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "PublicSOAPBaseUrl"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "PublicWebBaseUrl"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "PublicWinBaseUrl"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "WebServerPort"; Value = "8080"; IsHidden = $null; },
            [pscustomobject]@{Id = "WebServerSSLCertificateThumbprint"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "WebClientRunDemo"; Value = "true"; IsHidden = $null; },
            [pscustomobject]@{Id = "WebClientDependencyBehavior"; Value = "install"; IsHidden = $null; },
            [pscustomobject]@{Id = "NavHelpServerPath"; Value = "[WIX_SystemDrive]\Inetpub\wwwroot"; IsHidden = $null; },
            [pscustomobject]@{Id = "NavHelpServerName"; Value = ""; IsHidden = $null; },
            [pscustomobject]@{Id = "NavHelpServerPort"; Value = "0"; IsHidden = $null; }
        )        
    }
}