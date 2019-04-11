foreach($p in pip list)
{

    $package = $p -split ' ', 2
    pip install $package[0] --upgrade
    
}