# Module manifest for module 'sdwheeler.ReleaseInfo'
# Generated by: Sean D. Wheeler <sewhee@microsoft.com>
@{
    RootModule        = '.\sdwheeler.ReleaseInfo.psm1'
    ModuleVersion     = '1.0.5'
    GUID              = 'd2e623ff-2df3-4fe0-ab87-ec113d40ab89'
    Author            = 'Sean D. Wheeler <sewhee@microsoft.com>'
    CompanyName       = 'Microsoft'
    Copyright         = '(c) Microsoft. All rights reserved.'
    Description       = 'Collection of tools to work with the PowerShell environment.'
    # PowerShellVersion = ''
    # RequiredModules = @()
    # RequiredAssemblies = @()
    # ScriptsToProcess = @()
    TypesToProcess = @('EolData.Types.ps1xml')
    FormatsToProcess = @('EolData.Format.ps1xml','PmcData.Format.ps1xml')
    # NestedModules = @()
    FunctionsToExport = @(
        'Find-PmcPackages',
        'Find-DotnetDockerInfo',
        'Find-DockerImages',
        'Get-LinuxDistroStatus',
        'Get-OSEndOfLife',
        'Get-DSCReleaseHistory',
        'Get-PSReleaseHistory',
        'Get-PSReleasePackage'
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
            ProjectUri               = 'https://github.com/sdwheeler/tools-by-sean/modules/sdwheeler.PSUtils'
            RequireLicenseAcceptance = $false
        }
    }
}
