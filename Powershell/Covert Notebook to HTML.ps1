param (
    [Parameter(ValueFromRemainingArguments=$true)]
    $Path
)

if(!$Path)
{
    $notebook = Read-Host -Prompt "Insert the name of the notebook to convert"
}
else {
    $notebook = $Path
}

$test = Test-Path($notebook)

if(!$test)
{
    Write-Error "$notebook not found, exiting"
    Exit
}
else {
    jupyter nbconvert --to html $notebook    
}
