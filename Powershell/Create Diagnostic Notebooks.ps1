[CmdletBinding()]
Param(
    [parameter(Mandatory)]
    [System.IO.FileInfo]$OutputPath
)

function DownloadFilesFromRepo {
    Param(
        [string]$Owner,
        [string]$Repository,
        [string]$Path,
        [string]$DestinationPath
        )
    
        $baseUri = "https://api.github.com/"
        $args = "repos/$Owner/$Repository/contents/$Path"
        $wr = Invoke-WebRequest -Uri $($baseuri+$args)
        $objects = $wr.Content | ConvertFrom-Json
        $files = $objects | Where-Object {$_.type -eq "file"} | Select-Object -exp download_url
        
        if (-not (Test-Path $DestinationPath)) {
            # Destination path does not exist, let's create it
            try {
                New-Item -Path $DestinationPath -ItemType Directory -ErrorAction Stop
            } catch {
                throw "Could not create path '$DestinationPath'!"
            }
        }
    
        foreach ($file in $files) {
            $fileDestination = Join-Path $DestinationPath (Split-Path $file -Leaf) | ForEach-Object { $_ -replace '%20',' '}
            try {
                Invoke-WebRequest -Uri $file -OutFile $fileDestination -ErrorAction Stop -Verbose
                "Grabbed '$($file)' to '$fileDestination'"
            } catch {
                throw "Unable to download '$($file.path)'"
            }
        }
    
    }

#Download Diagnostic Scripts
DownloadFilesFromRepo -Owner "EmanueleMeazzo" -Repository "tsql.tech-Code-snippets" -Path "DMV/Glenn Berry Diagnostic Scripts" -DestinationPath "TempFolderForThisStuff"
#Download DbaTool's Invoke-DbaDiagnosticQueryScriptParser
DownloadFilesFromRepo -Owner "sqlcollaborative" -Repository "dbatools" -Path "internal/functions/Invoke-DbaDiagnosticQueryScriptParser.ps1" -DestinationPath "TempFolderForThisStuff"

#Load The Function
. .\TempFolderForThisStuff\Invoke-DbaDiagnosticQueryScriptParser.ps1

#Create the Notebooks
New-Item -ItemType Directory -Force -Path $OutputPath
$files = Get-ChildItem -Path "TempFolderForThisStuff\*.sql"
foreach ($file in $files)
{
    $filename = $OutputPath.ToString() + "\" + (Split-Path $file -Leaf).Replace(".sql",".ipynb").ToString()
    $cells = @()

    Invoke-DbaDiagnosticQueryScriptParser $file |
        ForEach-Object {
            $cells += [pscustomobject]@{cell_type = "markdown"; source = "## $($_.QueryName)`n`n$($_.Description)" }
            $cells += [pscustomobject]@{cell_type = "code"; source = $_.Text }
        }

    $preamble = @"
    {
        "metadata": {
            "kernelspec": {
                "name": "SQL",
                "display_name": "SQL",
                "language": "sql"
            },
            "language_info": {
                "name": "sql",
                "version": ""
            }
        },
        "nbformat_minor": 2,
        "nbformat": 4,
        "cells":
"@


    $preamble | Out-File $filename -Force
    $cells | ConvertTo-Json | Out-File -FilePath $filename -Append
    "}}" | Out-File -FilePath $filename -Append

}

Remove-Item "TempFolderForThisStuff" -Force -Recurse