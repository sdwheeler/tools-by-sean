# Create an empty configuration object
$NewConfiguration = [ordered]@{
    '$schema' = 'https://aka.ms/PowerShell/Crescendo/Schemas/2021-11'
    Commands = @()
}

## Create first Crescendo command and set its properties
$cmdlet = @{
    Verb = 'Get'
    Noun = 'VssProvider'
    OriginalName = '$env:Windir/system32/vssadmin.exe'
}
$newCommand = New-CrescendoCommand @cmdlet
$newCommand.OriginalCommandElements = @('list','providers')
$newCommand.Description = 'List registered volume shadow copy providers'
$newCommand.Usage = New-UsageInfo -usage $newCommand.Description
$newCommand.Platform = @('Windows')

### Add an example to the command
$newCommand.Examples = @()
$example = @{
    Command = 'Get-VssProvider'
    Description = 'Get a list of VSS Providers'
    OriginalCommand = 'vssadmin list providers'
}
$newCommand.Examples += New-ExampleInfo @example

### Add an Output Handler to the command
$newCommand.OutputHandlers = @()
$handler = New-OutputHandler
$handler.ParameterSetName = 'Default'
$handler.HandlerType = 'Function'
$handler.Handler = 'ParseProvider'
$newCommand.OutputHandlers += $handler

## Add the command to the Commands collection of the configuration
$NewConfiguration.Commands += $newCommand

## Create second Crescendo command and set its properties
$cmdlet = @{
    Verb = 'Get'
    Noun = 'VssShadow'
    OriginalName = '$env:Windir/system32/vssadmin.exe'
}
$newCommand = New-CrescendoCommand @cmdlet
$newCommand.OriginalCommandElements = @('list','shadows')
$newCommand.Description = 'List existing volume shadow copies. Without any options, ' +
    'all shadow copies on the system are displayed ordered by shadow copy set. ' +
    'Combinations of options can be used to refine the output.'
$newCommand.Usage = New-UsageInfo -usage 'List existing volume shadow copies.'
$newCommand.Platform = ,'Windows'

### Add multiple examples to the command
$newCommand.Examples = @()
$example = @{
    Command = 'Get-VssShadow'
    Description = 'Get a list of VSS shadow copies'
    OriginalCommand = 'vssadmin list shadows'
}
$newCommand.Examples += New-ExampleInfo @example
$example = @{
    Command = 'Get-VssShadow -For C:'
    Description = 'Get a list of VSS shadow copies for volume C:'
    OriginalCommand = 'vssadmin list shadows /For=C:'
}
$newCommand.Examples += New-ExampleInfo @example
$example = @{
    Command = "Get-VssShadow -Shadow '{c17ebda1-5da3-4f4a-a3dc-f5920c30ed0f}"
    Description = 'Get a specific shadow copy'
    OriginalCommand = 'vssadmin list shadows /Shadow={3872a791-51b6-4d10-813f-64b4beb9f935}'
}
$newCommand.Examples += New-ExampleInfo @example

### Define the parameters and parameter sets
$newCommand.DefaultParameterSetName = 'Default'

#### Add a new parameter to the command
$newCommand.Parameters = @()
$parameters = New-ParameterInfo -OriginalName '/For=' -Name 'For'
$parameters.ParameterType = 'string'
$parameters.ParameterSetName = @('Default','ByShadowId','BySetId')
$parameters.NoGap = $true
$parameters.Description = "List the shadow copies for volume name like 'C:'"
$newCommand.Parameters += $parameters

#### Add a new parameter to the command
$parameters = New-ParameterInfo -OriginalName '/Shadow=' -Name 'Shadow'
$parameters.ParameterType = 'string'
$parameters.ParameterSetName = @('ByShadowId')
$parameters.NoGap = $true
$parameters.Mandatory = $true
$parameters.Description = "List shadow copies matching the Id in GUID format: " +
    "'{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}'"
$newCommand.Parameters += $parameters

#### Add a new parameter to the command
$parameters = New-ParameterInfo -OriginalName '/Set=' -Name 'Set'
$parameters.ParameterType = 'string'
$parameters.ParameterSetName = @('BySetId')
$parameters.NoGap = $true
$parameters.Mandatory = $true
$parameters.Description = "List shadow copies matching the shadow set Id in GUID format: " +
    "'{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}'"
$newCommand.Parameters += $parameters

### Add an Output Handler to the command
$newCommand.OutputHandlers = @()
$handler = New-OutputHandler
$handler.ParameterSetName = 'Default'
$handler.HandlerType = 'Function'
$handler.Handler = 'ParseShadow'
$newCommand.OutputHandlers += $handler

## Add the command to the Commands collection of the configuration
$NewConfiguration.Commands += $newCommand

# Export the configuration to a JSON file and create the module
$NewConfiguration | ConvertTo-Json -Depth 5 | Out-File .\vssadmin.json -Force
Export-CrescendoModule -ConfigurationFile vssadmin.json -ModuleName .\vssadmin.psm1 -Force
