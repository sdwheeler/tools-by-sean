param(
    [string[]]$Module = 'sdwheeler.*',
    [switch]$clean,
    [switch]$publish
)
if ( $clean ) {
    $null = if (Test-Path "${PSScriptRoot}/out") {
        Remove-Item "${PSScriptRoot}/out" -Recurse -Force
    }
}

if ($publish) {
    $ModuleList = (Get-Item $Module).BaseName
    foreach ($moduleName in $ModuleList) {
        $psd = Import-PowerShellDataFile "$PSScriptRoot/${moduleName}/${moduleName}.psd1"
        $moduleVersion = $psd.ModuleVersion
        $moduleDeploymentDir = "${PSScriptRoot}/out/${moduleName}/${moduleVersion}"

        # create directory with version
        # copy files to that location
        if (-not (Test-Path $moduleDeploymentDir)) {
            New-Item -Type Directory -Force -Path $moduleDeploymentDir
        }
        Copy-Item -Force -Recurse "$PSScriptRoot/${moduleName}/*" $moduleDeploymentDir

        if (-not (test-path $moduleDeploymentDir)) {
            throw "Could not find '$moduleDeploymentDir'"
        }
        Publish-PSResource -Path $moduleDeploymentDir -Repository LocalPSResource
    }
}