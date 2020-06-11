#-------------------------------------------------------
#region Content Scripts
function bcsync {
  param([string]$path)
  $basepath = 'C:\Git\PS-Docs\PowerShell-Docs\reference\'
  $startpath = (get-item $path).fullname
  $vlist = '5.1','6','7.0','7.1'
  if ($startpath) {
    $relpath = $startpath -replace [regex]::Escape($basepath)
    $version = ($relpath -split '\\')[0]
    foreach ($v in $vlist) {
      if ($v -ne $version) {
        $target = $startpath -replace [regex]::Escape($version), $v
        if (Test-Path $target) {
          Start-Process -wait "${env:ProgramFiles}\Beyond Compare 4\BComp.exe" -ArgumentList $startpath,$target
        }
      }
    }
  } else {
      "Invalid path: $path"
  }
}
function Get-ContentWithoutHeader {
  param(
    $path
  )

  $doc = Get-Content $path -Encoding UTF8
  $start = $end = -1

 # search the the first 30 lines for the Yaml header
 # no yaml header in our docset will ever be that long

  for ($x = 0; $x -lt 30; $x++) {
    if ($doc[$x] -eq '---') {
      if ($start -eq -1) {
        $start = $x
      } else {
        if ($end -eq -1) {
          $end = $x+1
          break
        }
      }
    }
  }
  if ($end -gt $start) {
    Write-Output ($doc[$end..$($doc.count)] -join "`r`n")
  } else {
    Write-Output ($doc -join "`r`n")
  }
}

function Show-Help {
  param(
    [string]$cmd,

    [ValidateSet('5','5.1','6','7','7.0','7.1')]
    [string]$version='7.0',

    [switch]$UseBrowser
  )

  $aboutpath = @(
    'Microsoft.PowerShell.Core\About',
    'Microsoft.PowerShell.Security\About',
    'Microsoft.WsMan.Management\About',
    'PSDesiredStateConfiguration\About',
    'PSReadline\About',
    'PSScheduledJob\About',
    'PSWorkflow\About'
  )

  $basepath = 'C:\Git\PS-Docs\PowerShell-Docs\reference'
  if ($version -eq '7') {$version = '7.0'}
  if ($version -eq '5') {$version = '5.1'}

  if ($cmd -like 'about*') {
    foreach ($path in $aboutpath) {
      $cmdlet = ''
      $mdpath = '{0}\{1}\{2}.md' -f $version, $path, $cmd
      if (Test-Path "$basepath\$mdpath") {
        $cmdlet = $cmd
        break
      }
    }
  } else {
    $cmdlet = Get-Command $cmd
    if ($cmdlet.CommandType -eq 'Alias') { $cmdlet = Get-Command $cmdlet.Definition }
    $mdpath = '{0}\{1}\{2}.md' -f $version, $cmdlet.ModuleName, $cmdlet.Name
  }

  if ($cmdlet) {
    if (Test-Path "$basepath\$mdpath") {
      Get-ContentWithoutHeader "$basepath\$mdpath" |
        Show-Markdown -UseBrowser:$UseBrowser
    } else{
      write-error "$mdpath not found!"
    }
  } else {
    write-error "$cmd not found!"
  }
}

function show-metatags {
    param(
      [uri]$url,
      [switch]$all
    )
    $tags = @('author', 'description', 'manager', 'ms.author', 'ms.date', 'ms.devlang', 'ms.manager', 'ms.prod',
      'ms.product', 'ms.service', 'ms.technology', 'ms.component', 'ms.tgt_pltfr', 'ms.topic', 'title'
    )
    $pagetags = @()
    $UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36 Edge/15.15063'

    $page = Invoke-WebRequest -Uri $url -UserAgent $UserAgent
    if ($all) {
      $page.ParsedHtml.getElementsByTagName('meta') | Where-Object name |
      ForEach-Object{ $pagetags += new-object -type psobject -Property ([ordered]@{'name'=$_.name; 'content'=$_.content}) }
    } else {
      $page.ParsedHtml.getElementsByTagName('meta') | Where-Object name |
      Where-Object {$tags -contains $_.name} | ForEach-Object{ $pagetags += new-object -type psobject -Property ([ordered]@{'name'=$_.name; 'content'=$_.content}) }
    }
    $pagetags += new-object -type psobject -Property ([ordered]@{'name'='title'; 'content'=$page.ParsedHtml.title})
    $pagetags | Sort-Object name
}
#-------------------------------------------------------
function get-metadata {
  param(
    $path='*.md',
    [switch]$recurse
  )

  function get-yamlblock {
    param($mdpath)
    $doc = Get-Content $mdpath
    $start = $end = -1
    $hdr = ""

    for ($x = 0; $x -lt 30; $x++) {
      if ($doc[$x] -eq '---') {
        if ($start -eq -1) {
          $start = $x
        } else {
          if ($end -eq -1) {
            $end = $x
            break
          }
        }
      }
    }
    if ($end -gt $start) {
      $hdr = $doc[$start..$end] -join "`n"
      $hdr | ConvertFrom-YAML | Set-Variable temp
      $temp
    }
  }

  $docfxmetadata = (Get-Content .\docfx.json | ConvertFrom-Json -AsHashtable).build.fileMetadata

  Get-ChildItem $path -Recurse:$recurse | ForEach-Object {
    $temp = get-yamlblock $_.fullname
    $filemetadata = [ordered]@{
      file = $_.fullname -replace '\\','/'
      author = ''
      'ms.author' = ''
      'manager' = ''
      'ms.date' = ''
      'ms.prod' = ''
      'ms.technology' = ''
      'ms.topic' = ''
      'title' = ''
      'keywords' = ''
      'description' = ''
      'online version' = ''
      'external help file' = ''
      'Module Name' = ''
      'ms.assetid' = ''
      'Locale' = ''
      'schema' = ''
    }
    foreach ($item in $temp.Keys) {
      if ($temp.$item.GetType().Name -eq 'Object[]') {
        $filemetadata.$item = $temp.$item -join ','
      } else {
        $filemetadata.$item = $temp.$item
      }
    }

    foreach ($prop in $docfxmetadata.keys) {
      if ($filemetadata.$prop -eq '') {
        foreach ($key in $docfxmetadata.$prop.keys) {
          $pattern = ($key -replace '\*\*','.*') -replace '\.md','\.md'
          if ($filemetadata.file -match $pattern) {
            $filemetadata.$prop = $docfxmetadata.$prop.$key
            break
          }
        }
      }
    }
    new-object -type psobject -prop $filemetadata
  }
}

#-------------------------------------------------------
function Get-MDLinks {
    param(
      [string]$filepath
    )
    $linkpattern = '(?<link>!?\[(?<label>[^\]]*)\]\((?<file>[^)#\?]*)?(?<anchor>#[^\?]+)?)(?<query>\?[^#]+)?\)'
    $mdtext = Select-String -Path $filepath -Pattern $linkpattern
    $mdtext | ForEach-Object -Process {
      if ($_ -match $linkpattern)
      {
        Write-Output $Matches |
        Select-Object @{l='link';e={$_.link}},
        @{l='label';e={$_.label}},
        @{l='file';e={$_.file}},
        @{l='anchor';e={$_.anchor}},
        @{l='query';e={$_.query}}
      }
    }
}
#-------------------------------------------------------
function make-linkrefs {
  param([string[]]$path)
  foreach ($p in $path) {
    $linkpattern = '(?<link>!?\[(?<label>[^\]]*)\]\((?<file>[^)#]*)?(?<anchor>#.+)?\))'
    $mdtext = Select-String -Path $p -Pattern $linkpattern

    $mdtext.matches| ForEach-Object{
      $link = @()
      foreach ($g in $_.Groups) {
        if ($g.Name -eq 'label') { $link += $g.value }
        if ($g.Name -eq 'file') { $link += $g.value }
        if ($g.Name -eq 'anchor') { $link += $g.value }
      }
      "[{0}]: {1}{2}" -f $link #$link[0],$link[1],$link[2]
    }
  }
}
#-------------------------------------------------------
function do-pandoc {
  param($aboutFile)
  $file = get-item $aboutFile
  $aboutFileOutputFullName = $file.basename + '.help.txt'
  $aboutFileFullName = $file.fullname

  $pandocArgs = @(
      "--from=gfm",
      "--to=plain+multiline_tables+inline_code_attributes",
      "--columns=75",
      "--output=$aboutFileOutputFullName",
      "--quiet"
  )
  Get-ContentWithoutHeader $aboutFileFullName | & pandoc.exe $pandocArgs
}
#-------------------------------------------------------
function Get-Syntax {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory=$true,Position=0)]
    [string]$cmdletname,
    [switch]$Markdown
  )

  $common = "Debug", "ErrorAction", "ErrorVariable", "InformationAction", "InformationVariable",
            "OutVariable", "OutBuffer", "PipelineVariable", "Verbose", "WarningAction", "WarningVariable"

  $cmdlet = Get-Command $cmdletname
  if ($cmdlet.CommandType -eq 'Alias') { $cmdlet = Get-Command $cmdlet.Definition }

  if ($Markdown) {
    $cmdletname = $cmdlet.name
    foreach ($ps in $cmdlet.parametersets) {
      $hasCommonParams = $false
      $syntax = @()
      $line = "$cmdletname "
      if ($ps.name -eq '__AllParameterSets') {
        $msg = '### All'
      } else {
        $msg = '### ' + $ps.name
      }
      if ($ps.isdefault) {
        $msg += ' (Default)'
      }
      $msg += "`r`n`r`n" + '```' + "`r`n"
      $ps.Parameters | ForEach-Object{
        $token = ''
        if ($common -notcontains $_.name) {
          if ($_.position -gt -1) {
            $token += '[-' + $_.name + ']'
          } else {
            $token += '-' + $_.name
          }
          if ($_.parametertype.name -ne 'SwitchParameter') {
            $token += ' <'+ $_.parametertype.name + '>'
          }
          if (-not $_.ismandatory) {
            $token = '[' + $token + ']'
          }
          if (($line.length + $token.Length) -gt 100) {
            $syntax += $line.TrimEnd()
            $line = " $token "
          } else {
            $line += "$token "
          }
        } else {
          $hasCommonParams = $true
        }
      }
      if ($hasCommonParams) {
        if ($line.length -ge 80) {
          $syntax += $line.TrimEnd()
          $syntax += ' [<CommonParameters>]'
        } else {
          $syntax += $line.TrimEnd() + ' [<CommonParameters>]'
        }
      }
      $msg += ($syntax -join  "`r`n") + "`r`n" + '```' + "`r`n"
      $msg
    } # end foreach ps
  } else {
    (Get-Command $cmdlet.name).ParameterSets |
      Select-Object -Property @{n='Cmdlet'; e={$cmdlet.name}},
                              @{n='ParameterSetName';e={$_.name}},
                              @{n='Parameters';e={$_.ToString()}}
  }
}
Set-Alias syntax Get-Syntax
#-------------------------------------------------------
function Get-OutputType {
  param([string]$cmd)
  Get-PSDrive | Sort-Object Provider -Unique | ForEach-Object{
    Push-Location $($_.name + ':')
    [pscustomobject] @{
      Provider = $_.Provider.Name
      OutputType = (Get-Command $cmd).OutputType.Name | Select-Object -uni
    }
    Pop-Location
  }
}
#-------------------------------------------------------
function Get-ShortDescription {
  $crlf = "`r`n"
  Get-ChildItem .\*.md | ForEach-Object{
      $filename = $_.Name
      $name = $_.BaseName
      $headers = Select-String -path $filename -Pattern '^## \w*' -AllMatches
      $mdtext = Get-Content $filename
      $start = $headers[0].LineNumber
      $end = $headers[1].LineNumber - 2
      $short = $mdtext[($start)..($end)] -join ' '
      if ($short -eq '') { $short = '{{Placeholder}}'}

      '### [{0}]({1}){3}{2}{3}' -f $name,$filename,$short.Trim(),$crlf
  }
}
#-------------------------------------------------------
function Swap-WordWrapSettings {
  $settingsfile = "$env:USERPROFILE\AppData\Roaming\Code\User\settings.json"
  $c = Get-Content $settingsfile
  $s = ($c | Select-String -Pattern 'editor.wordWrapColumn', 'reflowMarkdown.preferredLineLength','editor.rulers').line
  $n = $s | ForEach-Object {
    if ($_ -match '//') {
      $_ -replace '//'
    } else {
      $_ -replace ' "', ' //"'
    }
  }
  for ($x = 0; $x -lt $s.count; $x++) {
    $c = $c -replace [regex]::Escape($s[$x]), $n[$x]
    #if ($n[$x] -notlike "*//*") {$n[$x]}
  }
  set-content -path $settingsfile -value $c -force
}
#-------------------------------------------------------
function Get-DocsUrl {
  param(
    [string]$topic,
    [switch]$markdown,
    [switch]$mdref
  )

  $topics = @(
      'CimCmdlets/Export-BinaryMiLog',
      'CimCmdlets/Get-CimAssociatedInstance',
      'CimCmdlets/Get-CimClass',
      'CimCmdlets/Get-CimInstance',
      'CimCmdlets/Get-CimSession',
      'CimCmdlets/Import-BinaryMiLog',
      'CimCmdlets/Invoke-CimMethod',
      'CimCmdlets/New-CimInstance',
      'CimCmdlets/New-CimSession',
      'CimCmdlets/New-CimSessionOption',
      'CimCmdlets/Register-CimIndicationEvent',
      'CimCmdlets/Remove-CimInstance',
      'CimCmdlets/Remove-CimSession',
      'CimCmdlets/Set-CimInstance',
      'ISE/Get-IseSnippet',
      'ISE/Import-IseSnippet',
      'ISE/New-IseSnippet',
      'Microsoft.PowerShell.Archive/Compress-Archive',
      'Microsoft.PowerShell.Archive/Expand-Archive',
      'Microsoft.PowerShell.Core/About/about_Alias_Provider',
      'Microsoft.PowerShell.Core/About/about_Aliases',
      'Microsoft.PowerShell.Core/About/about_Arithmetic_Operators',
      'Microsoft.PowerShell.Core/About/about_Arrays',
      'Microsoft.PowerShell.Core/About/about_Assignment_Operators',
      'Microsoft.PowerShell.Core/About/about_Automatic_Variables',
      'Microsoft.PowerShell.Core/About/about_Break',
      'Microsoft.PowerShell.Core/About/about_CimSession',
      'Microsoft.PowerShell.Core/About/about_Classes',
      'Microsoft.PowerShell.Core/About/about_Command_Precedence',
      'Microsoft.PowerShell.Core/About/about_Command_Syntax',
      'Microsoft.PowerShell.Core/About/about_Comment_Based_Help',
      'Microsoft.PowerShell.Core/About/about_CommonParameters',
      'Microsoft.PowerShell.Core/About/about_Comparison_Operators',
      'Microsoft.PowerShell.Core/About/about_Continue',
      'Microsoft.PowerShell.Core/About/about_Core_Commands',
      'Microsoft.PowerShell.Core/About/about_Data_Sections',
      'Microsoft.PowerShell.Core/About/about_Debuggers',
      'Microsoft.PowerShell.Core/About/about_DesiredStateConfiguration',
      'Microsoft.PowerShell.Core/About/about_Do',
      'Microsoft.PowerShell.Core/About/about_DscLogResource',
      'Microsoft.PowerShell.Core/About/about_Enum',
      'Microsoft.PowerShell.Core/About/about_Environment_Provider',
      'Microsoft.PowerShell.Core/About/about_Environment_Variables',
      'Microsoft.PowerShell.Core/About/about_Eventlogs',
      'Microsoft.PowerShell.Core/About/about_Execution_Policies',
      'Microsoft.PowerShell.Core/About/about_Experimental_Features',
      'Microsoft.PowerShell.Core/About/about_FileSystem_Provider',
      'Microsoft.PowerShell.Core/About/about_For',
      'Microsoft.PowerShell.Core/About/about_Foreach',
      'Microsoft.PowerShell.Core/About/about_Format.ps1xml',
      'Microsoft.PowerShell.Core/About/about_Function_Provider',
      'Microsoft.PowerShell.Core/About/about_Functions',
      'Microsoft.PowerShell.Core/About/about_Functions_Advanced',
      'Microsoft.PowerShell.Core/About/about_Functions_Advanced_Methods',
      'Microsoft.PowerShell.Core/About/about_Functions_Advanced_Parameters',
      'Microsoft.PowerShell.Core/About/about_Functions_CmdletBindingAttribute',
      'Microsoft.PowerShell.Core/About/about_Functions_OutputTypeAttribute',
      'Microsoft.PowerShell.Core/About/about_Group_Policy_Settings',
      'Microsoft.PowerShell.Core/About/about_Hash_Tables',
      'Microsoft.PowerShell.Core/About/about_Hidden',
      'Microsoft.PowerShell.Core/About/about_History',
      'Microsoft.PowerShell.Core/About/about_If',
      'Microsoft.PowerShell.Core/About/about_Job_Details',
      'Microsoft.PowerShell.Core/About/about_Jobs',
      'Microsoft.PowerShell.Core/About/about_Join',
      'Microsoft.PowerShell.Core/About/about_Language_Keywords',
      'Microsoft.PowerShell.Core/About/about_Language_Modes',
      'Microsoft.PowerShell.Core/About/about_Line_Editing',
      'Microsoft.PowerShell.Core/About/about_Locations',
      'Microsoft.PowerShell.Core/About/about_Logging',
      'Microsoft.PowerShell.Core/About/about_Logging_Non-Windows',
      'Microsoft.PowerShell.Core/About/about_Logging_Windows',
      'Microsoft.PowerShell.Core/About/about_Logical_Operators',
      'Microsoft.PowerShell.Core/About/about_Methods',
      'Microsoft.PowerShell.Core/About/about_Modules',
      'Microsoft.PowerShell.Core/About/about_Numeric_Literals',
      'Microsoft.PowerShell.Core/About/about_Object_Creation',
      'Microsoft.PowerShell.Core/About/about_Objects',
      'Microsoft.PowerShell.Core/About/about_Operator_Precedence',
      'Microsoft.PowerShell.Core/About/about_Operators',
      'Microsoft.PowerShell.Core/About/about_PackageManagement',
      'Microsoft.PowerShell.Core/About/about_Parameter_Sets',
      'Microsoft.PowerShell.Core/About/about_Parameters',
      'Microsoft.PowerShell.Core/About/about_Parameters_Default_Values',
      'Microsoft.PowerShell.Core/About/about_Parsing',
      'Microsoft.PowerShell.Core/About/about_Path_Syntax',
      'Microsoft.PowerShell.Core/About/about_Pipeline_Chain_Operators',
      'Microsoft.PowerShell.Core/About/about_Pipelines',
      'Microsoft.PowerShell.Core/About/about_PowerShell_Config',
      'Microsoft.PowerShell.Core/About/about_PowerShell_Editions',
      'Microsoft.PowerShell.Core/About/about_PowerShell_exe',
      'Microsoft.PowerShell.Core/About/about_PowerShell_Ise_exe',
      'Microsoft.PowerShell.Core/About/about_Preference_Variables',
      'Microsoft.PowerShell.Core/About/about_Profiles',
      'Microsoft.PowerShell.Core/About/about_Prompts',
      'Microsoft.PowerShell.Core/About/about_Properties',
      'Microsoft.PowerShell.Core/About/about_Providers',
      'Microsoft.PowerShell.Core/About/about_PSConsoleHostReadLine',
      'Microsoft.PowerShell.Core/About/about_PSModulePath',
      'Microsoft.PowerShell.Core/About/about_PSSession_Details',
      'Microsoft.PowerShell.Core/About/about_PSSessions',
      'Microsoft.PowerShell.Core/About/about_PSSnapins',
      'Microsoft.PowerShell.Core/About/about_Pwsh',
      'Microsoft.PowerShell.Core/About/about_Quoting_Rules',
      'Microsoft.PowerShell.Core/About/about_Redirection',
      'Microsoft.PowerShell.Core/About/about_Ref',
      'Microsoft.PowerShell.Core/About/about_Registry_Provider',
      'Microsoft.PowerShell.Core/About/about_Regular_Expressions',
      'Microsoft.PowerShell.Core/About/about_Remote',
      'Microsoft.PowerShell.Core/About/about_Remote_Disconnected_Sessions',
      'Microsoft.PowerShell.Core/About/about_Remote_FAQ',
      'Microsoft.PowerShell.Core/About/about_Remote_Jobs',
      'Microsoft.PowerShell.Core/About/about_Remote_Output',
      'Microsoft.PowerShell.Core/About/about_Remote_Requirements',
      'Microsoft.PowerShell.Core/About/about_Remote_Troubleshooting',
      'Microsoft.PowerShell.Core/About/about_Remote_Variables',
      'Microsoft.PowerShell.Core/About/about_Requires',
      'Microsoft.PowerShell.Core/About/about_Reserved_Words',
      'Microsoft.PowerShell.Core/About/about_Return',
      'Microsoft.PowerShell.Core/About/about_Run_With_PowerShell',
      'Microsoft.PowerShell.Core/About/about_Scopes',
      'Microsoft.PowerShell.Core/About/about_Script_Blocks',
      'Microsoft.PowerShell.Core/About/about_Script_Internationalization',
      'Microsoft.PowerShell.Core/About/about_Scripts',
      'Microsoft.PowerShell.Core/About/about_Session_Configuration_Files',
      'Microsoft.PowerShell.Core/About/about_Session_Configurations',
      'Microsoft.PowerShell.Core/About/about_Signing',
      'Microsoft.PowerShell.Core/About/about_Simplified_Syntax',
      'Microsoft.PowerShell.Core/About/about_Special_Characters',
      'Microsoft.PowerShell.Core/About/about_Splatting',
      'Microsoft.PowerShell.Core/About/about_Split',
      'Microsoft.PowerShell.Core/About/about_Switch',
      'Microsoft.PowerShell.Core/About/about_Telemetry',
      'Microsoft.PowerShell.Core/About/about_Thread_Jobs',
      'Microsoft.PowerShell.Core/About/about_Throw',
      'Microsoft.PowerShell.Core/About/about_Transactions',
      'Microsoft.PowerShell.Core/About/about_Trap',
      'Microsoft.PowerShell.Core/About/about_Try_Catch_Finally',
      'Microsoft.PowerShell.Core/About/about_Type_Accelerators',
      'Microsoft.PowerShell.Core/About/about_Type_Operators',
      'Microsoft.PowerShell.Core/About/about_Types.ps1xml',
      'Microsoft.PowerShell.Core/About/about_Updatable_Help',
      'Microsoft.PowerShell.Core/About/about_Update_Notifications',
      'Microsoft.PowerShell.Core/About/about_Using',
      'Microsoft.PowerShell.Core/About/about_Variable_Provider',
      'Microsoft.PowerShell.Core/About/about_Variables',
      'Microsoft.PowerShell.Core/About/about_While',
      'Microsoft.PowerShell.Core/About/about_Wildcards',
      'Microsoft.PowerShell.Core/About/about_Windows_Powershell_5.1',
      'Microsoft.PowerShell.Core/About/about_Windows_PowerShell_Compatibility',
      'Microsoft.PowerShell.Core/About/about_Windows_PowerShell_ISE',
      'Microsoft.PowerShell.Core/About/about_Windows_RT',
      'Microsoft.PowerShell.Core/About/about_WMI',
      'Microsoft.PowerShell.Core/About/about_WMI_Cmdlets',
      'Microsoft.PowerShell.Core/About/about_WQL',
      'Microsoft.PowerShell.Core/About/about_WS-Management_Cmdlets',
      'Microsoft.PowerShell.Core/Add-History',
      'Microsoft.PowerShell.Core/Add-PSSnapin',
      'Microsoft.PowerShell.Core/Clear-History',
      'Microsoft.PowerShell.Core/Clear-Host',
      'Microsoft.PowerShell.Core/Connect-PSSession',
      'Microsoft.PowerShell.Core/Debug-Job',
      'Microsoft.PowerShell.Core/Disable-ExperimentalFeature',
      'Microsoft.PowerShell.Core/Disable-PSRemoting',
      'Microsoft.PowerShell.Core/Disable-PSSessionConfiguration',
      'Microsoft.PowerShell.Core/Disconnect-PSSession',
      'Microsoft.PowerShell.Core/Enable-ExperimentalFeature',
      'Microsoft.PowerShell.Core/Enable-PSRemoting',
      'Microsoft.PowerShell.Core/Enable-PSSessionConfiguration',
      'Microsoft.PowerShell.Core/Enter-PSHostProcess',
      'Microsoft.PowerShell.Core/Enter-PSSession',
      'Microsoft.PowerShell.Core/Exit-PSHostProcess',
      'Microsoft.PowerShell.Core/Exit-PSSession',
      'Microsoft.PowerShell.Core/Export-Console',
      'Microsoft.PowerShell.Core/Export-ModuleMember',
      'Microsoft.PowerShell.Core/ForEach-Object',
      'Microsoft.PowerShell.Core/Get-Command',
      'Microsoft.PowerShell.Core/Get-ExperimentalFeature',
      'Microsoft.PowerShell.Core/Get-Help',
      'Microsoft.PowerShell.Core/Get-History',
      'Microsoft.PowerShell.Core/Get-Job',
      'Microsoft.PowerShell.Core/Get-Module',
      'Microsoft.PowerShell.Core/Get-PSHostProcessInfo',
      'Microsoft.PowerShell.Core/Get-PSSession',
      'Microsoft.PowerShell.Core/Get-PSSessionCapability',
      'Microsoft.PowerShell.Core/Get-PSSessionConfiguration',
      'Microsoft.PowerShell.Core/Get-PSSnapin',
      'Microsoft.PowerShell.Core/Import-Module',
      'Microsoft.PowerShell.Core/Invoke-Command',
      'Microsoft.PowerShell.Core/Invoke-History',
      'Microsoft.PowerShell.Core/New-Module',
      'Microsoft.PowerShell.Core/New-ModuleManifest',
      'Microsoft.PowerShell.Core/New-PSRoleCapabilityFile',
      'Microsoft.PowerShell.Core/New-PSSession',
      'Microsoft.PowerShell.Core/New-PSSessionConfigurationFile',
      'Microsoft.PowerShell.Core/New-PSSessionOption',
      'Microsoft.PowerShell.Core/New-PSTransportOption',
      'Microsoft.PowerShell.Core/Out-Default',
      'Microsoft.PowerShell.Core/Out-Host',
      'Microsoft.PowerShell.Core/Out-Null',
      'Microsoft.PowerShell.Core/Receive-Job',
      'Microsoft.PowerShell.Core/Receive-PSSession',
      'Microsoft.PowerShell.Core/Register-ArgumentCompleter',
      'Microsoft.PowerShell.Core/Register-PSSessionConfiguration',
      'Microsoft.PowerShell.Core/Remove-Job',
      'Microsoft.PowerShell.Core/Remove-Module',
      'Microsoft.PowerShell.Core/Remove-PSSession',
      'Microsoft.PowerShell.Core/Remove-PSSnapin',
      'Microsoft.PowerShell.Core/Resume-Job',
      'Microsoft.PowerShell.Core/Save-Help',
      'Microsoft.PowerShell.Core/Set-PSDebug',
      'Microsoft.PowerShell.Core/Set-PSSessionConfiguration',
      'Microsoft.PowerShell.Core/Set-StrictMode',
      'Microsoft.PowerShell.Core/Start-Job',
      'Microsoft.PowerShell.Core/Stop-Job',
      'Microsoft.PowerShell.Core/Suspend-Job',
      'Microsoft.PowerShell.Core/Test-ModuleManifest',
      'Microsoft.PowerShell.Core/Test-PSSessionConfigurationFile',
      'Microsoft.PowerShell.Core/Unregister-PSSessionConfiguration',
      'Microsoft.PowerShell.Core/Update-Help',
      'Microsoft.PowerShell.Core/Wait-Job',
      'Microsoft.PowerShell.Core/Where-Object',
      'Microsoft.PowerShell.Diagnostics/Export-Counter',
      'Microsoft.PowerShell.Diagnostics/Get-Counter',
      'Microsoft.PowerShell.Diagnostics/Get-WinEvent',
      'Microsoft.PowerShell.Diagnostics/Import-Counter',
      'Microsoft.PowerShell.Diagnostics/New-WinEvent',
      'Microsoft.PowerShell.Host/Start-Transcript',
      'Microsoft.PowerShell.Host/Stop-Transcript',
      'Microsoft.PowerShell.LocalAccounts/Add-LocalGroupMember',
      'Microsoft.PowerShell.LocalAccounts/Disable-LocalUser',
      'Microsoft.PowerShell.LocalAccounts/Enable-LocalUser',
      'Microsoft.PowerShell.LocalAccounts/Get-LocalGroup',
      'Microsoft.PowerShell.LocalAccounts/Get-LocalGroupMember',
      'Microsoft.PowerShell.LocalAccounts/Get-LocalUser',
      'Microsoft.PowerShell.LocalAccounts/New-LocalGroup',
      'Microsoft.PowerShell.LocalAccounts/New-LocalUser',
      'Microsoft.PowerShell.LocalAccounts/Remove-LocalGroup',
      'Microsoft.PowerShell.LocalAccounts/Remove-LocalGroupMember',
      'Microsoft.PowerShell.LocalAccounts/Remove-LocalUser',
      'Microsoft.PowerShell.LocalAccounts/Rename-LocalGroup',
      'Microsoft.PowerShell.LocalAccounts/Rename-LocalUser',
      'Microsoft.PowerShell.LocalAccounts/Set-LocalGroup',
      'Microsoft.PowerShell.LocalAccounts/Set-LocalUser',
      'Microsoft.PowerShell.Management/Add-Computer',
      'Microsoft.PowerShell.Management/Add-Content',
      'Microsoft.PowerShell.Management/Checkpoint-Computer',
      'Microsoft.PowerShell.Management/Clear-Content',
      'Microsoft.PowerShell.Management/Clear-EventLog',
      'Microsoft.PowerShell.Management/Clear-Item',
      'Microsoft.PowerShell.Management/Clear-ItemProperty',
      'Microsoft.PowerShell.Management/Clear-RecycleBin',
      'Microsoft.PowerShell.Management/Complete-Transaction',
      'Microsoft.PowerShell.Management/Convert-Path',
      'Microsoft.PowerShell.Management/Copy-Item',
      'Microsoft.PowerShell.Management/Copy-ItemProperty',
      'Microsoft.PowerShell.Management/Debug-Process',
      'Microsoft.PowerShell.Management/Disable-ComputerRestore',
      'Microsoft.PowerShell.Management/Enable-ComputerRestore',
      'Microsoft.PowerShell.Management/Get-ChildItem',
      'Microsoft.PowerShell.Management/Get-Clipboard',
      'Microsoft.PowerShell.Management/Get-ComputerInfo',
      'Microsoft.PowerShell.Management/Get-ComputerRestorePoint',
      'Microsoft.PowerShell.Management/Get-Content',
      'Microsoft.PowerShell.Management/Get-ControlPanelItem',
      'Microsoft.PowerShell.Management/Get-EventLog',
      'Microsoft.PowerShell.Management/Get-HotFix',
      'Microsoft.PowerShell.Management/Get-Item',
      'Microsoft.PowerShell.Management/Get-ItemProperty',
      'Microsoft.PowerShell.Management/Get-ItemPropertyValue',
      'Microsoft.PowerShell.Management/Get-Location',
      'Microsoft.PowerShell.Management/Get-Process',
      'Microsoft.PowerShell.Management/Get-PSDrive',
      'Microsoft.PowerShell.Management/Get-PSProvider',
      'Microsoft.PowerShell.Management/Get-Service',
      'Microsoft.PowerShell.Management/Get-TimeZone',
      'Microsoft.PowerShell.Management/Get-Transaction',
      'Microsoft.PowerShell.Management/Get-WmiObject',
      'Microsoft.PowerShell.Management/Invoke-Item',
      'Microsoft.PowerShell.Management/Invoke-WmiMethod',
      'Microsoft.PowerShell.Management/Join-Path',
      'Microsoft.PowerShell.Management/Limit-EventLog',
      'Microsoft.PowerShell.Management/Move-Item',
      'Microsoft.PowerShell.Management/Move-ItemProperty',
      'Microsoft.PowerShell.Management/New-EventLog',
      'Microsoft.PowerShell.Management/New-Item',
      'Microsoft.PowerShell.Management/New-ItemProperty',
      'Microsoft.PowerShell.Management/New-PSDrive',
      'Microsoft.PowerShell.Management/New-Service',
      'Microsoft.PowerShell.Management/New-WebServiceProxy',
      'Microsoft.PowerShell.Management/Pop-Location',
      'Microsoft.PowerShell.Management/Push-Location',
      'Microsoft.PowerShell.Management/Register-WmiEvent',
      'Microsoft.PowerShell.Management/Remove-Computer',
      'Microsoft.PowerShell.Management/Remove-EventLog',
      'Microsoft.PowerShell.Management/Remove-Item',
      'Microsoft.PowerShell.Management/Remove-ItemProperty',
      'Microsoft.PowerShell.Management/Remove-PSDrive',
      'Microsoft.PowerShell.Management/Remove-Service',
      'Microsoft.PowerShell.Management/Remove-WmiObject',
      'Microsoft.PowerShell.Management/Rename-Computer',
      'Microsoft.PowerShell.Management/Rename-Item',
      'Microsoft.PowerShell.Management/Rename-ItemProperty',
      'Microsoft.PowerShell.Management/Reset-ComputerMachinePassword',
      'Microsoft.PowerShell.Management/Resolve-Path',
      'Microsoft.PowerShell.Management/Restart-Computer',
      'Microsoft.PowerShell.Management/Restart-Service',
      'Microsoft.PowerShell.Management/Restore-Computer',
      'Microsoft.PowerShell.Management/Resume-Service',
      'Microsoft.PowerShell.Management/Set-Clipboard',
      'Microsoft.PowerShell.Management/Set-Content',
      'Microsoft.PowerShell.Management/Set-Item',
      'Microsoft.PowerShell.Management/Set-ItemProperty',
      'Microsoft.PowerShell.Management/Set-Location',
      'Microsoft.PowerShell.Management/Set-Service',
      'Microsoft.PowerShell.Management/Set-TimeZone',
      'Microsoft.PowerShell.Management/Set-WmiInstance',
      'Microsoft.PowerShell.Management/Show-ControlPanelItem',
      'Microsoft.PowerShell.Management/Show-EventLog',
      'Microsoft.PowerShell.Management/Split-Path',
      'Microsoft.PowerShell.Management/Start-Process',
      'Microsoft.PowerShell.Management/Start-Service',
      'Microsoft.PowerShell.Management/Start-Transaction',
      'Microsoft.PowerShell.Management/Stop-Computer',
      'Microsoft.PowerShell.Management/Stop-Process',
      'Microsoft.PowerShell.Management/Stop-Service',
      'Microsoft.PowerShell.Management/Suspend-Service',
      'Microsoft.PowerShell.Management/Test-ComputerSecureChannel',
      'Microsoft.PowerShell.Management/Test-Connection',
      'Microsoft.PowerShell.Management/Test-Path',
      'Microsoft.PowerShell.Management/Undo-Transaction',
      'Microsoft.PowerShell.Management/Use-Transaction',
      'Microsoft.PowerShell.Management/Wait-Process',
      'Microsoft.PowerShell.Management/Write-EventLog',
      'Microsoft.PowerShell.ODataUtils/Export-ODataEndpointProxy',
      'Microsoft.PowerShell.Operation.Validation/Get-OperationValidation',
      'Microsoft.PowerShell.Operation.Validation/Invoke-OperationValidation',
      'Microsoft.PowerShell.Security/About/about_Certificate_Provider',
      'Microsoft.PowerShell.Security/ConvertFrom-SecureString',
      'Microsoft.PowerShell.Security/ConvertTo-SecureString',
      'Microsoft.PowerShell.Security/Get-Acl',
      'Microsoft.PowerShell.Security/Get-AuthenticodeSignature',
      'Microsoft.PowerShell.Security/Get-CmsMessage',
      'Microsoft.PowerShell.Security/Get-Credential',
      'Microsoft.PowerShell.Security/Get-ExecutionPolicy',
      'Microsoft.PowerShell.Security/Get-PfxCertificate',
      'Microsoft.PowerShell.Security/New-FileCatalog',
      'Microsoft.PowerShell.Security/Protect-CmsMessage',
      'Microsoft.PowerShell.Security/Set-Acl',
      'Microsoft.PowerShell.Security/Set-AuthenticodeSignature',
      'Microsoft.PowerShell.Security/Set-ExecutionPolicy',
      'Microsoft.PowerShell.Security/Test-FileCatalog',
      'Microsoft.PowerShell.Security/Unprotect-CmsMessage',
      'Microsoft.PowerShell.Utility/Add-Member',
      'Microsoft.PowerShell.Utility/Add-Type',
      'Microsoft.PowerShell.Utility/Clear-Variable',
      'Microsoft.PowerShell.Utility/Compare-Object',
      'Microsoft.PowerShell.Utility/Convert-String',
      'Microsoft.PowerShell.Utility/ConvertFrom-Csv',
      'Microsoft.PowerShell.Utility/ConvertFrom-Json',
      'Microsoft.PowerShell.Utility/ConvertFrom-Markdown',
      'Microsoft.PowerShell.Utility/ConvertFrom-SddlString',
      'Microsoft.PowerShell.Utility/ConvertFrom-String',
      'Microsoft.PowerShell.Utility/ConvertFrom-StringData',
      'Microsoft.PowerShell.Utility/ConvertTo-Csv',
      'Microsoft.PowerShell.Utility/ConvertTo-Html',
      'Microsoft.PowerShell.Utility/ConvertTo-Json',
      'Microsoft.PowerShell.Utility/ConvertTo-Xml',
      'Microsoft.PowerShell.Utility/Debug-Runspace',
      'Microsoft.PowerShell.Utility/Disable-PSBreakpoint',
      'Microsoft.PowerShell.Utility/Disable-RunspaceDebug',
      'Microsoft.PowerShell.Utility/Enable-PSBreakpoint',
      'Microsoft.PowerShell.Utility/Enable-RunspaceDebug',
      'Microsoft.PowerShell.Utility/Export-Alias',
      'Microsoft.PowerShell.Utility/Export-Clixml',
      'Microsoft.PowerShell.Utility/Export-Csv',
      'Microsoft.PowerShell.Utility/Export-FormatData',
      'Microsoft.PowerShell.Utility/Export-PSSession',
      'Microsoft.PowerShell.Utility/Format-Custom',
      'Microsoft.PowerShell.Utility/Format-Hex',
      'Microsoft.PowerShell.Utility/Format-List',
      'Microsoft.PowerShell.Utility/Format-Table',
      'Microsoft.PowerShell.Utility/Format-Wide',
      'Microsoft.PowerShell.Utility/Get-Alias',
      'Microsoft.PowerShell.Utility/Get-Culture',
      'Microsoft.PowerShell.Utility/Get-Date',
      'Microsoft.PowerShell.Utility/Get-Error',
      'Microsoft.PowerShell.Utility/Get-Event',
      'Microsoft.PowerShell.Utility/Get-EventSubscriber',
      'Microsoft.PowerShell.Utility/Get-FileHash',
      'Microsoft.PowerShell.Utility/Get-FormatData',
      'Microsoft.PowerShell.Utility/Get-Host',
      'Microsoft.PowerShell.Utility/Get-MarkdownOption',
      'Microsoft.PowerShell.Utility/Get-Member',
      'Microsoft.PowerShell.Utility/Get-PSBreakpoint',
      'Microsoft.PowerShell.Utility/Get-PSCallStack',
      'Microsoft.PowerShell.Utility/Get-Random',
      'Microsoft.PowerShell.Utility/Get-Runspace',
      'Microsoft.PowerShell.Utility/Get-RunspaceDebug',
      'Microsoft.PowerShell.Utility/Get-TraceSource',
      'Microsoft.PowerShell.Utility/Get-TypeData',
      'Microsoft.PowerShell.Utility/Get-UICulture',
      'Microsoft.PowerShell.Utility/Get-Unique',
      'Microsoft.PowerShell.Utility/Get-Uptime',
      'Microsoft.PowerShell.Utility/Get-Variable',
      'Microsoft.PowerShell.Utility/Get-Verb',
      'Microsoft.PowerShell.Utility/Group-Object',
      'Microsoft.PowerShell.Utility/Import-Alias',
      'Microsoft.PowerShell.Utility/Import-Clixml',
      'Microsoft.PowerShell.Utility/Import-Csv',
      'Microsoft.PowerShell.Utility/Import-LocalizedData',
      'Microsoft.PowerShell.Utility/Import-PowerShellDataFile',
      'Microsoft.PowerShell.Utility/Import-PSSession',
      'Microsoft.PowerShell.Utility/Invoke-Expression',
      'Microsoft.PowerShell.Utility/Invoke-RestMethod',
      'Microsoft.PowerShell.Utility/Invoke-WebRequest',
      'Microsoft.PowerShell.Utility/Join-String',
      'Microsoft.PowerShell.Utility/Measure-Command',
      'Microsoft.PowerShell.Utility/Measure-Object',
      'Microsoft.PowerShell.Utility/New-Alias',
      'Microsoft.PowerShell.Utility/New-Event',
      'Microsoft.PowerShell.Utility/New-Guid',
      'Microsoft.PowerShell.Utility/New-Object',
      'Microsoft.PowerShell.Utility/New-TemporaryFile',
      'Microsoft.PowerShell.Utility/New-TimeSpan',
      'Microsoft.PowerShell.Utility/New-Variable',
      'Microsoft.PowerShell.Utility/Out-File',
      'Microsoft.PowerShell.Utility/Out-GridView',
      'Microsoft.PowerShell.Utility/Out-Printer',
      'Microsoft.PowerShell.Utility/Out-String',
      'Microsoft.PowerShell.Utility/Read-Host',
      'Microsoft.PowerShell.Utility/Register-EngineEvent',
      'Microsoft.PowerShell.Utility/Register-ObjectEvent',
      'Microsoft.PowerShell.Utility/Remove-Alias',
      'Microsoft.PowerShell.Utility/Remove-Event',
      'Microsoft.PowerShell.Utility/Remove-PSBreakpoint',
      'Microsoft.PowerShell.Utility/Remove-TypeData',
      'Microsoft.PowerShell.Utility/Remove-Variable',
      'Microsoft.PowerShell.Utility/Select-Object',
      'Microsoft.PowerShell.Utility/Select-String',
      'Microsoft.PowerShell.Utility/Select-Xml',
      'Microsoft.PowerShell.Utility/Send-MailMessage',
      'Microsoft.PowerShell.Utility/Set-Alias',
      'Microsoft.PowerShell.Utility/Set-Date',
      'Microsoft.PowerShell.Utility/Set-MarkdownOption',
      'Microsoft.PowerShell.Utility/Set-PSBreakpoint',
      'Microsoft.PowerShell.Utility/Set-TraceSource',
      'Microsoft.PowerShell.Utility/Set-Variable',
      'Microsoft.PowerShell.Utility/Show-Command',
      'Microsoft.PowerShell.Utility/Show-Markdown',
      'Microsoft.PowerShell.Utility/Sort-Object',
      'Microsoft.PowerShell.Utility/Start-Sleep',
      'Microsoft.PowerShell.Utility/Tee-Object',
      'Microsoft.PowerShell.Utility/Test-Json',
      'Microsoft.PowerShell.Utility/Trace-Command',
      'Microsoft.PowerShell.Utility/Unblock-File',
      'Microsoft.PowerShell.Utility/Unregister-Event',
      'Microsoft.PowerShell.Utility/Update-FormatData',
      'Microsoft.PowerShell.Utility/Update-List',
      'Microsoft.PowerShell.Utility/Update-TypeData',
      'Microsoft.PowerShell.Utility/Wait-Debugger',
      'Microsoft.PowerShell.Utility/Wait-Event',
      'Microsoft.PowerShell.Utility/Write-Debug',
      'Microsoft.PowerShell.Utility/Write-Error',
      'Microsoft.PowerShell.Utility/Write-Host',
      'Microsoft.PowerShell.Utility/Write-Information',
      'Microsoft.PowerShell.Utility/Write-Output',
      'Microsoft.PowerShell.Utility/Write-Progress',
      'Microsoft.PowerShell.Utility/Write-Verbose',
      'Microsoft.PowerShell.Utility/Write-Warning',
      'Microsoft.WsMan.Management/About/about_WS-Management_Cmdlets',
      'Microsoft.WsMan.Management/About/about_WSMan_Provider',
      'Microsoft.WsMan.Management/Connect-WSMan',
      'Microsoft.WsMan.Management/Disable-WSManCredSSP',
      'Microsoft.WsMan.Management/Disconnect-WSMan',
      'Microsoft.WsMan.Management/Enable-WSManCredSSP',
      'Microsoft.WsMan.Management/Get-WSManCredSSP',
      'Microsoft.WsMan.Management/Get-WSManInstance',
      'Microsoft.WsMan.Management/Invoke-WSManAction',
      'Microsoft.WsMan.Management/New-WSManInstance',
      'Microsoft.WsMan.Management/New-WSManSessionOption',
      'Microsoft.WsMan.Management/Remove-WSManInstance',
      'Microsoft.WsMan.Management/Set-WSManInstance',
      'Microsoft.WsMan.Management/Set-WSManQuickConfig',
      'Microsoft.WsMan.Management/Test-WSMan',
      'PackageManagement/Find-Package',
      'PackageManagement/Find-PackageProvider',
      'PackageManagement/Get-Package',
      'PackageManagement/Get-PackageProvider',
      'PackageManagement/Get-PackageSource',
      'PackageManagement/Import-PackageProvider',
      'PackageManagement/Install-Package',
      'PackageManagement/Install-PackageProvider',
      'PackageManagement/Register-PackageSource',
      'PackageManagement/Save-Package',
      'PackageManagement/Set-PackageSource',
      'PackageManagement/Uninstall-Package',
      'PackageManagement/Unregister-PackageSource',
      'PowershellGet/Find-Command',
      'PowershellGet/Find-DscResource',
      'PowershellGet/Find-Module',
      'PowershellGet/Find-RoleCapability',
      'PowershellGet/Find-Script',
      'PowershellGet/Get-InstalledModule',
      'PowershellGet/Get-InstalledScript',
      'PowershellGet/Get-PSRepository',
      'PowershellGet/Install-Module',
      'PowershellGet/Install-Script',
      'PowershellGet/New-ScriptFileInfo',
      'PowershellGet/Publish-Module',
      'PowershellGet/Publish-Script',
      'PowershellGet/Register-PSRepository',
      'PowershellGet/Save-Module',
      'PowershellGet/Save-Script',
      'PowershellGet/Set-PSRepository',
      'PowershellGet/Test-ScriptFileInfo',
      'PowershellGet/Uninstall-Module',
      'PowershellGet/Uninstall-Script',
      'PowershellGet/Unregister-PSRepository',
      'PowershellGet/Update-Module',
      'PowershellGet/Update-ModuleManifest',
      'PowershellGet/Update-Script',
      'PowershellGet/Update-ScriptFileInfo',
      'PSDesiredStateConfiguration/About/about_Classes_and_DSC',
      'PSDesiredStateConfiguration/Disable-DscDebug',
      'PSDesiredStateConfiguration/Enable-DscDebug',
      'PSDesiredStateConfiguration/Get-DscConfiguration',
      'PSDesiredStateConfiguration/Get-DscConfigurationStatus',
      'PSDesiredStateConfiguration/Get-DscLocalConfigurationManager',
      'PSDesiredStateConfiguration/Get-DscResource',
      'PSDesiredStateConfiguration/Invoke-DscResource',
      'PSDesiredStateConfiguration/New-DSCCheckSum',
      'PSDesiredStateConfiguration/Publish-DscConfiguration',
      'PSDesiredStateConfiguration/Remove-DscConfigurationDocument',
      'PSDesiredStateConfiguration/Restore-DscConfiguration',
      'PSDesiredStateConfiguration/Set-DscLocalConfigurationManager',
      'PSDesiredStateConfiguration/Start-DscConfiguration',
      'PSDesiredStateConfiguration/Stop-DscConfiguration',
      'PSDesiredStateConfiguration/Test-DscConfiguration',
      'PSDesiredStateConfiguration/Update-DscConfiguration',
      'PSDiagnostics/Disable-PSTrace',
      'PSDiagnostics/Disable-PSWSManCombinedTrace',
      'PSDiagnostics/Disable-WSManTrace',
      'PSDiagnostics/Enable-PSTrace',
      'PSDiagnostics/Enable-PSWSManCombinedTrace',
      'PSDiagnostics/Enable-WSManTrace',
      'PSDiagnostics/Get-LogProperties',
      'PSDiagnostics/Set-LogProperties',
      'PSDiagnostics/Start-Trace',
      'PSDiagnostics/Stop-Trace',
      'PSReadline/About/about_PSReadline',
      'PSReadline/Get-PSReadlineKeyHandler',
      'PSReadline/Get-PSReadlineOption',
      'PSReadline/PSConsoleHostReadline',
      'PSReadline/Remove-PSReadlineKeyHandler',
      'PSReadline/Set-PSReadlineKeyHandler',
      'PSReadline/Set-PSReadlineOption',
      'PSScheduledJob/About/about_Scheduled_Jobs',
      'PSScheduledJob/About/about_Scheduled_Jobs_Advanced',
      'PSScheduledJob/About/about_Scheduled_Jobs_Basics',
      'PSScheduledJob/About/about_Scheduled_Jobs_Troubleshooting',
      'PSScheduledJob/Add-JobTrigger',
      'PSScheduledJob/Disable-JobTrigger',
      'PSScheduledJob/Disable-ScheduledJob',
      'PSScheduledJob/Enable-JobTrigger',
      'PSScheduledJob/Enable-ScheduledJob',
      'PSScheduledJob/Get-JobTrigger',
      'PSScheduledJob/Get-ScheduledJob',
      'PSScheduledJob/Get-ScheduledJobOption',
      'PSScheduledJob/New-JobTrigger',
      'PSScheduledJob/New-ScheduledJobOption',
      'PSScheduledJob/Register-ScheduledJob',
      'PSScheduledJob/Remove-JobTrigger',
      'PSScheduledJob/Set-JobTrigger',
      'PSScheduledJob/Set-ScheduledJob',
      'PSScheduledJob/Set-ScheduledJobOption',
      'PSScheduledJob/Unregister-ScheduledJob',
      'PSWorkflow/About/about_ActivityCommonParameters',
      'PSWorkflow/About/about_Checkpoint-Workflow',
      'PSWorkflow/About/about_Foreach-Parallel',
      'PSWorkflow/About/about_InlineScript',
      'PSWorkflow/About/about_Parallel',
      'PSWorkflow/About/about_Sequence',
      'PSWorkflow/About/about_Suspend-Workflow',
      'PSWorkflow/About/about_WorkflowCommonParameters',
      'PSWorkflow/About/about_Workflows',
      'PSWorkflow/New-PSWorkflowExecutionOption',
      'PSWorkflow/New-PSWorkflowSession',
      'PSWorkflowUtility/Invoke-AsWorkflow',
      'PSWorkflowUtility/PSWorkflowUtility',
      'ThreadJob/Start-ThreadJob'
  )
  $topics | Where-Object {$_ -like "*$topic*"} | ForEach-Object{
    $url = "https://docs.microsoft.com/powershell/module/$_".ToLower()
    $url = "/powershell/module/$_".ToLower()
    if ($markdown) {
      $text = ($_ -split '/')[-1]
      if ($mdref) {
        "[$text]: $url"
      } else {
        "[$text]($url)"
      }
    } else {
      $url
    }
  }
}
#endregion
#-------------------------------------------------------
