function DownloadFilesFromRepo {
    Param(
        [string]$Owner,
        [string]$Repository,
        [string]$Path,
        [string]$DestinationPath
        )
    
        $baseUri = "https://api.github.com/"
        $ar = "repos/$Owner/$Repository/contents/$Path"
        [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11, tls"
        $wr = Invoke-WebRequest -Uri $($baseuri+$ar)
        $objects = $wr.Content | ConvertFrom-Json
        $files = $objects | Where-Object {$_.type -eq "file" -and $_.name -like "sp_*" } | Select-Object -exp download_url
        
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
DownloadFilesFromRepo -Owner "BrentOzarULTD" -Repository "SQL-Server-First-Responder-Kit" -Path "" -DestinationPath "TempFolderForThisStuff"

$files = Get-ChildItem -Path "TempFolderForThisStuff\*.sql"
$filename = "FirstRespondersKit.ipynb"

$cells = @()
$cells += [pscustomobject]@{cell_type = "markdown"; source = "# First Responders Kit Installation Notebook" }

$cells += [pscustomobject]@{cell_type = "markdown"; source = "You're a DBA, sysadmin, or developer who manages Microsoft SQL Servers. It's your fault if they're down or slow. These tools help you understand what's going on in your server.

- When you want an overall health check, run <b>sp_Blitz</b>.
- To learn which queries have been using the most resources, run <b>sp_BlitzCache</b>.
- To analyze which indexes are missing or slowing you down, run <b>sp_BlitzIndex</b>.
- To find out why the server is slow right now, run <b>sp_BlitzFirst</b>." }

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

foreach ($file in $files) {
    $text = Get-Content $file -Raw
    $cells += [pscustomobject]@{cell_type = "markdown"; source = "## Install $($file.BaseName)`n" }
    $cells += [pscustomobject]@{cell_type = "code"; source = $text.ToString(); metadata = [PSCustomObject]@{
        tags = @("hide_input","dummytag")}}
}

$cells | ConvertTo-Json -Depth 5 | Out-File -FilePath $filename -Append
"}}" | Out-File -FilePath $filename -Append

Remove-Item "TempFolderForThisStuff" -Force -Recurse
