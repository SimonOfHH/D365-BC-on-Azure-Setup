# Will be called in VM
function Global:Get-BusinessCentralDefaultInstallConfig {
    [CmdletBinding()]
    <#
    .SYNOPSIS
        ...
    .DESCRIPTION
        ...
    #>
    param(       
        [Parameter(Mandatory = $false)]
        [ValidateSet('App', 'Web')]
        [string]
        $InstallationType = 'App',
        [Parameter(Mandatory = $false)]
        [ValidateSet('13', '14', '15')]
        [string]
        $BusinessCentralVersion = '14',
        [Parameter(Mandatory = $false)]        
        [string]
        $FileDirectory = 'C:\Install\'
    )
    process {
        # TODO: Add config for webclient / Validate config
        
        # Set The Formatting
        $xmlsettings = New-Object System.Xml.XmlWriterSettings
        $xmlsettings.Indent = $true
        $xmlsettings.IndentChars = "    "

        $filename = "$FileDirectory\InstallConfig.$(get-date -format yyyyMMddhhmmss).xml"
        # Set the File Name Create The Document
        $XmlWriter = [System.XML.XmlWriter]::Create($filename, $xmlsettings)

        # Write the XML Decleration and set the XSL
        $xmlWriter.WriteStartDocument()

        $componentSettings = @()
        $parameters = @()

        if ($InstallationType -eq 'App') { # Default Application Server config
            Get-BusinessCentralDefaultAppServerConfig -BusinessCentralVersion $BusinessCentralVersion -ComponentSettings ([ref]$componentSettings) -Parameters ([ref]$parameters)
                        
        } else { # Default Web Server config
            Get-BusinessCentralDefaultWebServerConfig -BusinessCentralVersion $BusinessCentralVersion -ComponentSettings ([ref]$componentSettings) -Parameters ([ref]$parameters)            
        }
        
        # Start the Root Element
        $xmlWriter.WriteStartElement("Configuration")

        foreach ($componentSetting in $componentSettings) {
            $xmlWriter.WriteStartElement("Component")
            $XmlWriter.WriteAttributeString("Id", $componentSetting.Id)
            $XmlWriter.WriteAttributeString("State", $componentSetting.State)
            $XmlWriter.WriteAttributeString("ShowOptionNode", $componentSetting.ShowOptionNode)
            $xmlWriter.WriteEndElement()
        }
        foreach ($parameter in $parameters) {
            $xmlWriter.WriteStartElement("Parameter")
            $XmlWriter.WriteAttributeString("Id", $parameter.Id)
            if ($null -ne $parameter.IsHidden) {
                $XmlWriter.WriteAttributeString("IsHidden", $parameter.IsHidden)
            }
            $XmlWriter.WriteAttributeString("Value", $parameter.Value)
            $xmlWriter.WriteEndElement()
        }

        $xmlWriter.WriteEndElement() # <-- End <Root> 

        # End, Finalize and close the XML Document
        $xmlWriter.WriteEndDocument()
        $xmlWriter.Flush()
        $xmlWriter.Close()

        return $filename
    }
}