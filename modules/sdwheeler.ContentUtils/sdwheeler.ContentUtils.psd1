# Module manifest for module 'sdwheeler.ContentUtils'
# Generated by: Sean D. Wheeler <sewhee@microsoft.com>
# Generated on: 9/10/2021
@{
    RootModule        = '.\sdwheeler.ContentUtils.psm1'
    ModuleVersion     = '1.0.1'
    GUID              = 'ada27b77-02b5-4c60-b494-9204ffd6316d'
    Author            = 'Sean D. Wheeler <sewhee@microsoft.com>'
    CompanyName       = 'Microsoft'
    Copyright         = '(c) Microsoft. All rights reserved.'
    Description       = 'Collection of commands to work with Docs content.'
    # PowerShellVersion = ''
    # RequiredModules = @()
    # RequiredAssemblies = @()
    # ScriptsToProcess = @()
    # TypesToProcess = @()
    # FormatsToProcess = @()
    # NestedModules = @()
    FunctionsToExport = @(
        'Edit-PSDoc',
        'Get-ArticleCount',
        'Get-ArticleIssueTemplate',
        'Get-DocsUrl',
        'Get-MDRule',
        'Get-SourceUrl',
        'Get-VersionedContent',
        'Show-Help',
        'Switch-WordWrapSettings'
    )
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = '*'
    # List of all files packaged with this module
    # FileList = @()
    # HelpInfoURI = ''
    PrivateData       = @{
        PSData = @{
            Tags                     = @()
            LicenseUri               = 'https://github.com/sdwheeler/tools-by-sean/blob/main/LICENSE'
            ProjectUri               = 'https://github.com/sdwheeler/tools-by-sean/modules/sdwheeler.ContentUtils'
            RequireLicenseAcceptance = $false
        }
    }
}