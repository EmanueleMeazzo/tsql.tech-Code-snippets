$sqlinstalled = Get-Module -ListAvailable -Name sqlserver

if (!$sqlinstalled) {
    Install-Module sqlserver -Scope CurrentUser -Force
} 

$instance = 'mssql'
$database = 'TempDB'
$query = "SELECT * FROM sys.tables"

Invoke-Sqlcmd -ServerInstance $instance -Database $database -Query $query | ConvertTo-Csv -Delimiter ';' -NoTypeInformation | Out-File .\export.csv -Force