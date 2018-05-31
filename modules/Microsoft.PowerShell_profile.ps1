########################################################
#region Initialize Environment
########################################################
if ($PSVersionTable.PSVersion -ge '6.0.0') {
  Add-WindowsPSModulePath
}
Add-Type -Path 'C:\Program Files\System.Data.SQLite\2015\GAC\System.Data.SQLite.dll'
Import-Module sdwheeler.utilities -WarningAction SilentlyContinue
Import-Module PSYaml
# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
#endregion
#-------------------------------------------------------
#region Aliases
#-------------------------------------------------------
set-alias pop   pop-location
set-alias ed    "${env:ProgramFiles(x86)}\NoteTab 7\NotePro.exe"
set-alias fview "$env:ProgramW6432\Maze Computer\File View\FView.exe"
#endregion
#-------------------------------------------------------
#region Git Functions
$env:GITHUB_ORG         = 'Microsoft'
$env:GITHUB_USERNAME    = 'sdwheeler'

$global:gitRepoRoots = 'C:\Git\PS-Docs', 'C:\Git\AzureDocs', 'C:\Git\Microsoft', 'C:\Git\Community', 'C:\Git\CSIStuff', 'C:\Git\PS-Other'

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Import-Module posh-git
Start-SshAgent -Quiet
Set-Location C:\Git

if ($env:SKIPREPOS -ne 'True') { get-myrepos }
$env:SKIPREPOS = $True
#-------------------------------------------------------
function global:prompt {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal] $identity
  $name = ($identity.Name -split '\\')[1]
  $path = Convert-Path $executionContext.SessionState.Path.CurrentLocation
  $prefix = "($env:PROCESSOR_ARCHITECTURE)"

  if($principal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) { $prefix = "Admin: $prefix" }
  $realLASTEXITCODE = $LASTEXITCODE
  $prefix = "Git $prefix"
  Write-Host ("$prefix[$Name]") -nonewline
  Write-VcsStatus
  ("`n$('+' * (get-location -stack).count)") + "PS $($path)$('>' * ($nestedPromptLevel + 1)) "
  $global:LASTEXITCODE = $realLASTEXITCODE
  $host.ui.RawUI.WindowTitle = "$prefix[$Name] $($path)"
}
#endregion
#-------------------------------------------------------
#region Helper functions
#-------------------------------------------------------
function show($topic) { get-help -show $topic }
function about($topic) { get-help -show about_$topic }
function show-help {
  param($cmd='*')
  #param($module="")
  #get-module -list $module | select -expand ExportedCommands | %{ foreach ($k in $_.Keys) {$k} } |
  #  % { get-command $_ | Select-Object Name,ResolvedCommandName,Verb,Noun,CommandType,ModuleName } |
  get-command $cmd | Where-Object CommandType -ne 'Application' | Select-Object Name,ResolvedCommandName,Verb,Noun,CommandType,ModuleName |
  Out-GridView -Title 'All Cmdlets' -PassThru | ForEach-Object { Get-Help $_.name -show }
}
#-------------------------------------------------------
function get-enumValues {
  Param([string]$enum)
  $enumValues = @{}
  [enum]::getvalues([type]$enum) |
  ForEach-Object { $enumValues.add($_, $_.value__) }
  $enumValues
}
function normalizeFilename {
  param([string]$inputString)

  $i = ([IO.Path]::GetInvalidFileNameChars() | %{ [regex]::Escape($_) }) -join '|'

  $normal = $inputString -replace $i,' '
  while ($normal -match '  ') {
    $normal = $normal -replace '  ',' '
  }
  $normal
}
#-------------------------------------------------------
function epro {
  code C:\Git\CSIStuff\tools-by-sean\modules
}
function push-profile {
  pushd C:\Git\CSIStuff\tools-by-sean\modules
  copy .\Microsoft.PowerShell_profile.ps1 $env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1
  copy .\Microsoft.PowerShellISE_profile.ps1 $env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1
  copy C:\Git\CSIStuff\tools-by-sean\modules\sdwheeler.utilities\* $env:USERPROFILE\Documents\WindowsPowerShell\Modules\sdwheeler.utilities
  popd
}
#-------------------------------------------------------
function bc {
  Start-Process "${env:ProgramFiles(x86)}\Beyond Compare 3\BComp.exe" -ArgumentList $args
}
#-------------------------------------------------------
function ed {
  Start-Process "${env:ProgramFiles(x86)}\NoteTab 7\notepro.exe" -ArgumentList $args
}
#-------------------------------------------------------
function soma {
  & "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe" http://ice1.somafm.com/illstreet-128-aac
}
#-------------------------------------------------------
function color {
  param($hexColor='', [Switch]$Table)

  if ($Table) {
    for ($bg = 0; $bg -lt 0x10; $bg++) {
      for ($fg = 0; $fg -lt 0x10; $fg++) {
        Write-Host -nonewline -background $bg -foreground $fg (' {0:X}{1:X} ' -f $bg,$fg)
      }
      Write-Host
    }
  } else {
    if ($hexColor -eq '') {
      # Output the current colors as a string.
      'Current Color = {0:X}{1:X} ' -f [Int] $HOST.UI.RawUI.BackgroundColor, [Int] $HOST.UI.RawUI.ForegroundColor
    } else {
      # Assume -color specifies a hex value and cast it to a [Byte].
      $newcolor = [Byte] ('0x{0}' -f $hexColor)
      # Split the color into background and foreground colors. The
      # [Math]::Truncate method returns a [Double], so cast it to an [Int].
      $bg = [Int] [Math]::Truncate($newcolor / 0x10)
      $fg = $newcolor -band 0xF

      # If the background and foreground colors match, throw an error;
      # otherwise, set the colors.
      if ($bg -eq $fg) {
        Write-Error 'The background and foreground colors must not match.'
      } else {
        $HOST.UI.RawUI.BackgroundColor = $bg
        $HOST.UI.RawUI.ForegroundColor = $fg
      }
    }
  }
}
#-------------------------------------------------------
function get-weeknum {
  param($date=(get-date))

  $Calendar = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
  $Calendar.GetWeekOfYear($date,[System.Globalization.CalendarWeekRule]::FirstFullWeek,[System.DayOfWeek]::Sunday)
}
#-------------------------------------------------------
function get-sprint {
  param($date=(get-date))

  # Sprint 130 starts in week 2 on 1/15/2018
  [math]::Floor(((get-weeknum $date) - 2)/3) + 130
}
#-------------------------------------------------------
function kill-module {
  param(
    [Parameter(Mandatory=$true)]
    [string]$module,

    [Parameter(Mandatory=$true)]
    [string]$version,

    [switch]$Force
  )
  'Creating list of dependencies...'
  $depmods = Find-Module $module -RequiredVersion $version | select -exp dependencies |
      select @{l='name';e={$_.name}},@{l='ver';e={$_.requiredversion}}

  $depmods += @{name=$module; version=$version}

  $saveErrorPreference =  $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'

  foreach ($mod in $depmods) {
    'Uninstalling {0}' -f $mod.name
    try {
      uninstall-module $mod.name -RequiredVersion $mod.ver -Force:$Force -ErrorAction Stop
    } catch {
      write-host ("`t" + $_.FullyQualifiedErrorId)
    }
  }

  $ErrorActionPreference = $saveErrorPreference
}
#endregion
#-------------------------------------------------------
#region Applications
#-------------------------------------------------------
function update-sysinternals {
  param([switch]$exclusions=$false)
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [Security.Principal.WindowsPrincipal] $identity
  if($principal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    $web = get-service webclient
    if ($web.status -ne 'Running') { 'Starting webclient...'; start-service webclient }
    $web = get-service webclient
    while ($web.status -ne 'Running') { Start-Sleep -sec 1 }
    if ($exclusions) {
      Robocopy.exe \\live.sysinternals.com\tools 'C:\Public\Sysinternals' /s /e /XF thumbs.db /xf strings.exe /xf sysmon.exe /xf psexec.exe
    } else {
      Robocopy.exe \\live.sysinternals.com\tools 'C:\Public\Sysinternals' /s /e /XF thumbs.db
    }
  } else {
    'Updating Sysinternals tools requires elevation.'
  }
}
#-------------------------------------------------------
function wootrss {
  param(
    [ValidateSet('accessories','computers','electronics','home','kids','sellout','shirt','sport','tools','wine','www', ignorecase=$true)]
    [string]$site,
    [switch]$notable
  )
  $deals = @()
  $url = 'http://api.woot.com/1/sales/current.rss'
  $woots = Invoke-RestMethod $url | Where-Object {$_.link.startswith("https://$site") }

  foreach ($woot in $woots) {
    $wootoff = ''
    if ($woot.wootoff -eq 'true') {$wootoff = 'woot!'}
    $props = [ordered]@{site=($woot.link -split '\.')[0] -replace 'https://','';
      title=$woot.title;
      price=$woot.pricerange;
      '%sold'=[double]($woot.soldoutpercentage) * 100;
      wootoff=$wootoff;
      condition=$woot.condition;
    }
    $deals += new-object -type PSObject -prop $props
  }
  if ($notable) {
    $deals
  } else {
    $deals | Format-Table -AutoSize
  }
}
function woot {
  param([switch]$notable=$false)
  $apikey = '029075373ff94c7da98799eeb3532034'
  $url = 'https://api.woot.com/2/events.json?eventType=Daily&key={0}' -f  $apikey
  $daily = invoke-restmethod $url
  $url = 'https://api.woot.com/2/events.json?eventType=WootOff&key={0}' -f  $apikey
  $daily += invoke-restmethod $url
  $results = $daily | sort site |
  Select-Object `
  @{l='site';e={($_.site -split '\.')[0]}},
  type,
  @{l='title';e={$_.offers.Title}},
  @{l='Price';e={$_.offers.items.SalePrice | Sort-Object | Select-Object -first 1 -Last 1}},
  @{l='%Sold';e={100 - $_.offers.PercentageRemaining}},
  @{l='Condition';e={$_.offers.items.Attributes | Where-Object Key -eq 'Condition' | Select-Object -ExpandProperty Value -First 1}}
  if ($notable) {$results} else {$results | ft -AutoSize}
}
#endregion
#-------------------------------------------------------
#region KB/Hotfix information
#-------------------------------------------------------
function kb {
  param(
    [parameter(ValueFromPipeline=$true)]
    [string[]]$kb
  )
  foreach ($k in $kb) {
    $k = $k -replace '[a-zA-Z]',''
    $article = irm " https://support.microsoft.com/app/content/api/content/help/en-us/$k"
    $article | select @{n='id';e={$_.details.id}},@{n='title';e={$_.details.title}}
  }
}
#-------------------------------------------------------
function list-kbhistory {
  $objSession = New-Object -Com 'Microsoft.Update.Session'
  $objSearcher = $objSession.CreateUpdateSearcher()
  $intHistoryCount = $objSearcher.GetTotalHistoryCount()
  $colHistory = $objSearcher.QueryHistory(0, $intHistoryCount)
  $ops = @{1='Install'; 2='Uninstall';}
  $rc = @{
    0 = 'Not started';
    1 = 'In progress';
    2 = 'Completed successfully';
    3 = 'Completed with errors';
    4 = 'Failed to complete';
    5 = 'Operation was aborted';
  }

  foreach ($kb in $colHistory) {
    if ($kb.Title) {
      if ($kb.Title -match 'KB\d*') {
        $id = $matches[0]
      } else {
        $id=''
      }
      $data = [ordered]@{
        KB=$id;
        Date=$kb.Date;
        Operation=$ops[$kb.Operation];
        Result=$rc[$kb.ResultCode];
        HResult='0x{0:X8}' -f $kb.HResult;
        Title=$kb.Title;
      }
      new-object PSObject -prop $data
    }
  }
}
#endregion
#-------------------------------------------------------
#region Network Functions
#-------------------------------------------------------
function tcpstat {
  Get-NetTCPConnection |
  Where-Object state -eq established |
  Select-Object LocalAddress,LocalPort,RemoteAddress,
  RemotePort,@{l='PID';e={$_.OwningProcess}},
  @{l='Process';e={(get-process -id $_.owningprocess).ProcessName}} | Format-Table -AutoSize
}
#endregion
#-------------------------------------------------------
#region Eventlog Functions
#-------------------------------------------------------
function get-user32reason {
  param($reasoncode = 0)
  $minorcodes = @{
    0x00000000='Other issue.'
    0x00000001='Maintenance.'
    0x00000002='Installation.'
    0x00000003='Upgrade.'
    0x00000004='Reconfigure.'
    0x00000005='Unresponsive.'
    0x00000006='Unstable.'
    0x00000007='Disk.'
    0x00000008='Processor.'
    0x00000009='Network card.'
    0x0000000a='Power supply.'
    0x0000000b='Unplugged.'
    0x0000000c='Environment.'
    0x0000000d='Driver.'
    0x0000000e='Other driver event.'
    0x0000000F='Blue screen crash event.'
    0x00000010='Service pack.'
    0x00000011='Hot fix.'
    0x00000012='Security patch.'
    0x00000013='Security issue.'
    0x00000014='Network connectivity.'
    0x00000015='WMI issue.'
    0x00000016='Service pack uninstallation.'
    0x00000017='Hot fix uninstallation.'
    0x00000018='Security patch uninstallation.'
    0x00000019='MMC issue.'
    0x00000020='Terminal Services.'
  }

  $majorcodes = @{
    0x00010000='Hardware issue.'
    0x00020000='Operating system issue.'
    0x00030000='Software issue.'
    0x00040000='Application issue.'
    0x00050000='System failure.'
    0x00060000='Power failure.'
    0x00070000='Legacy API shutdown'
  }
  $flags = @{
    0x40000000='The reason code is defined by the user.'
    0x80000000='The shutdown was planned.'
  }
  $flag = 'Unplanned'
  $major = 'Unknown'
  $minor = 'Unknown'

  if (0x80000000 -eq ($reasoncode -band 0x80000000)) { $flag = $flags[0x80000000] }
  if (0x40000000 -eq ($reasoncode -band 0x40000000)) { $flag = '{0} {1}' -f $flag,$flags[0x40000000] }
  foreach ($x in $majorcodes.keys) {
    if (($reasoncode -band 0xf0000) -eq $x) { $major = $majorcodes[$x]; break; }
  }
  foreach ($x in $minorcodes.keys) {
    if (($reasoncode -band 0xffff) -eq $x) { $minor = $minorcodes[$x]; break; }
  }
  $result = [ordered]@{ flags=$flag; major=$major; minor=$minor }
  new-object -type psobject -prop $result
}
#-------------------------------------------------------
function get-restartevents {
  [CmdletBinding(DefaultParameterSetName='date')]
  param(
    [string[]]$computer = @("$env:computername"),
    [parameter(ParameterSetName='date')][datetime]$date = (get-date).AddDays(-3),
    [parameter(ParameterSetName='days')][int]$days = 3
  )
  switch ($PsCmdlet.ParameterSetName)
  {
    'date'  { $starttime = $date; break}
    'days'  { $starttime = (get-date).AddDays(-$days); break}
  }
  foreach ($c in $computer) {
    $srclist = 'EventLog,Microsoft-Windows-Kernel-General,Microsoft-Windows-Kernel-Power,USER32' -split ','
    $idlist = @(12,13,41,109,1001,1074,6005,6006,6008)
    $props = @('LogName','TimeCreated','LevelDisplayName','Id','ProviderName','MachineName','UserId','Message')
    $filterhash = @{ Logname='System'; StartTime=$starttime; ProviderName=$srclist; Id=$idlist }

    Get-WinEvent -FilterHashtable $filterhash -computer $c | Select-Object $props
  }
}
#-------------------------------------------------------
function get-logonevents {
  param(
    [string]$computer=$env:computername,
    [int]$days = 30
  )
  $millisecperday = 24*60*60*1000
  $logonType = @{
    2='Interactive';
    3='Network';
    4='Batch';
    5='Service';
    7='Unlock';
    8='NetworkCleartext';
    9='RunAsCredentials';
    10='RemoteInteractive';
    11='CachedInteractive';
  }
  Get-WinEvent -LogName Security -computer $computer -filterxpath ('*[System[(EventID=4624 or EventID=4648) and TimeCreated[timediff(@SystemTime) <= {0}]]]' -f ($days*$millisecperday)) | ForEach-Object{
    $event = $_
    $props = $event.Properties
    switch ($_.id) {
      4624 {
        $log = [ordered]@{
          date = $event.TimeCreated;
          eventid = $event.Id;
          subjectSID = $props[0].Value.Value;
          subjectName = '{0}\{1}' -f $props[2].Value,$props[1].Value;
          logonSID = $props[4].Value.Value;
          logonName = '{0}\{1}' -f $props[6].Value,$props[5].Value;
          logonType = $logonType[[int]$props[8].Value];
          target = $props[11].Value;
          process = '[{0}] {1}' -f $props[16].Value,$props[17].Value
        }
      }
      4648 {
        $log = [ordered]@{
          date = $event.TimeCreated;
          eventid = $event.Id;
          subjectSID = $props[0].Value;
          subjectName = '{0}\{1}' -f $props[2].Value,$props[1].Value;
          logonSID = '';
          logonName = $props[5].Value;
          logonType = 'n/a';
          target = $props[8].Value;
          process = '[{0}] {1}' -f $props[10].Value,$props[11].Value
        }
      }
    }
    new-object -type psobject -prop $log
  }
}
#endregion
#-------------------------------------------------------
#region AD Functions
function getuser {
  param( [string]$sam)
  $adprops = @('DistinguishedName','SamAccountName','UserPrincipalName','mail','DisplayName','GivenName','sn','Title','Department','telephoneNumber','MobilePhone','StreetAddress','City','State','PostalCode','Country','Manager','sbuxManagerNumber','extensionAttribute7','sbuxJobNumber','EmployeeNumber','sbuxLocalMarketEmployeeID','sbuxCostCenter','extensionAttribute1','employeeType','sbuxEmployeeStatus','extensionAttribute15','sbuxSourceSystem','extensionAttribute8','sbuxImmutableID','ObjectGUID','objectSid','Created','LastLogonDate','PasswordLastSet','LastBadPasswordAttempt','Enabled','LockedOut','PasswordExpired','PasswordNeverExpires','PasswordNotRequired','Description','otherLoginWorkstations','proxyAddresses')
  get-aduser $sam -prop * | Select-Object $adprops
}
function Get-XADUserPasswordExpirationDate {
  Param ([Parameter(Mandatory=$true,  Position=0,  ValueFromPipeline=$true, HelpMessage='Identity of the Account')]
  [Object] $accountIdentity)
  PROCESS {
    $accountObj = Get-ADUser $accountIdentity -properties PasswordExpired, PasswordNeverExpires, PasswordLastSet
    $accountObj
    if ($accountObj.PasswordExpired) {
      Write-Output ('Password of account: ' + $accountObj.Name + ' already expired!')
    } else {
      if ($accountObj.PasswordNeverExpires) {
        Write-Output ('Password of account: ' + $accountObj.Name + ' is set to never expires!')
      } else {
        $passwordSetDate = $accountObj.PasswordLastSet
        if ($passwordSetDate -eq $null) {
          Write-Output ('Password of account: ' + $accountObj.Name + ' has never been set!')
        }  else {
          $maxPasswordAgeTimeSpan = $null
          $dfl = (get-addomain).DomainMode
          if ($dfl -ge 3) {
            ## Greater than Windows2008 domain functional level
            $accountFGPP = Get-ADUserResultantPasswordPolicy $accountObj
            if ($accountFGPP -ne $null) {
              $maxPasswordAgeTimeSpan = $accountFGPP.MaxPasswordAge
            } else {
              $maxPasswordAgeTimeSpan = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
            }
          } else {
            $maxPasswordAgeTimeSpan = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
          }
          if ($maxPasswordAgeTimeSpan -eq $null -or $maxPasswordAgeTimeSpan.TotalMilliseconds -eq 0) {
            Write-Output ('MaxPasswordAge is not set for the domain or is set to zero!')
          } else {
            Write-Output ('Password of account: ' + $accountObj.SamAccountName + ' expires on: ' + ($passwordSetDate + $maxPasswordAgeTimeSpan))
          }
        }
      }
    }
  }
}
function phone {
  param([string[]]$names)
  $users = $names | ForEach-Object{ Get-ADUser -identity $_ -prop sAMAccountName,DisplayName,telephonenumber,EmailAddress,physicalDeliveryOfficeName,title,mobile,department }
  $users | Select-Object @{l='account';e={$_.sAMAccountName}},
  @{l='name';e={$_.DisplayName}},
  title,
  department,
  @{l='email';e={$_.EmailAddress}},
  @{l='phone';e={$_.telephonenumber}},
  @{l='mobile';e={$_.mobile}},
  @{l='office';e={$_.physicalDeliveryOfficeName}}
}
Function Get-LocalGroupMembership {
  <#
      .Synopsis
      Get the local group membership.

      .Description
      Get the local group membership.

      .Parameter ComputerName
      Name of the Computer to get group members. Default is "localhost".

      .Parameter GroupName
      Name of the GroupName to get members from. Default is "Administrators".

      .Example
      Get-LocalGroupMembership
      Description
      -----------
      Get the Administrators group membership for the localhost

      .Example
      Get-LocalGroupMembership -ComputerName SERVER01 -GroupName "Remote Desktop Users"
      Description
      -----------
      Get the membership for the the group "Remote Desktop Users" on the computer SERVER01

      .Example
      Get-LocalGroupMembership -ComputerName SERVER01,SERVER02 -GroupName "Administrators"
      Description
      -----------
      Get the membership for the the group "Administrators" on the computers SERVER01 and SERVER02

      .OUTPUTS
      PSCustomObject

      .INPUTS
      Array

      .Link
      N/A

      .Notes
      NAME:      Get-LocalGroupMembership
      AUTHOR:    Francois-Xavier Cat
      WEBSITE:   www.LazyWinAdmin.com
  #>
  [Cmdletbinding()]

  PARAM (
    [alias('DnsHostName','__SERVER','Computer','IPAddress')]
    [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [string]$GroupName = 'Administrators'

  )
  BEGIN{
  }#BEGIN BLOCK

  PROCESS{
    foreach ($Computer in $ComputerName){
      TRY{
        $Everything_is_OK = $true

        # Testing the connection
        Write-Verbose -Message "$Computer - Testing connection..."
        Test-Connection -ComputerName $Computer -Count 1 -ErrorAction Stop |Out-Null

        # Get the members for the group and computer specified
        Write-Verbose -Message "$Computer - Querying..."
        $Group = [ADSI]"WinNT://$Computer/$GroupName,group"
        $Members = @($group.psbase.Invoke('Members'))
      }#TRY
      CATCH{
        $Everything_is_OK = $false
        Write-Warning -Message "Something went wrong on $Computer"
        Write-Verbose -Message "Error on $Computer"
      }#Catch

      IF($Everything_is_OK){
        # Format the Output
        Write-Verbose -Message "$Computer - Formatting Data"
        $members | ForEach-Object {
          $name = $_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null)
          $class = $_.GetType().InvokeMember('Class', 'GetProperty', $null, $_, $null)
          $path = $_.GetType().InvokeMember('ADsPath', 'GetProperty', $null, $_, $null)

          # Find out if this is a local or domain object
          if ($path -like "*/$Computer/*"){
            $Type = 'Local'
          }
          else {$Type = 'Domain'
          }

          $Details = '' | Select-Object ComputerName,Account,Class,Group,Path,Type
          $Details.ComputerName = $Computer
          $Details.Account = $name
          $Details.Class = $class
          $Details.Group = $GroupName
          $details.Path = $path
          $details.Type = $type

          # Show the Output
          $Details
        }
      }#IF(Everything_is_OK)
    }#Foreach
  }#PROCESS BLOCK

  END{Write-Verbose -Message 'Script Done'}#END BLOCK
}
function get-aduserpic {
  param($samname)
  $user = Get-ADUser $samname -Properties thumbnailphoto
  $user.thumbnailphoto | Set-Content .\$samname.jpg -Encoding byte
}
function set-aduserpic {
  param($samname)
  $photo = [byte[]](Get-Content .\$samname.jpg -Encoding byte)
  Set-ADUser $samname -Replace @{thumbnailPhoto=$photo}
}
#endregion
#-------------------------------------------------------
#region Debug Stuff
#-------------------------------------------------------
function err {
  param([string]$errcode)
  [xml]$err = err.exe /:xml $errcode
  if ($err.ErrV1.err) {
    $err.ErrV1.err
  } else {
    $err.ErrV1 | Format-List
  }
}
function set-vsvars {
  pushd "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\Tools"
  cmd /c "VsDevCmd.bat&set" | foreach {
    if ($_ -match "=") {
      $v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
    }
  }
  popd
  Write-Host "`nVisual Studio 2017 Command Prompt variables set." -ForegroundColor Yellow
}
#-------------------------------------------------------
#endregion
#-------------------------------------------------------
