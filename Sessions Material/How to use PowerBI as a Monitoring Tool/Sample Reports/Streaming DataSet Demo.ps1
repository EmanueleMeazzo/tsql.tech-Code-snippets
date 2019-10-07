$i = 1

while ($i -le 25) {
    $endpoint = "https://api.powerbi.com/beta/yourendpointmaybe?"

$machinename = Get-ComputerInfo -Property CsName
$timestamp = Get-Date
$freememorybytes = Get-Counter -Counter "\memory\available bytes"
$totalprocessortime = Get-Counter -Counter "\Processor(_Total)\% Processor Time"

$payload = @{
"MachineName" = $machinename.CsName
"TimeStamp" = $timestamp
"FreeMemoryBytes" = $freememorybytes.CounterSamples.CookedValue
"TotalProcessorTime" = $totalprocessortime.CounterSamples.CookedValue
}

Invoke-RestMethod -Method Post -Uri "$endpoint" -Body (ConvertTo-Json @($payload))

Start-Sleep -Seconds 1

$i++
}