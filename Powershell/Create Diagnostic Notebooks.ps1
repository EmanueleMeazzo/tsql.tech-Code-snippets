[CmdletBinding()]
Param(
    [parameter(Mandatory)]
    [System.IO.FileInfo]$OutputPath
)

function Invoke-DbaDiagnosticQueryScriptParser {
    [CmdletBinding(DefaultParameterSetName = "Default")]

    Param(
        [parameter(Mandatory)]
        [ValidateScript( {Test-Path $_})]
        [System.IO.FileInfo]$filename,
        [Switch]$ExcludeQueryTextColumn,
        [Switch]$ExcludePlanColumn,
        [Switch]$NoColumnParsing
    )

    $out = "Parsing file {0}" -f $filename
    write-verbose -Message $out

    $ParsedScript = @()
    [string]$scriptpart = ""

    $fullscript = Get-Content -Path $filename

    $start = $false
    $querynr = 0
    $DBSpecific = $false

    if ($ExcludeQueryTextColumn) {$QueryTextColumn = ""}  else {$QueryTextColumn = ", t.[text] AS [Complete Query Text]"}
    if ($ExcludePlanColumn) {$PlanTextColumn = ""} else {$PlanTextColumn = ", qp.query_plan AS [Query Plan]"}

    foreach ($line in $fullscript) {
        if ($start -eq $false) {
            if (($line -match "You have the correct major version of SQL Server for this diagnostic information script") -or ($line.StartsWith("-- Server level queries ***") -or ($line.StartsWith("-- Instance level queries ***")))) {
                $start = $true
            }
            continue
        }

        if ($line.StartsWith("-- Database specific queries ***") -or ($line.StartsWith("-- Switch to user database **"))) {
            $DBSpecific = $true
        }

        if (!$NoColumnParsing) {
            if (($line -match "-- uncomment out these columns if not copying results to Excel") -or ($line -match "-- comment out this column if copying results to Excel")) {
                $line = $QueryTextColumn + $PlanTextColumn
            }
        }

        if ($line -match "-{2,}\s{1,}(.*) \(Query (\d*)\) \((\D*)\)") {
            $prev_querydescription = $Matches[1]
            $prev_querynr = $Matches[2]
            $prev_queryname = $Matches[3]

            if ($querynr -gt 0) {
                $properties = @{QueryNr = $querynr; QueryName = $queryname; DBSpecific = $DBSpecific; Description = $queryDescription; Text = $scriptpart}
                $newscript = New-Object -TypeName PSObject -Property $properties
                $ParsedScript += $newscript
                $scriptpart = ""
            }

            $querydescription = $prev_querydescription
            $querynr = $prev_querynr
            $queryname = $prev_queryname
        } else {
            if (!$line.startswith("--") -and ($line.trim() -ne "") -and ($null -ne $line) -and ($line -ne "\n")) {
                $scriptpart += $line + "`n"
            }
        }
    }

    $properties = @{QueryNr = $querynr; QueryName = $queryname; DBSpecific = $DBSpecific; Description = $queryDescription; Text = $scriptpart}
    $newscript = New-Object -TypeName PSObject -Property $properties
    $ParsedScript += $newscript
    $ParsedScript
}

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
# #Download DbaTool's Invoke-DbaDiagnosticQueryScriptParser
# DownloadFilesFromRepo -Owner "sqlcollaborative" -Repository "dbatools" -Path "internal/functions/Invoke-DbaDiagnosticQueryScriptParser.ps1" -DestinationPath "TempFolderForThisStuff"

# #Load The Function
# . .\TempFolderForThisStuff\Invoke-DbaDiagnosticQueryScriptParser.ps1

#Create the Notebooks
New-Item -ItemType Directory -Force -Path $OutputPath
$files = Get-ChildItem -Path "TempFolderForThisStuff\*.sql"
foreach ($file in $files)
{
    $filename = $OutputPath.ToString() + "\" + (Split-Path $file -Leaf).Replace(".sql",".ipynb").ToString()
    $Description = (Split-Path $file -Leaf).Replace(".sql","").ToString()
    $cells = @()
    $cells += [pscustomobject]@{cell_type = "markdown"; source = "# $Description" }

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