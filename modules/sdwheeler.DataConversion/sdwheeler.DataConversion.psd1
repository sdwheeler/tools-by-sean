# Module manifest for module 'sdwheeler.DataConversion'
# Generated by: Sean D. Wheeler <sewhee@microsoft.com>
# Generated on: 9/10/2021
@{
    RootModule        = '.\sdwheeler.DataConversion.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '710d103e-3d99-4766-81e8-701544805286'
    Author            = 'Sean D. Wheeler <sewhee@microsoft.com>'
    CompanyName       = 'Microsoft'
    Copyright         = '(c) Microsoft. All rights reserved.'
    Description = 'Collection of command to convert to/from different data formats.'
    # PowerShellVersion = ''
    # RequiredModules = @()
    # RequiredAssemblies = @()
    # ScriptsToProcess = @()
    # TypesToProcess = @()
    # FormatsToProcess = @()
    # NestedModules = @()
    FunctionsToExport = @(
        'ConvertFrom-Base64',
        'ConvertTo-Base64',
        'ConvertTo-UrlEncoding',
        'ConvertFrom-UrlEncoding',
        'ConvertTo-HtmlEncoding',
        'ConvertFrom-HtmlEncoding'
    )
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = '*'
    # List of all files packaged with this module
    # FileList = @()
    # HelpInfoURI = ''
    PrivateData = @{
        PSData = @{
            Tags = @()
            LicenseUri = 'https://github.com/sdwheeler/tools-by-sean/blob/main/LICENSE'
            ProjectUri = 'https://github.com/sdwheeler/tools-by-sean/modules/sdwheeler.DataConversion'
            RequireLicenseAcceptance = $false
        }
    }
}
