function Global:Set-CertificatePermissions {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $CertificateStorePath = "Cert:\LocalMachine\My",
        [Parameter(Mandatory = $false)]
        [string]
        $Username,
        [Parameter(Mandatory = $true)]
        [string]
        $CertificateThumbprint
    )
    if ($Username) {
        Write-Verbose "Setting Permissions for Certificate $CertificateThumbprint for '$Username' to 'Read'"
    } else {
        Write-Verbose "Setting Permissions for Certificate $CertificateThumbprint for all users to 'Read'"
    }
    
    $certificate = Get-ChildItem $CertificateStorePath | Where-Object thumbprint -eq $CertificateThumbprint
    
    if ($null -eq $certificate) {
        Write-Verbose "Certificate with thumbprint $CertificateThumbprint does not exist at $CertificateStorePath"
        exit 1;
    }
    else {
        $rsaCert = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
        $fileName = $rsaCert.key.UniqueName
        $path = "$env:ALLUSERSPROFILE\Microsoft\Crypto\Keys\$fileName"
        $permissions = Get-Acl -Path $path
    
        if ($Username) {
            $access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule("$Username", 'Read', 'None', 'None', 'Allow')
        }
        else {
            $access_rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Users", 'Read', 'None', 'None', 'Allow')
        }
        $permissions.AddAccessRule($access_rule)
        Set-Acl -Path $path -AclObject $permissions
    }
}