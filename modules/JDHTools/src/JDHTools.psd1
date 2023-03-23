@{
    RootModule        = '.\JDHTools.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '1f40e601-7f2a-44c9-ba90-48fc850f7fdb'
    Author            = 'Jeff Hicks'
    CompanyName       = 'JDH Information Technology Solutions, Inc.'
    Copyright         = '(c) 2017-2022 JDH Information Technology Solutions, Inc.'
    Description       = 'A collection of tools from Jeff Hicks'
    # PowerShellVersion = ''
    # TypesToProcess = @()
    FormatsToProcess  = @(
        'Formats\PSFormatView.format.ps1xml',
        'Formats\WhoIsResult.format.ps1xml'
    )
    # NestedModules = @()
    FunctionsToExport = @(
        'Convert-CommandToHashtable',
        'ConvertTo-PSClass',
        'Get-FormatView',
        'Get-GitConfig',
        'Get-MyAlias',
        'Get-WhoIs',
        'New-PSFormatXML'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    # FileList = @()
    PrivateData       = @{
        PSData = @{
            # Tags = @()
            # LicenseUri = ''
            # ProjectUri = ''
            # IconUri = ''
            # ReleaseNotes = ''
            # Prerelease = ''
            # RequireLicenseAcceptance = $false
            # ExternalModuleDependencies = @()
        } # End of PSData hashtable
    } # End of PrivateData hashtable
    # HelpInfoURI = ''
}
