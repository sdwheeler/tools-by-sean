function Get-EnumValues {
  Param([string]$enum)
  $enumValues = @{}
  [enum]::getvalues([type]$enum) |
    ForEach-Object { $enumValues.add($_, $_.value__) }
  $enumValues
}
function Get-Constructors ([type]$type) {
  foreach ($constr in $type.GetConstructors()) {
    $params = ''
    foreach ($parameter in $constr.GetParameters()) {
      if ($params -eq '') {
        $params = "{0} {1}" -f $parameter.parametertype.fullname,
        $parameter.name
      }
      else {
        $params += ", {0} {1}" -f $parameter.parametertype.fullname,
        $parameter.name
      }
    }
    Write-Host $($constr.DeclaringType.Name) "($params)"
  }
}
function normalizeFilename {
  param([string]$inputString)

  $i = ([IO.Path]::GetInvalidFileNameChars() + '(', ')', '[', ']', ' ' | ForEach-Object { [regex]::Escape($_) }) -join '|'

  $normal = $inputString -replace $i, '-'
  while ($normal -match '--') {
    $normal = $normal -replace '--', '-'
  }
  $normal
}
#-------------------------------------------------------
function kill-module {
  param(
    [Parameter(Mandatory = $true)]
    [string]$module,

    [Parameter(Mandatory = $true)]
    [string]$version,

    [switch]$Force
  )
  'Creating list of dependencies...'
  $depmods = Find-Module $module -RequiredVersion $version | Select-Object -exp dependencies |
    Select-Object @{l = 'name'; e = { $_.name } }, @{l = 'ver'; e = { $_.requiredversion } }

  $depmods += @{name = $module; version = $version }

  $saveErrorPreference = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'

  foreach ($mod in $depmods) {
    'Uninstalling {0}' -f $mod.name
    try {
      uninstall-module $mod.name -RequiredVersion $mod.ver -Force:$Force -ErrorAction Stop
    }
    catch {
      write-host ("`t" + $_.FullyQualifiedErrorId)
    }
  }

  $ErrorActionPreference = $saveErrorPreference
}
#-------------------------------------------------------
function save-history {
  $date = Get-Date -f 'yyyy-MM-dd'
  $oldlog = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt"
  $newlog = "C:\Users\sewhee\Documents\PowerShell\History\ConsoleHost_history_$date.txt"
  Copy-Item $oldlog $newlog -Force
  Get-History |
    Select-Object -ExpandProperty CommandLine |
    Sort-Object -Unique |
    Out-File $oldlog -Force
}