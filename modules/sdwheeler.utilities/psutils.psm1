function Get-EnumValues {
    Param([string]$enum)
    $enumValues = @{}
    [enum]::getvalues([type]$enum) |
    ForEach-Object { $enumValues.add($_, $_.value__) }
    $enumValues
  }
  function Get-Constructors ([type]$type)
  {
      foreach ($constr in $type.GetConstructors())
      {
          $params = ''
          foreach ($parameter in $constr.GetParameters())
          {
              if ($params -eq '') {
                  $params =  "{0} {1}" -f $parameter.parametertype.fullname,
                      $parameter.name
              } else {
                $params +=  ", {0} {1}" -f $parameter.parametertype.fullname,
                    $parameter.name
              }
          }
          Write-Host $($constr.DeclaringType.Name) "($params)"
      }
  }
  function normalizeFilename {
    param([string]$inputString)

    $i = ([IO.Path]::GetInvalidFileNameChars()+'(',')','[',']',' ' | %{ [regex]::Escape($_) }) -join '|'

    $normal = $inputString -replace $i,'-'
    while ($normal -match '--') {
      $normal = $normal -replace '--','-'
    }
    $normal
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
