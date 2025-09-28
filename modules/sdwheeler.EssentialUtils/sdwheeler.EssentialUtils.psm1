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
    & "${env:ProgramFiles}\VideoLAN\VLC\vlc.exe" "$HOME\OneDrive - Microsoft\Documents\WIP\soma.m3u8"
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
#region Utility functions
#-------------------------------------------------------
function Save-History {
    $date = Get-Date -f 'yyyy-MM-dd'
    $oldlog = "$env:APPDATA\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"
    $newlog = "$env:USERPROFILE\Documents\PowerShell\History\ConsoleHost_history_$date.txt"
    Copy-Item $oldlog $newlog -Force
    Get-History |
        Select-Object -ExpandProperty CommandLine |
        Sort-Object -Unique |
        Out-File $oldlog -Force
}
#-------------------------------------------------------
function Get-MyHistory {
    Get-History | Select-Object id,
        @{n='Time'; e={'{0:MM/dd/yyyy HH:mm:ss}' -f$_.StartExecutionTime}},
        CommandLine
}
if ($PSVersionTable.PSVersion.Major -ge 6) {
    Set-Alias -Name h -Value Get-MyHistory -Force
} else {
    Set-Alias -Name h2 -Value Get-MyHistory -Force
}
#-------------------------------------------------------
function Get-AsciiTable {
    [byte[]](0..255) | Format-Hex
}
Set-Alias ascii Get-AsciiTable
#-------------------------------------------------------
function Get-AsciiValue {
    [CmdletBinding(DefaultParameterSetName='ByChar')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByChar')]
        [ValidateLength(1,1)]
        [string]$Char,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByValue')]
        [ValidateRange(0, 255)]
        [int]$Byte,

        [Parameter(Mandatory, ParameterSetName = 'ByRange')]
        [ValidateSet('Control', 'Printable', 'Extended')]
        [string]$Range
    )
    begin {
        $ascii = Import-Csv $PSScriptRoot\ascii.csv
    }
    process {
        switch ($PSCmdlet.ParameterSetName) {
            'ByChar'  { $ascii[([int]($char[0]))] }
            'ByValue' { $ascii[$byte] }
            'ByRange' { $ascii | Where-Object Collection -eq $Range }
        }
    }
}
#-------------------------------------------------------
function Get-KeyChord {
    Write-Host 'Enter a single key: ' -NoNewLine
    $key = [console]::ReadKey()
    $key |
        Select-Object @{n='CharCode'; e={[int]$_.KeyChar}},
        @{n='KeyChar'; e={"'$($_.KeyChar)'"}},
        Key, Modifiers
}
#-------------------------------------------------------
function Set-EnvironmentVariable {
    param(
        [Parameter(Mandatory)]
        [ArgumentCompleter( {
            param ( $commandName,
                    $parameterName,
                    $wordToComplete,
                    $commandAst,
                    $fakeBoundParameters )
            (Get-Item env:*$wordToComplete*).Name
        } )]
        [string]$Name,

        [string]$Value,

        [ValidateSet('Machine', 'User')]
        [string]$Scope = 'User'
    )
    if ('' -eq $Value) {
        $Value = Read-Host -Prompt "Enter value for $Name" -MaskInput
    }
    [System.Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
    Set-Item env:$Name -Value $Value
}
#-------------------------------------------------------
function Sync-EnvironmentVariable {
    param(
        [Parameter(Mandatory)]
        [ArgumentCompleter( {
            param ( $commandName,
                    $parameterName,
                    $wordToComplete,
                    $commandAst,
                    $fakeBoundParameters )
            (Get-Item env:*$wordToComplete*).Name
        } )]
        [string]$Name,

        [switch]$ToRegistry,

        [ValidateSet('Machine', 'User')]
        [string]$Scope = 'User'
    )
    if ($ToRegistry) {
        $Value = Get-Item env:$Name
        [System.Environment]::SetEnvironmentVariable($Name, $Value.Value, $Scope)
    } else {
        $Value = [System.Environment]::GetEnvironmentVariable($Name, $Scope)
        Set-Item env:$Name -Value $Value
    }
}
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
            versioncmd = "'gh-dash version {0}' -f (gh dash --version | sls 'module version: (v(\d+\.{0,1})+),').Matches.Groups[1].Value"
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
            $info.pstypenames.Insert(0, 'ToolInfoWithNotes')
        } else {
            $info.pstypenames.Insert(0, 'ToolInfo')
        }
        $info

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
            Write-Host "Downloading gh-dash $($v.tagName)..."
            $f = ($v.assets | Where-Object Name -like '*windows-amd64.exe').name
            gh release download -R dlvhdr/gh-dash -p $f -D $HOME\Downloads --skip-existing
            Write-Host "Installing gh-dash $($v.tagName)..."
            Copy-Item "$HOME\Downloads\$f" "$HOME\AppData\Local\GitHub CLI\extensions\gh-dash\gh-dash.exe" -Force
        }
        'gh' {
            $v = (gh release view -R cli/cli --json tagName  --json assets | ConvertFrom-Json)
            Write-Host "Downloading gh $($v.tagName)..."
            $f = ($v.assets | Where-Object Name -like '*windows_amd64.msi').name
            gh release download -R cli/cli -p $f -D $HOME\Downloads --skip-existing
            Write-Host "Installing gh $($v.tagName)..."
            Invoke-Item $HOME\Downloads\$f
        }
        'vale' {
            $v = (gh release view -R errata-ai/vale --json tagName,assets | ConvertFrom-Json)
            Write-Host "Downloading vale $($v.tagName)..."
            $f = ($v.assets | Where-Object Name -like 'vale*Windows_64-bit.zip').name
            gh release download -R errata-ai/vale -p $f -D $HOME\Downloads --skip-existing
            Write-Host "Installing vale $($v.tagName)..."
            7z e $HOME\Downloads\$f vale.exe -oC:\Public\Toolbox -y
        }
        'pandoc' {
            $v = (gh release view -R jgm/pandoc --json tagName,assets | ConvertFrom-Json)
            Write-Host "Downloading pandoc $($v.tagName)..."
            $f = ($v.assets | Where-Object Name -like '*windows-x86_64.msi').name
            gh release download -R jgm/pandoc -p $f -D $HOME\Downloads --skip-existing
            Write-Host "Installing pandoc $v..."
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
    <#
    .SYNOPSIS
    Copies user configuration files to the GitHub repo.
    #>
    [CmdletBinding()]
    $repoPath = $git_repos['tools-by-sean'].path
    if ($repoPath) {
        Copy-Item -Verbose $HOME\AppData\Roaming\Code\User\*.json $repoPath\vscode
        Copy-Item -Verbose ~\.gitconfig $repoPath\gitconfig\.gitconfig
        Copy-Item -Verbose ~\.gitignore $repoPath\gitconfig\.gitignore
        robocopy $HOME\Documents\PowerShell\profiles $repoPath\profile
        robocopy $HOME\.config $repoPath\config /s /e
        robocopy $HOME\.vale $repoPath\vale /s /e

    } else {
        Write-Error '$git_repos does not contain repo.'
    }
}
Set-Alias -Name spro -Value Save-Profile
#-------------------------------------------------------
function Update-Profile {
    <#
    .SYNOPSIS
    Copies profile scripts and user configs from the GitHub repo to my profile location.
    #>
    [CmdletBinding()]
    $repoPath = $git_repos['tools-by-sean'].path
    if ($null -ne $repoPath) {
        Copy-Item -Verbose $repoPath\vscode\*.json $HOME\AppData\Roaming\Code\User
        Copy-Item -Verbose $repoPath\gitconfig\.gitconfig ~\.gitconfig
        Copy-Item -Verbose $repoPath\gitconfig\.gitignore ~\.gitignore
        robocopy $repoPath\profile $HOME\Documents\PowerShell\profiles
        robocopy $repoPath\profile $HOME\Documents\WindowsPowerShell\profiles
        robocopy $repoPath\vale    $HOME\.vale /s /e
        robocopy $repoPath\config  $HOME\.config /s /e
    } else {
        Write-Error '$git_repos does not contain repo.'
    }
}
Set-Alias -Name upro -Value Update-Profile
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#region File & Directory functions
#-------------------------------------------------------
function New-Directory {
    param($name)
    mkdir $name
    Push-Location .\$name
}
Set-Alias -Name mcd -Value new-directory
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
#region Formatting proxy functions
#-------------------------------------------------------
function Format-TableAuto {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [psobject]
        ${InputObject})

    begin {
        $PSBoundParameters['AutoSize'] = $true
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Format-Table', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = { & $wrappedCmd @PSBoundParameters }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    }

    process {
        $steppablePipeline.Process($_)
    }

    end {
        $steppablePipeline.End()
    }
    <#
  .ForwardHelpTargetName Format-Table
  .ForwardHelpCategory Cmdlet
  #>
}
Set-Alias fta Format-TableAuto
#-------------------------------------------------------
function Format-TableWrapped {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true)]
        [psobject]
        ${InputObject})

    begin {
        $PSBoundParameters['Wrap'] = $true
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Format-Table', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = { & $wrappedCmd @PSBoundParameters }

        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    }

    process {
        $steppablePipeline.Process($_)
    }

    end {
        $steppablePipeline.End()
    }
    <#
  .ForwardHelpTargetName Format-Table
  .ForwardHelpCategory Cmdlet
  #>
}
Set-Alias ftw Format-TableWrapped
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#-------------------------------------------------------
#region Web utilities
#-------------------------------------------------------
function Get-HtmlHeaderLinks {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('Url')]
        [uri]$PageUrl
    )

    $page = Invoke-WebRequest $PageUrl
    $parsedContent = $page.Content | select-string '\<link[^\>]+\>' -AllMatches
    $rawLinks = $parsedContent.Matches.Value.TrimStart('<link ').TrimEnd('>')

    foreach ($link in $rawLinks) {
        $parsedLink = [pscustomobject]@{
            rel = ''
            type = ''
            id = ''
            href = ''
            link = $link
        }
        if ($link -match 'rel=[''"]?(?<value>[\w-]+\x20?[\w-]+)[''"]?') {
            $parsedLink.rel = $Matches.value
        }
        if ($link -match 'href=[''"]?(?<value>[^\s"'']+)[''"]?') {
            $parsedLink.href = $Matches.value
        }
        if ($link -match 'id=[''"]?(?<value>[^\s"'']+)[''"]?') {
            $parsedLink.id = $Matches.value
        }
        if ($link -match 'type=[''"]?(?<value>[^\s"'']+)[''"]?') {
            $parsedLink.type = $Matches.value
        }
        $parsedLink.pstypenames.Insert(0, 'HtmlHeaderLink')
        $parsedLink
    }
}
#-------------------------------------------------------
function Show-Redirects {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$startURL,
        [switch]$showall
    )

    $ErrorActionPreference = 'Stop'
    $lastError = $null

    function GetWebRequest {
        param([uri]$url)
        $wr = [System.Net.WebRequest]::Create($url)
        $wr.Method= 'GET'
        $wr.Timeout = 25000
        $wr.AllowAutoRedirect = $false
        $wr.UserAgent = 'Redirect crawler'
        try {
            $resp = [System.Net.HttpWebResponse]$wr.GetResponse()
            $resp
        }
        catch [System.Net.WebException] {
            $script:lastError = $_.Exception
        }
    }

    $locationlist = @()
    while ($startURL -ne '') {
        $response = GetWebRequest $startURL
        if ($null -eq $response) {
            if ($script:lastError.Status -ne 'ProtocolError') {
                $result = [pscustomobject]@{
                    code       = '0x{0:x8}' -f $script:lastError.Hresult
                    status     = $script:lastError.Status
                    requestURL = $startURL
                    location   = $startURL
                }
            } else {
                $result = [pscustomobject]@{
                    code       = $script:lastError.Response.StatusCode -as [int]
                    status     = $script:lastError.Response.StatusDescription
                    requestURL = $startURL
                    location   = $startURL
                }
            }
            break
        }
        if ($locationlist.Contains($response.Headers['Location'])) {
            $result = [pscustomobject]@{
                code='RedirLoop'
                status= 'Redirection loop!'
                requestURL=$startURL
                location=$response.Headers['Location']
            }
            break
        }

        switch ($response.StatusCode.value__) {
            {$_ -in (301,302,304)} {
                $result = [pscustomobject]@{
                    code       = $response.StatusCode.value__
                    status     = $response.StatusDescription
                    requestURL = $startURL
                    location   = $response.Headers['Location']
                }
                if ($response.Headers['Location'].StartsWith('/')) {
                    $baseURL = [uri]$response.ResponseUri
                    $startURL = $baseURL.Scheme + '://'+ $baseURL.Host + $response.Headers['Location']
                } elseif ($response.Headers['Location'].StartsWith('http')) {
                    $startURL = $response.Headers['Location']
                } else {
                    $baseURL = [uri]$response.ResponseUri
                    $startURL = $baseURL.Scheme + '://'+ $baseURL.Host + $baseURL.AbsolutePath + $response.Headers['Location']
                }
                break
            }
            404 {
                $result = [pscustomobject]@{
                    code       = $response.StatusCode.value__
                    status     = $response.StatusDescription
                    requestURL = $startURL
                    location   = $startURL
                }
                $startURL = ''
                break
            }
            200 {
                $result = [pscustomobject]@{
                    code=$response.StatusCode.value__
                    status= $response.StatusDescription
                    requestURL=$response.ResponseUri
                    location=$response.ResponseUri
                }
                $startURL = ''
                break
            }
            default {
                $result = [pscustomobject]@{
                    code       = $response.StatusCode.value__
                    status     = $response.StatusDescription
                    requestURL = $startURL
                    location   = $response.ResponseUri
                }
                $startURL = ''
                break
            }
        }
        $locationlist += $response.Headers['Location']
        if ($showall) {
            write-output $result
            $result = $null
        }
    }
    if ($result) { write-output $result }
    $locationlist = @()
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
#-------------------------------------------------------
#region Private Functions
#-------------------------------------------------------
function GetTools {
    $items = Get-Content -Path $PSScriptRoot\tools.jsonc |
        ConvertFrom-Json
    foreach ($item in $items) {
        $item.ExePath = Invoke-Expression ('"{0}"' -f $item.ExePath)
    }
    $items
}
$ToolList = GetTools

function GetInstalledVersion {
    param($tool)

    $InstalledVersion = ''
    if (Test-Path $tool.ExePath) {
        switch ($tool.VersionCmd) {
            'gcm'   {
                $InstalledVersion = (Get-Command $tool.ExePath).FileVersionInfo.FileVersion
            }
            'sls'   {
                $result = Select-String -Path $tool.ExePath -Pattern $tool.VersionPattern
                if ($result -match $tool.VersionPattern) { $InstalledVersion = $matches[1] }
            }
            default {
                if ($tool.VersionPattern -ne '') {
                    $result = Invoke-Expression $tool.VersionCmd | Select-String -Pattern $tool.VersionPattern
                    $InstalledVersion = $result.Matches.Groups.Where({$_.Name -eq 'ver'}).value
                } else {
                    $InstalledVersion = Invoke-Expression $tool.VersionCmd
                }
            }
        }
    } else {
        $InstalledVersion = 'n/a'
    }
    $tool | Add-Member -MemberType NoteProperty -Name InstalledVersion -Value $InstalledVersion -Force
}
function GetWingetVersion {
    param($tool)

    if ($tool.WingetId -ne '') {
        $result = Find-WinGetPackage -Id $tool.WingetId | Where-Object Id -eq $tool.WingetId
        $tool | Add-Member -MemberType NoteProperty -Name WingetVer -Value $result.Version -Force
    }
}

function GetGitHubVersion {
    param($tool)

    if ($tool.GitRepo -ne '' -and $tool.HasRelease ) {
        $release = gh release view -R $($tool.GitRepo) --json name,tagName,publishedAt,body |
            ConvertFrom-Json
        $tool | Add-Member -MemberType NoteProperty -Name GitHubTag -Value $release.tagName -Force
        $tool | Add-Member -MemberType NoteProperty -Name GHReleaseDate -Value "$('{0:yyyy-MM-dd}' -f $release.publishedAt)" -Force
        $tool | Add-Member -MemberType NoteProperty -Name ReleaseNotes -Value $release.body -Force
    }
}
#-------------------------------------------------------
#endregion Private Functions
#-------------------------------------------------------
#-------------------------------------------------------
#region Public Functions
#-------------------------------------------------------
function Find-Tool {
    param (
        [CmdletBinding(DefaultParameterSetName = 'ByName')]
        [Parameter(Position = 0, ParameterSetName = 'ByName')]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $ToolList.Name | Where-Object {$_ -like "*$wordToComplete*"}
        })]
        [string[]]$Name,

        [Parameter(ParameterSetName = 'ByName')]
        [switch]$Full,

        [Parameter(ParameterSetName = 'ListAvailable', Mandatory)]
        [switch]$ListAvailable
    )
    begin {
        if (-not $PSBoundParameters.ContainsKey('ListAvailable')) {
            $ListAvailable = $false
        }
    }
    end {
        if ($null -eq $Name) {
            $Name = $ToolList.Name
        }

        if ($ListAvailable) {
            foreach ($item in $ToolList) {
                if ($item.pstypenames[0] -eq 'System.Management.Automation.PSCustomObject') {
                    $item.pstypenames.Insert(0, 'AvailableToolData')
                } else {
                    $item.pstypenames[0] = 'AvailableToolData'
                }
                GetWingetVersion -tool $item
                GetGitHubVersion -tool $item
                $item
            }
        } else {
            foreach ($item in $ToolList) {
                if ($item.Name -in $Name) {
                    if ($item.pstypenames[0] -eq 'System.Management.Automation.PSCustomObject') {
                        $item.pstypenames.Insert(0, 'ToolData')
                    } else {
                        $item.pstypenames[0] = 'ToolData'
                    }
                    GetInstalledVersion -tool $item
                    GetWingetVersion -tool $item
                    GetGitHubVersion -tool $item
                    if ($Full) {
                        $item | Select-Object *
                    } else {
                        $item
                    }
                }
            }
        }
    }
}
#-------------------------------------------------------
function Update-Sysinternals {
    param([switch]$exclusions = $false)
    if ($IsAdmin) {
        $web = Get-Service webclient
        if ($web.status -ne 'Running') { 'Starting webclient...'; Start-Service webclient }
        $web = Get-Service webclient
        while ($web.status -ne 'Running') { Start-Sleep -Seconds 1 }
        if ($exclusions) {
            robocopy.exe \\live.sysinternals.com\tools 'C:\Public\Sysinternals' /s /e /XF thumbs.db /xf strings.exe /xf sysmon.exe /xf psexec.exe
        } else {
            robocopy.exe \\live.sysinternals.com\tools 'C:\Public\Sysinternals' /s /e /XF thumbs.db
        }
    } else {
        'Updating Sysinternals tools requires elevation.'
    }
}
#-------------------------------------------------------
#endregion Public Functions
#-------------------------------------------------------
