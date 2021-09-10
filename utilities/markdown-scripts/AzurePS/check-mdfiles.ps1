$modmap = gc C:\Git\CSIStuff\tools-by-sean\migrate-scripts\AzurePS\modulepaths.json | convertfrom-json

foreach ($mod in $modmap) {
    $modname = $mod.module
    if ($mod.path.count -eq 2){
        $modpath = $mod.path[0]
    } else {
        $modpath = $mod.path
    }
    $psd1 = (Get-ChildItem -Name C:\temp\psgallery\azurerm-4.0.0\$modname -rec -inc "$modname.psd1")
    $psd1 = "C:\temp\psgallery\azurerm-4.0.0\$modname\$psd1"

    $cmdlets = (Get-Module $psd1 -ListAvailable).ExportedCmdlets.Keys

    $results = @{}

    foreach ($cmd in $cmdlets) {
        $results.Add($cmd,'Missing')
        foreach ($path in $mod.path) {
            $mdpath = $path + '\' + $cmd + '.md'
            if ($results[$cmd] -eq 'Missing') {
                if (Test-Path $mdpath) {
                    $results[$cmd] = 'Found'
                } else {
                    $results[$cmd] = 'Missing'
                }
            }
        }
    }
    $results.Keys | %{ if ($results[$_] -eq 'Missing') {"Missing: $_"}}
}