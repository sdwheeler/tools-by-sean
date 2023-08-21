#-------------------------------------------------------
#region Aliases and shortcut functions
#-------------------------------------------------------
Set-Alias qrss "${env:ProgramFiles(x86)}\QuiteRSS\QuiteRSS.exe"
Set-Alias ed "${env:ProgramFiles(x86)}\NoteTab 7\NotePro.exe"
Set-Alias fview "$env:ProgramW6432\Maze Computer\File View\FView.exe"
Set-Alias 7z 'C:\Program Files\7-Zip\7z.exe'
Set-Alias testexe C:\Public\Toolbox\TestExe\testexe.exe
#-------------------------------------------------------
function soma {
    #& "${env:ProgramFiles}\VideoLAN\VLC\vlc.exe" http://ice1.somafm.com/illstreet-128-aac
    & "${env:ProgramFiles}\VideoLAN\VLC\vlc.exe" '$HOME\OneDrive - Microsoft\Documents\WIP\soma.m3u'
}
#-------------------------------------------------------
function bc {
    Start-Process "${env:ProgramFiles}\Beyond Compare 4\BComp.exe" -ArgumentList $args
}
#-------------------------------------------------------
function ed {
    Start-Process "${env:ProgramFiles(x86)}\NoteTab 7\notepro.exe" -ArgumentList $args
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Public functions
#-------------------------------------------------------
function Get-AsciiTable {
    [byte[]](0..255) | Format-Hex
}
Set-Alias ascii get-asciitable
#-------------------------------------------------------
function Push-MyLocation {
    param($targetlocation)
    if ($null -eq $targetlocation) {
        Get-Location -Stack
    } else {
        if (Test-Path $targetlocation -PathType Container) {
            Push-Location $targetlocation
        } elseif (Test-Path $targetlocation) {
            $location = Get-Item $targetlocation
            Push-Location $location.PSParentPath
        } else {
            Write-Error "Invalid path: $targetlocation"
        }
    }
}
Set-Alias -Name cdd -Value Push-MyLocation
Set-Alias -Name pop -Value Pop-Location
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region CLI tool management
#-------------------------------------------------------
function Find-CLI {
    param(
        [CmdletBinding()]
        [Parameter(Position = 0)]
        [ValidateSet('dash', 'gh', 'vale', 'pandoc')]
        [string[]]$Tools = @('dash', 'gh', 'vale', 'pandoc'),
        [switch]$ShowReleaseNotes
    )
    $tooldata = @{
        dash = @{
            repo = 'dlvhdr/gh-dash'
            versioncmd = 'gh dash --version | findstr version'
        }
        gh = @{
            repo = 'cli/cli'
            versioncmd = 'gh --version | findstr version'
        }
        vale = @{
            repo = 'errata-ai/vale'
            versioncmd = 'vale --version | findstr version'
        }
        pandoc = @{
            repo = 'jgm/pandoc'
            versioncmd = 'pandoc --version | findstr exe'
        }
    }

    foreach ($tool in $Tools) {
        $release = gh release view -R $($tooldata[$tool].repo) --json name,tagName,publishedAt,body | ConvertFrom-Json
        $info = [pscustomobject]@{
            Installed    = $(Invoke-Expression $tooldata[$tool].versioncmd)
            Current      = "$($release.name) ($('{0:yyyy-MM-dd}' -f $release.publishedAt))"
            ReleaseNotes = $release.body
        }
        if ($ShowReleaseNotes) {
            $info  | Format-List
        } else {
            $info | Select-Object Installed, Current | Format-List
        }

    }
}
#-------------------------------------------------------
function Update-CLI {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('dash', 'gh', 'vale', 'pandoc')]
        [string[]]$Tools
    )

    switch ($Tools) {
        'dash' {
            $v = (gh release view -R dlvhdr/gh-dash --json tagName,assets| ConvertFrom-Json)
            "Downloading gh-dash $($v.tagName)..."
            $f = ($v.assets | Where-Object Name -like 'windows-amd64.exe').name
            gh release download -R dlvhdr/gh-dash -p windows-amd64.exe -O "$HOME\Downloads\$($v.tagName)-gh-dash.exe" --skip-existing
            "Installing gh-dash $($v.tagName)..."
            Copy-Item "$HOME\Downloads\$($v.tagName)-gh-dash.exe" "$HOME\AppData\Local\GitHub CLI\extensions\gh-dash\gh-dash.exe" -Force
        }
        'gh' {
            $v = (gh release view -R cli/cli --json tagName  --json assets | ConvertFrom-Json)
            "Downloading gh $($v.tagName)..."
            $f = ($v.assets | Where-Object Name -like '*windows_amd64.msi').name
            gh release download -R cli/cli -p $f -D $HOME\Downloads --skip-existing
            "Installing gh $($v.tagName)..."
            Invoke-Item $HOME\Downloads\$f
        }
        'vale' {
            $v = (gh release view -R errata-ai/vale --json tagName,assets | ConvertFrom-Json)
            "Downloading vale $($v.tagName)..."
            $f = ($v.assets | Where-Object Name -like 'vale*Windows_64-bit.zip').name
            gh release download -R errata-ai/vale -p $f -D $HOME\Downloads --skip-existing
            "Installing vale $($v.tagName)..."
            7z e $HOME\Downloads\$f vale.exe -oC:\Public\Toolbox -y
        }
        'pandoc' {
            $v = (gh release view -R jgm/pandoc --json tagName,assets | ConvertFrom-Json)
            "Downloading pandoc $($v.tagName)..."
            $f = ($v.assets | Where-Object Name -like '*windows-x86_64.msi').name
            gh release download -R jgm/pandoc -p $f -D $HOME\Downloads --skip-existing
            "Installing pandoc $v..."
            Invoke-Item $HOME\Downloads\$f
        }
    }
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region Profile management tools
#-------------------------------------------------------
function Edit-Profile {
    $repoPath = $git_repos['tools-by-sean'].path
    if ($repoPath) {
        code "$repoPath"
    } else {
        Write-Error '$git_repos does not contain repo.'
    }
}
Set-Alias -Name epro -Value Edit-Profile
#-------------------------------------------------------
function Save-Profile {
    [CmdletBinding()]
    $repoPath = $git_repos['tools-by-sean'].path
    if ($repoPath) {
        Copy-Item -Verbose $HOME\AppData\Roaming\Code\User\*.json $repoPath\profile\vscode
        robocopy $HOME\Documents\PowerShell\profiles $repoPath\profile\scripts
        robocopy $HOME\.vale $repoPath\profile\vale /s /e
        robocopy $HOME\.config $repoPath\profile\config /s /e

    } else {
        Write-Error '$git_repos does not contain repo.'
    }
}
Set-Alias -Name spro -Value Save-Profile
#-------------------------------------------------------
function Update-Profile {
    [CmdletBinding()]
    $repoPath = $git_repos['tools-by-sean'].path
    if ($null -ne $repoPath) {
        Copy-Item -Verbose $repoPath\profile\vscode\*.json $HOME\AppData\Roaming\Code\User
        robocopy $repoPath\profile\scripts $HOME\Documents\PowerShell\profiles
        robocopy $repoPath\profile\scripts $HOME\Documents\WindowsPowerShell\profiles
        robocopy $repoPath\profile\vale    $HOME\.vale /s /e
        robocopy $repoPath\profile\config  $HOME\.config /s /e
        Get-ChildItem "$repoPath\modules\sdwheeler*" -dir | ForEach-Object {
            Write-Verbose "Copying $_ to $HOME\Documents\PowerShell\Modules\$($_.name)"
            robocopy $_ "$HOME\Documents\PowerShell\Modules\$($_.name)" /NJH /NJS /NP
            robocopy $_ "$HOME\Documents\WindowsPowerShell\Modules\$($_.name)" /NJH /NJS /NP
        }
    } else {
        Write-Error '$git_repos does not contain repo.'
    }
}
Set-Alias -Name upro -Value Update-Profile
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
