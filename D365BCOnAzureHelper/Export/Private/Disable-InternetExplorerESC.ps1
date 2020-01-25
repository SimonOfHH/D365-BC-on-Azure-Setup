function Disable-InternetExplorerESC {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(
        [bool]
        $AdminOnly = $true
    )
    process {
        $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
        $val = Get-ItemProperty -Path $AdminKey -Name "IsInstalled"
        if ($val.IsInstalled -eq 0) {
            return
        }
        Write-Verbose "Disabling IE Enhanced Security Configuration (ESC)"
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0 -Force
        if (-not($AdminOnly)) {
            $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
            Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0 -Force
        }
        if (Get-Process -Name Explorer -ErrorAction SilentlyContinue) {
            Write-Verbose "Stopping Process 'Explorer' to apply settings"        
            Stop-Process -Name Explorer -Force
        }
        Write-Verbose "IE Enhanced Security Configuration (ESC) has been disabled."
    }
}