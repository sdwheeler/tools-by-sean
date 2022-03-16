############################
# TODO LIST
# - write code to fixup URLs in docs
############################

function Get-WhatsNew {
    [CmdletBinding(DefaultParameterSetName = 'ByVersion')]
    param (
        [Parameter(Position=0,ParameterSetName='ByVersion')]
        [Parameter(Position=0,ParameterSetName='CompareVersion')]
        [ValidateSet('5.1','7.0','7.1','7.2','7.3')]
        [string]$Version,

        [Parameter(Mandatory,ParameterSetName='CompareVersion')]
        [ValidateSet('5.1','7.0','7.1','7.2','7.3')]
        [string]$CompareVersion,

        [Parameter(Mandatory,ParameterSetName='AllVersions')]
        [switch]$All,

        [Parameter(Position=0,ParameterSetName='ByVersion')]
        [Alias('MOTD')]
        [switch]$Daily,

        [Parameter(ParameterSetName='ByVersion')]
        [switch]$Online
    )


    $versions = @(
        ([PSCustomObject]@{
            version = '5.1'
            path = Join-Path $PSScriptRoot 'relnotes/What-s-New-in-Windows-PowerShell-50.md'
            url = 'https://docs.microsoft.com/powershell/scripting/windows-powershell/whats-new/what-s-new-in-windows-powershell-50'
        }),
        ([PSCustomObject]@{
            version = '7.0'
            path = Join-Path $PSScriptRoot 'relnotes/What-s-New-in-PowerShell-70.md'
            url = 'https://docs.microsoft.com/powershell/scripting/whats-new/what-s-new-in-powershell-70'
        }),
        ([PSCustomObject]@{
            version = '7.1'
            path = Join-Path $PSScriptRoot 'relnotes/What-s-New-in-PowerShell-71.md'
            url = 'https://docs.microsoft.com/powershell/scripting/whats-new/what-s-new-in-powershell-71'
        }),
        ([PSCustomObject]@{
            version = '7.2'
            path = Join-Path $PSScriptRoot 'relnotes/What-s-New-in-PowerShell-72.md'
            url = 'https://docs.microsoft.com/powershell/scripting/whats-new/what-s-new-in-powershell-72'
        }),
        ([PSCustomObject]@{
            version = '7.3'
            path = Join-Path $PSScriptRoot 'relnotes/What-s-New-in-PowerShell-73.md'
            url = 'https://docs.microsoft.com/powershell/scripting/whats-new/what-s-new-in-powershell-73'
        })
    )

    if (0 -eq $Version) {
        $Version = [double]('{0}.{1}' -f$PSVersionTable.PSVersion.Major,$PSVersionTable.PSVersion.Minor)
    }

    # Resolve parameter set
    $mdfiles = @()
    if ($PsCmdlet.ParameterSetName -eq 'CompareVersion') {
        if ($Version -gt $CompareVersion) {
            $tempver = $CompareVersion
            $CompareVersion = $Version
            $Version = $tempver
        }
        foreach ($ver in $versions) {
            if (($ver.version -ge $Version) -and ($ver.version -le $CompareVersion)) {
                $mdfiles += $ver.path
            }
        }
    } elseif ($PsCmdlet.ParameterSetName -eq 'AllVersions') {
        $mdfiles = ($versions).path
    } else {
        $mdfiles = ($versions | Where-Object version -eq $Version).path
    }

    # Scan release notes for H2 blocks
    $endMarker = '<!-- end of content -->'
    foreach ($file in $mdfiles) {
        $mdtext = Get-Content $file -Encoding utf8
        $mdheaders = Select-String -Pattern '^##\s',$endMarker -Path $file

        $blocklist = @()

        foreach ($hdr in $mdheaders) {
            if ($hdr.Line -ne $endMarker) {
                $block = [PSCustomObject]@{
                    Name      = $hdr.Line.Trim()
                    StartLine = $hdr.LineNumber - 1
                    EndLine   = -1
                }
                $blocklist += $block
            } else {
                $blocklist[-1].EndLine = $hdr.LineNumber - 2
            }
        }
        if ($blocklist.Count -gt 0) {
            for ($x = 0; $x -lt $blocklist.Count; $x++) {
                if ($blocklist[$x].EndLine -eq -1) {
                    $blocklist[$x].EndLine = $blocklist[($x + 1)].StartLine - 1
                }
            }
        }

        if ($Daily) {
            $block = $blocklist | Get-Random -SetSeed (get-date -UFormat '%s')
            $mdtext[$block.StartLine..$block.EndLine]
            <# - Alternate ANSI output
            $mdtext[$block.StartLine..$block.EndLine] |
                ConvertFrom-Markdown -AsVT100EncodedString |
                Select-Object -ExpandProperty VT100EncodedString
            #>
        } elseif ($Online) {
            Start-Process ($versions | Where-Object version -eq $Version).url
        } else {
            foreach ($block in $blocklist) {
                $mdtext[$block.StartLine..$block.EndLine]
                <# - Alternate ANSI output
                $mdtext[$block.StartLine..$block.EndLine] |
                    ConvertFrom-Markdown -AsVT100EncodedString |
                    Select-Object -ExpandProperty VT100EncodedString
                #>
            }
        }
    }
}
