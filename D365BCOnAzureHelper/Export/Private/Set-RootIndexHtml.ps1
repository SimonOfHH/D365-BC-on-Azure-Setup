# Will be called in VM
function Global:Set-RootIndexHtml {
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
        $DestinationFile
    )    
    if (Test-Path -Path $DestinationFile){
        return
    }
    Write-Verbose "Creating file $DestinationFile"
    $content = "<html>
    <head>
    <title>       </title>
    <style type=`"text/css`">
    <!--
    h1	{text-align:center;
        font-family:Arial, Helvetica, Sans-Serif;
        }
    
    p	{text-indent:20px;
        }
    -->
    </style>
    </head>
    <body bgcolor = `"#ffffcc`" text = `"#000000`">
    <h1>Test Page</h1>
    
    <p>This Page is used for load balancer probing. It's only necessary that there is a index.htm page, so it's safe to replace it if necessary</p>
    
    </body>
    </html>"

    Set-Content -Path $DestinationFile -Value $content
}