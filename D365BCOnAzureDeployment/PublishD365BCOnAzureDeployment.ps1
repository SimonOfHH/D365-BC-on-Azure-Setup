$VerbosePreference = "SilentlyContinue"
$VerbosePreference = "Continue"
# Version, Author, CompanyName and nugetkey
. (Join-Path $PSScriptRoot ".\Private\settings.ps1")

$moduleName = "D365BCOnAzureDeployment"
Clear-Host
#Invoke-ScriptAnalyzer -Path $PSScriptRoot -Recurse -Settings PSGallery -Severity Warning

Write-Verbose "Unblocking files"
Get-ChildItem -Path $PSScriptRoot -Recurse | % { Unblock-File -Path $_.FullName }

Write-Verbose "Removing existing module"
Remove-Module $moduleName -ErrorAction Ignore
Write-Verbose "Uninstalling existing module"
Uninstall-module $moduleName -ErrorAction Ignore

$path = "C:\temp\$moduleName"

if (Test-Path -Path $path) {
    Write-Verbose "Removing existing temp directory"
    Remove-Item -Path $path -Force -Recurse
}
Write-Verbose "Copying necessary files"
Copy-Item -Path $PSScriptRoot -Destination "C:\temp" -Exclude @("settings.ps1", ".gitignore", "README.md", "Publish$moduleName.ps1") -Recurse
Remove-Item -Path (Join-Path $path ".git") -Force -Recurse -ErrorAction SilentlyContinue
#Remove-Item -Path (Join-Path $path "Tests") -Force -Recurse

Write-Verbose "Importing module"
$modulePath = Join-Path $path "$moduleName.psm1"
Import-Module $modulePath -DisableNameChecking

#get-module -Name SetupD365Environment

#$functionsToExport = (get-module -Name $moduleName).ExportedFunctions.Keys | Sort-Object
#$aliasesToExport = (get-module -Name $moduleName).ExportedAliases.Keys | Sort-Object

Write-Verbose "Updating manifest"
Update-ModuleManifest -Path (Join-Path $path "$moduleName.psd1") `
                      -RootModule "$moduleName.psm1" `
                      -ModuleVersion $version `
                      -Author $author `
                      -CompanyName $CompanyName

Copy-Item -Path (Join-Path $path "$moduleName.psd1") -Destination $PSScriptRoot -Force
Write-Verbose "Publishing Module"
$VerbosePreference = "SilentlyContinue"
Publish-Module -Path $path -NuGetApiKey $powershellGalleryApiKey
$VerbosePreference = "Continue"
Remove-Item -Path $path -Force -Recurse