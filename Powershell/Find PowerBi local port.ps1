$data = Get-Process -ProcessName msmdsrv

if ($null -eq $data) {
    Write-Host "A PowerBi model instance is not running"
}
else {
   $a = Get-NetTCPConnection -OwningProcess $data.Id
   $port = $a[0].LocalPort
   Write-Host "The PowerBi local SSAS instance is @ 127.0.0.1:$port"
}